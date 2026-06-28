#!/usr/bin/env node
/* serve.js — zero-dependency review-tracking server for HTML plans.
 *
 * Run it from anywhere; it serves the .plans/ directory it lives under:
 *     node .plans/_assets/serve.js [--port 7777]
 *
 * Responsibilities (see references/contract.md):
 *   - serve plan docs + assets over http://localhost:PORT (no file:// limits)
 *   - parse each plan doc's <section data-section-id> blocks, hash their text,
 *     and report NEW / MODIFIED / REVIEWED vs the reviewedHash in state.json
 *   - persist review actions to state.json (review.* subtree only; the executor
 *     owns increments.*), under a cooperative lock with atomic tmp+rename
 *   - expose GET /api/plan/<slug> — the increment DAG parsed from data-*,
 *     the parser-of-record for executor skills
 *   - reject duplicate data-section-id / data-inc (HTTP 422)
 *   - set a strict CSP + nosniff on every response; HTML-encode reflected values
 */

'use strict';
const http = require('node:http');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const ASSETS_DIR = __dirname;                  // .plans/_assets
const PLANS_ROOT = path.dirname(ASSETS_DIR);   // .plans
// --port forces a port (errors if busy); omit it to auto-pick: prefer 7777,
// then the next free port, so two repos' servers never collide.
const argPort = (() => {
  const i = process.argv.indexOf('--port');
  const v = i !== -1 ? parseInt(process.argv[i + 1], 10) : NaN;
  return Number.isInteger(v) ? v : null;
})();
const PORT = argPort ?? 7777;                  // preferred/start port
// --open <slug>/<file>.html → open that page in the OS browser once bound.
const OPEN_PATH = (() => {
  const i = process.argv.indexOf('--open');
  return i !== -1 ? (process.argv[i + 1] || '') : null;
})();

const SCHEMA_VERSION = 1;

// ---- helpers --------------------------------------------------------------

const esc = (s) => String(s).replace(/[&<>"]/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
};

// Security headers on every response. `script-src 'self'` stays strict (the
// important one — no inline/injected JS executes). `style-src` allows inline
// styles because mockups, the progress bar, and templates legitimately use
// `style="..."` for layout; inline-style injection is low-risk (no script
// execution). Author-time HTML encoding remains the first line of defence.
function securityHeaders(contentType) {
  return {
    'Content-Type': contentType,
    'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy':
      "default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self'; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'",
  };
}

function send(res, status, contentType, body) {
  res.writeHead(status, securityHeaders(contentType));
  res.end(body);
}
const sendJson = (res, status, obj) =>
  send(res, status, CONTENT_TYPES['.json'], JSON.stringify(obj, null, 2));

// Our thrown errors use { code: <http status> }; Node fs errors use a STRING
// .code (ENOENT, …). Never feed a string to writeHead — it throws and, inside a
// .catch, becomes a fatal unhandled rejection. Coerce to a valid status.
const httpStatus = (code) => (Number.isInteger(code) && code >= 100 && code < 600 ? code : 500);
const errBody = (e) => ({ error: String(e.msg || e.message || e) });

// Accumulate a request body with a hard 1 MB cap, then hand it to cb. On
// overflow it responds 413 and never calls cb.
function readBody(req, res, cb) {
  let body = '';
  let aborted = false;
  req.on('data', (c) => {
    if (aborted) return;
    if (body.length + c.length > 1e6) { aborted = true; sendJson(res, 413, { error: 'request body too large' }); req.destroy(); return; }
    body += c;
  });
  req.on('end', () => { if (!aborted) cb(body); });
}

// ---- HTML parsing (controlled, non-nesting sections in our templates) ------

// Returns [{ id, attrs:{...}, text }] for every <section ...> in the doc.
// Our templates never nest <section>, so positional pairing is sound.
function parseSections(html) {
  const out = [];
  // Consume quoted attribute spans whole so a `>` inside a value (e.g.
  // data-done="x > 0") is not mistaken for the tag boundary.
  const openRe = /<section\b((?:[^>"']|"[^"]*"|'[^']*')*)>/gi;
  let m;
  while ((m = openRe.exec(html)) !== null) {
    const attrStr = m[1];
    const innerStart = openRe.lastIndex;
    const closeIdx = html.indexOf('</section>', innerStart);
    const inner = closeIdx === -1 ? '' : html.slice(innerStart, closeIdx);
    const attrs = {};
    const aRe = /([\w-]+)="([^"]*)"/g;
    let a;
    while ((a = aRe.exec(attrStr)) !== null) attrs[a[1]] = a[2];
    const id = attrs['data-section-id'];
    if (!id) continue; // only data-section-id blocks are reviewable units
    out.push({ id, attrs, text: normalizeText(inner) });
  }
  return out;
}

// textContent-equivalent: drop tags, collapse whitespace. Stable across
// re-indentation so reformatting never flips a section to MODIFIED.
function normalizeText(htmlFragment) {
  return htmlFragment.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

const hash12 = (text) =>
  crypto.createHash('sha256').update(text, 'utf8').digest('hex').slice(0, 12);

const splitAttr = (val) => (val || '').split(',').map((x) => x.trim()).filter(Boolean);

// All plan docs in a slug dir, parsed. Throws {code:422,...} on duplicate ids.
function parseSlug(slug) {
  const dir = path.join(PLANS_ROOT, slug);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.html'));
  const sections = {};
  const increments = [];
  const seenSection = new Set();
  const seenInc = new Set();
  for (const f of files) {
    const html = fs.readFileSync(path.join(dir, f), 'utf8');
    for (const s of parseSections(html)) {
      if (seenSection.has(s.id))
        throw { code: 422, msg: `duplicate data-section-id "${s.id}" in ${f}` };
      seenSection.add(s.id);
      sections[s.id] = { currentHash: hash12(s.text) };
      const inc = s.attrs['data-inc'];
      if (inc !== undefined) {
        const id = Number(inc);
        if (!Number.isInteger(id) || id < 0)
          throw { code: 422, msg: `data-inc "${inc}" must be a non-negative integer in ${f}` };
        if (seenInc.has(id))
          throw { code: 422, msg: `duplicate data-inc "${inc}" (= ${id}) in ${f}` };
        seenInc.add(id);
        for (const req of ['data-size', 'data-files', 'data-done'])
          if (!s.attrs[req])
            throw { code: 422, msg: `increment ${id} missing required ${req} in ${f}` };
        const depends = splitAttr(s.attrs['data-depends']).map(Number);
        if (depends.some((d) => !Number.isInteger(d)))
          throw { code: 422, msg: `increment ${id} has a non-integer data-depends in ${f}` };
        increments.push({
          id,
          size: s.attrs['data-size'],
          depends,
          files: splitAttr(s.attrs['data-files']),
          done: s.attrs['data-done'],
        });
      }
    }
  }
  increments.sort((a, b) => a.id - b.id);
  return { sections, increments };
}

// ---- state.json (locked, atomic, disjoint-subtree) ------------------------

const stateFile = (slug) => path.join(PLANS_ROOT, slug, 'state.json');
const lockFile = (slug) => path.join(PLANS_ROOT, slug, 'state.json.lock');

function blankState(slug) {
  return { schemaVersion: SCHEMA_VERSION, slug, review: {}, increments: {} };
}

async function readState(slug) {
  try {
    const raw = await fsp.readFile(stateFile(slug), 'utf8');
    const s = JSON.parse(raw);
    if (typeof s.schemaVersion === 'number' && s.schemaVersion > SCHEMA_VERSION)
      throw new Error(`state.json schemaVersion ${s.schemaVersion} newer than ${SCHEMA_VERSION}`);
    const merged = { ...blankState(slug), ...s };
    // Coerce the two subtrees to objects — a null/garbage value in the file
    // must not propagate into property access later.
    if (!merged.review || typeof merged.review !== 'object') merged.review = {};
    if (!merged.increments || typeof merged.increments !== 'object') merged.increments = {};
    return merged;
  } catch (e) {
    if (e.code === 'ENOENT') return blankState(slug);
    throw e;
  }
}

// Mutate ONLY the review.* subtree, under the cooperative lock.
async function updateReview(slug, mutator) {
  const lock = lockFile(slug);
  // Evict a stale lock left by a crashed process (normal hold time is << 1s).
  try {
    const st = await fsp.stat(lock);
    if (Date.now() - st.mtimeMs > 5000) await fsp.unlink(lock).catch(() => {});
  } catch { /* ENOENT — no lock, fine */ }
  for (let attempt = 0; ; attempt++) {
    try {
      const fd = await fsp.open(lock, 'wx');
      try {
        const state = await readState(slug);
        state.review = state.review || {};
        mutator(state.review);
        const tmp = stateFile(slug) + '.tmp';
        await fsp.writeFile(tmp, JSON.stringify(state, null, 2));
        await fsp.rename(tmp, stateFile(slug));
        return state;
      } finally {
        await fd.close().catch(() => {});
        await fsp.unlink(lock).catch(() => {});
      }
    } catch (e) {
      if (e.code === 'EEXIST' && attempt < 40) {
        await new Promise((r) => setTimeout(r, 50));
        continue; // someone else holds the lock; back off ~2s total
      }
      throw e;
    }
  }
}

// ---- request handling -----------------------------------------------------

function statusOf(section, reviewedHash) {
  if (!reviewedHash) return 'new';
  return section.currentHash === reviewedHash ? 'reviewed' : 'modified';
}

async function apiState(slug, res) {
  const { sections, increments } = parseSlug(slug);
  const state = await readState(slug);
  const outSections = {};
  for (const [id, sec] of Object.entries(sections)) {
    const reviewedHash = state.review[id]?.reviewedHash ?? null;
    outSections[id] = { status: statusOf(sec, reviewedHash), currentHash: sec.currentHash, reviewedHash: reviewedHash || null };
  }
  sendJson(res, 200, {
    schemaVersion: SCHEMA_VERSION,
    slug,
    sections: outSections,
    increments: state.increments || {},
    incrementOrder: increments.map((i) => i.id),
  });
}

async function apiReview(slug, body, res) {
  const { sections } = parseSlug(slug);
  const data = JSON.parse(body || '{}');
  const targets = data.all ? Object.keys(sections) : [data.sectionId].filter(Boolean);
  if (!targets.length) return sendJson(res, 400, { error: 'sectionId or all:true required' });
  const now = new Date().toISOString();
  await updateReview(slug, (review) => {
    for (const id of targets) {
      if (!Object.hasOwn(sections, id)) continue; // reject inherited keys (constructor, __proto__)
      review[id] = { reviewedHash: sections[id].currentHash, reviewedAt: now };
    }
  });
  // report back the new statuses
  const out = {};
  for (const id of targets) {
    if (!Object.hasOwn(sections, id)) continue;
    out[id] = { status: 'reviewed', reviewedHash: sections[id].currentHash };
  }
  sendJson(res, 200, { reviewed: out, count: Object.keys(out).length });
}

function apiPlan(slug, res) {
  const { increments } = parseSlug(slug);
  sendJson(res, 200, { slug, increments });
}

// ---- feedback (append-only log; the AI reads it, the page writes it) -------

const feedbackFile = (slug) => path.join(PLANS_ROOT, slug, 'feedback.jsonl');

function readFeedback(slug) {
  try {
    return fs.readFileSync(feedbackFile(slug), 'utf8').split('\n').filter(Boolean)
      .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  } catch (e) { if (e.code === 'ENOENT') return []; throw e; }
}

async function apiFeedbackPost(slug, body, res) {
  const data = JSON.parse(body || '{}');
  const text = typeof data.text === 'string' ? data.text.trim() : '';
  if (!text) return sendJson(res, 400, { error: 'text required' });
  if (text.length > 5000) return sendJson(res, 413, { error: 'feedback too long (max 5000 chars)' });
  // One JSON object per line — appends are the only writes, so no lock needed.
  const entry = { ts: new Date().toISOString(), sectionId: data.sectionId || null, text };
  await fsp.appendFile(feedbackFile(slug), JSON.stringify(entry) + '\n');
  sendJson(res, 200, { ok: true, count: readFeedback(slug).length });
}

function apiFeedbackGet(slug, res) {
  sendJson(res, 200, { slug, feedback: readFeedback(slug) });
}

function listPlans() {
  return fs.readdirSync(PLANS_ROOT, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== '_assets')
    .map((d) => d.name);
}

function indexPage() {
  const items = listPlans().map((slug) => {
    const docs = fs.readdirSync(path.join(PLANS_ROOT, slug)).filter((f) => f.endsWith('.html'));
    const first = ['overview.html', 'plan.html'].find((f) => docs.includes(f)) ?? docs[0];
    return first ? `<li><a href="/${esc(slug)}/${esc(first)}">${esc(slug)}</a></li>` : `<li>${esc(slug)} <em>(no .html)</em></li>`;
  }).join('\n');
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Plans</title><link rel="stylesheet" href="/_assets/plan.css"></head>
<body><div class="plan-wrap"><header class="plan-head"><h1>Plans</h1>
<div class="plan-meta">served from ${esc(PLANS_ROOT)}</div></header>
<section class="plan-section"><ul>${items || '<li><em>no plans yet</em></li>'}</ul></section>
</div></body></html>`;
}

const ROOT_RESOLVED = path.resolve(PLANS_ROOT);

function serveStatic(pathname, res) {
  const rel = decodeURIComponent(pathname.replace(/^\/+/, ''));
  const full = path.join(PLANS_ROOT, rel);
  // Lexical guard: resolved path must stay within PLANS_ROOT (catches `..`).
  if (!path.resolve(full).startsWith(ROOT_RESOLVED + path.sep))
    return send(res, 403, CONTENT_TYPES['.html'], 'forbidden');
  // Symlink guard: path.resolve is lexical and does NOT follow symlinks, so a
  // symlink inside PLANS_ROOT pointing out (e.g. → /etc/passwd) would pass the
  // check above. Resolve the real on-disk path and re-check.
  let realFull;
  try { realFull = fs.realpathSync(full); }
  catch { return send(res, 404, CONTENT_TYPES['.html'], `<h1>404</h1><p>${esc(rel)}</p>`); }
  if (realFull !== ROOT_RESOLVED && !realFull.startsWith(ROOT_RESOLVED + path.sep))
    return send(res, 403, CONTENT_TYPES['.html'], 'forbidden');
  fs.readFile(realFull, (err, buf) => {
    if (err) return send(res, 404, CONTENT_TYPES['.html'], `<h1>404</h1><p>${esc(rel)}</p>`);
    send(res, 200, CONTENT_TYPES[path.extname(realFull)] || 'application/octet-stream', buf);
  });
}

const server = http.createServer((req, res) => {
  try {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const p = url.pathname;
    const apiMatch = p.match(/^\/api\/(state|review|plan|feedback)\/([^/]+)\/?$/);
    if (p === '/' || p === '/index.html') return send(res, 200, CONTENT_TYPES['.html'], indexPage());
    if (apiMatch) {
      const [, kind, slug] = apiMatch;
      if (!listPlans().includes(slug)) return sendJson(res, 404, { error: `unknown plan "${slug}"` });
      if (kind === 'state') return void apiState(slug, res).catch((e) => sendJson(res, httpStatus(e.code), errBody(e)));
      if (kind === 'plan') return apiPlan(slug, res);
      if (kind === 'feedback') {
        if (req.method === 'GET') return apiFeedbackGet(slug, res);
        if (req.method !== 'POST') return sendJson(res, 405, { error: 'GET or POST' });
        return readBody(req, res, (body) => apiFeedbackPost(slug, body, res).catch((e) => sendJson(res, httpStatus(e.code), errBody(e))));
      }
      if (kind === 'review') {
        if (req.method !== 'POST') return sendJson(res, 405, { error: 'POST only' });
        return readBody(req, res, (body) => apiReview(slug, body, res).catch((e) => sendJson(res, httpStatus(e.code), errBody(e))));
      }
    }
    return serveStatic(p, res);
  } catch (e) {
    sendJson(res, httpStatus(e.code), errBody(e));
  }
});

// Open a URL with the OS default opener (best-effort; never throws).
function openBrowser(url) {
  const { spawn } = require('node:child_process');
  const [cmd, args] =
    process.platform === 'darwin' ? ['open', [url]] :
    process.platform === 'win32' ? ['cmd', ['/c', 'start', '', url]] :
    ['xdg-open', [url]];
  try {
    const child = spawn(cmd, args, { stdio: 'ignore', detached: true });
    child.on('error', () => {}); // opener missing — URL is printed, don't crash
    child.unref();
  } catch { /* ignore */ }
}

// Bind to loopback only — local single-user review server, never LAN-reachable.
// Auto-pick a free port when --port wasn't given: try PORT, then PORT+1…+20,
// then let the OS assign one.
let bound = false;
server.on('error', (e) => {
  if (!bound && e.code === 'EADDRINUSE' && argPort === null) {
    const tried = server.__port ?? PORT;
    if (tried < PORT + 20) { server.__port = tried + 1; server.listen(server.__port, '127.0.0.1'); return; }
    server.listen(0, '127.0.0.1'); return; // 0 → OS picks any free port
  }
  console.error(`serve.js: ${e.message}`);
  process.exit(1);
});
server.on('listening', () => {
  bound = true;
  const base = `http://127.0.0.1:${server.address().port}/`;
  console.log(`plan tracker serving ${PLANS_ROOT}`);
  console.log(`PLAN_SERVER_URL=${base}`);      // machine-readable; the skill greps this
  console.log(`  → ${base}`);
  if (OPEN_PATH !== null) openBrowser(base + OPEN_PATH.replace(/^\/+/, ''));
});
server.listen(PORT, '127.0.0.1');

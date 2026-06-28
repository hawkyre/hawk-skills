/* plan.js — review-tracking client for HTML plans.
 *
 * Two modes, auto-detected:
 *   - SERVER mode (page served by serve.js over http): fetches per-section
 *     NEW / MODIFIED / REVIEWED status + increment progress from the server,
 *     renders badges + a "mark reviewed" control, and POSTs review actions back.
 *   - OFFLINE mode (opened as a file://, or server unreachable): review
 *     checkmarks persist in localStorage (display-only — never pushed to the
 *     server; the server is authoritative on reconnect). No NEW/MODIFIED diffing
 *     and no shared progress offline, by design.
 *
 * No dependencies, no build step. Loaded with `defer`.
 */
(() => {
  'use strict';

  // slug = the directory segment just before the current file name.
  function currentSlug() {
    const segs = location.pathname.split('/').filter(Boolean);
    return segs.length >= 2 ? decodeURIComponent(segs[segs.length - 2]) : null;
  }

  function postReview(slug, payload) {
    return fetch(`/api/review/${encodeURIComponent(slug)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  }

  const sections = () => Array.from(document.querySelectorAll('section[data-section-id]'));

  function setBadge(section, status) {
    const heading = section.querySelector('h1,h2,h3');
    if (!heading) return;
    let badge = heading.querySelector('.badge[data-review-badge]');
    if (!badge) {
      badge = document.createElement('span');
      badge.setAttribute('data-review-badge', '');
      heading.appendChild(document.createTextNode(' '));
      heading.appendChild(badge);
    }
    badge.className = `badge badge--${status}`;
    badge.textContent = status;
  }

  function controlBox(section) {
    let ctl = section.querySelector('.review-ctl');
    if (!ctl) { ctl = document.createElement('div'); ctl.className = 'review-ctl'; section.appendChild(ctl); }
    return ctl;
  }

  // Update the review button in place (re-callable without wiping sibling buttons).
  function addControl(section, label, onClick) {
    const ctl = controlBox(section);
    let btn = ctl.querySelector('button[data-review-btn]');
    if (!btn) { btn = document.createElement('button'); btn.type = 'button'; btn.setAttribute('data-review-btn', ''); ctl.insertBefore(btn, ctl.firstChild); }
    btn.textContent = label;
    btn.onclick = onClick;
    return btn;
  }

  // ---- feedback composer --------------------------------------------------

  function postFeedback(slug, payload) {
    return fetch(`/api/feedback/${encodeURIComponent(slug)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
    });
  }

  // A textarea + send button that POSTs feedback (optionally tagged to a section).
  function composer(slug, sectionId, mount, placeholder) {
    const box = document.createElement('div'); box.className = 'fb-composer';
    const ta = document.createElement('textarea'); ta.className = 'fb-input'; ta.rows = 2; ta.placeholder = placeholder;
    const row = document.createElement('div'); row.className = 'fb-row';
    const send = document.createElement('button'); send.type = 'button'; send.className = 'fb-send'; send.textContent = 'send feedback';
    const status = document.createElement('span'); status.className = 'fb-status';
    row.appendChild(send); row.appendChild(status);
    box.appendChild(ta); box.appendChild(row); mount.appendChild(box);
    const submit = async () => {
      const text = ta.value.trim(); if (!text) return;
      send.disabled = true; status.textContent = 'sending…';
      try {
        const r = await postFeedback(slug, sectionId ? { sectionId, text } : { text });
        if (r.ok) { ta.value = ''; status.textContent = 'sent ✓'; setTimeout(() => { status.textContent = ''; }, 2500); }
        else status.textContent = 'failed';
      } catch { status.textContent = 'server offline'; }
      send.disabled = false;
    };
    send.addEventListener('click', submit);
    ta.addEventListener('keydown', (e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') submit(); });
    return ta;
  }

  // A "note" toggle in a section's control box that reveals a per-section composer.
  function addNote(section, slug, id) {
    const ctl = controlBox(section);
    const btn = document.createElement('button'); btn.type = 'button'; btn.className = 'fb-toggle'; btn.textContent = 'note';
    let box = null;
    btn.addEventListener('click', () => {
      if (box) { box.remove(); box = null; return; }
      box = document.createElement('div'); section.appendChild(box);
      composer(slug, id, box, 'feedback on this section…').focus();
    });
    ctl.appendChild(btn);
  }

  // A plan-wide feedback section appended at the end.
  function addGlobalFeedback(slug) {
    const wrap = document.querySelector('.plan-wrap');
    if (!wrap || wrap.querySelector('.fb-global')) return;
    const box = document.createElement('section'); box.className = 'plan-section fb-global';
    const h = document.createElement('h2'); h.textContent = 'Feedback'; box.appendChild(h);
    const hint = document.createElement('p'); hint.className = 'muted'; hint.textContent = 'Type a note and send — the AI watching this plan picks it up when you send.';
    box.appendChild(hint);
    wrap.appendChild(box);
    composer(slug, null, box, 'overall feedback on this plan…');
  }

  function renderProgress(increments, order) {
    const box = document.querySelector('.progress[data-progress]');
    if (!box) return;
    const ids = order && order.length ? order : Object.keys(increments).map(Number);
    const total = ids.length;
    if (!total) return;
    let done = 0, prog = 0, block = 0;
    ids.forEach((id) => {
      const s = increments[id] && increments[id].status;
      if (s === 'done') done++;
      else if (s === 'in-progress') prog++;
      else if (s === 'blocked') block++;
    });
    const pct = (n) => `${(100 * n / total).toFixed(1)}%`;
    const track = box.querySelector('.progress-track');
    if (track) {
      track.innerHTML =
        `<span class="seg--done" style="width:${pct(done)}"></span>` +
        `<span class="seg--prog" style="width:${pct(prog)}"></span>` +
        `<span class="seg--block" style="width:${pct(block)}"></span>`;
    }
    const label = box.querySelector('.progress-label');
    if (label) {
      const parts = [`${done} / ${total} increments done`];
      if (prog) parts.push(`${prog} in progress`);
      if (block) parts.push(`${block} blocked`);
      label.textContent = parts.join(' · ');
    }
  }

  // ---- SERVER mode --------------------------------------------------------

  async function serverMode(slug) {
    const res = await fetch(`/api/state/${encodeURIComponent(slug)}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`state ${res.status}`);
    const state = await res.json();

    sections().forEach((section) => {
      const id = section.getAttribute('data-section-id');
      const info = state.sections[id];
      const status = info ? info.status : 'new';
      section.setAttribute('data-review', status);
      setBadge(section, status);
      addControl(section, status === 'reviewed' ? 'reviewed ✓' : 'mark reviewed', async () => {
        const r = await postReview(slug, { sectionId: id });
        if (r.ok) {
          section.setAttribute('data-review', 'reviewed');
          setBadge(section, 'reviewed');
          addControl(section, 'reviewed ✓', () => {});
        }
      });
      addNote(section, slug, id);
    });

    renderProgress(state.increments || {}, state.incrementOrder);
    addGlobalControl('mark all reviewed', async () => {
      const r = await postReview(slug, { all: true });
      if (r.ok) serverMode(slug); // re-render from fresh state
    });
    addGlobalFeedback(slug);
  }

  // ---- OFFLINE mode -------------------------------------------------------

  function offlineMode(slug) {
    const key = (id) => `planreview:${slug || 'local'}:${id}`;
    sections().forEach((section) => {
      const id = section.getAttribute('data-section-id');
      const render = () => {
        const reviewed = localStorage.getItem(key(id)) === '1';
        section.setAttribute('data-review', reviewed ? 'reviewed' : 'new');
        setBadge(section, reviewed ? 'reviewed' : 'new');
        addControl(section, reviewed ? 'reviewed ✓ (local)' : 'mark reviewed (local)', () => {
          const now = localStorage.getItem(key(id)) === '1';
          localStorage.setItem(key(id), now ? '0' : '1');
          render();
        });
      };
      render();
    });
    const label = document.querySelector('.progress[data-progress] .progress-label');
    if (label) label.textContent = '— offline: run serve.js for live progress & change tracking —';
  }

  function addGlobalControl(label, onClick) {
    const head = document.querySelector('.plan-head');
    if (!head || head.querySelector('[data-global-ctl]')) return;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.setAttribute('data-global-ctl', '');
    btn.className = 'review-ctl-global';
    btn.textContent = label;
    btn.style.cssText = 'float:right;font:inherit;font-size:.75rem;cursor:pointer;border:1px solid #cfcfcf;border-radius:4px;padding:.2rem .6rem;background:#fff;';
    btn.addEventListener('click', onClick);
    head.insertBefore(btn, head.firstChild);
  }

  // ---- boot ---------------------------------------------------------------

  function boot() {
    if (!sections().length) return;
    const slug = currentSlug();
    const httpServed = location.protocol === 'http:' || location.protocol === 'https:';
    if (httpServed && slug) {
      serverMode(slug).catch(() => offlineMode(slug)); // server down → fall back
    } else {
      offlineMode(slug);
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();

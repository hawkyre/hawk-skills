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

  function addControl(section, label, onClick) {
    let ctl = section.querySelector('.review-ctl');
    if (!ctl) {
      ctl = document.createElement('div');
      ctl.className = 'review-ctl';
      section.appendChild(ctl);
    }
    ctl.innerHTML = '';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = label;
    btn.addEventListener('click', onClick);
    ctl.appendChild(btn);
    return btn;
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
    });

    renderProgress(state.increments || {}, state.incrementOrder);
    addGlobalControl('mark all reviewed', async () => {
      const r = await postReview(slug, { all: true });
      if (r.ok) serverMode(slug); // re-render from fresh state
    });
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

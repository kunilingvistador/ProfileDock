/* ProfileDock website analytics. Native macOS app has no analytics. */
(() => {
  'use strict';
  const id = 'G-VTDFFJ1TWQ'; // Public measurement ID of the ProfileDock website stream.
  const host = 'kunilingvistador.github.io';
  const prefix = '/ProfileDock/';
  const key = 'profiledock.analytics-consent.v1';
  const paths = ['', 'en/', 'guides/', 'en/guides/', ...['chrome-profile-shortcuts-mac-dock', 'chrome-shortcut-existing-window', 'switch-chrome-profiles-keyboard-mac'].flatMap(slug => [`guides/${slug}/`, `en/guides/${slug}/`])];
  const path = location.pathname;
  if (!/^G-[A-Z0-9]+$/.test(id) || !paths.includes(path.slice(prefix.length)) || !path.startsWith(prefix)) return;
  let loaded = false;
  let allowed = false;
  function readChoice() {
    try {
      const saved = JSON.parse(localStorage.getItem(key) || 'null');
      if (saved && ['granted', 'denied'].includes(saved.choice) && typeof saved.at === 'number' && saved.at <= Date.now()) return saved.choice;
    } catch (_) { return 'denied'; /* Keep tracking off if preferences cannot be read. */ }
    return null;
  }
  function saveChoice(choice) {
    try { localStorage.setItem(key, JSON.stringify({choice, at: Date.now()})); } catch (_) { /* Current-page choice still works. */ }
  }
  function clearCookies() {
    document.cookie.split(';').forEach(part => {
      const name = part.trim().split('=')[0];
      if (name === 'pd_ga' || name.startsWith('pd_ga_')) document.cookie = `${name}=; Max-Age=0; Path=${prefix}; SameSite=Lax; Secure`;
    });
  }
  function start() {
    if (loaded || !allowed || location.hostname !== host || location.protocol !== 'https:') return;
    loaded = true;
    window[`ga-disable-${id}`] = false;
    window.dataLayer = window.dataLayer || [];
    function gtag() { window.dataLayer.push(arguments); }
    window.gtag = gtag;
    gtag('consent', 'default', {analytics_storage: 'granted', ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied'});
    gtag('js', new Date());
    let referrer = '';
    try { const url = new URL(document.referrer); if (['http:', 'https:'].includes(url.protocol)) referrer = url.origin + '/'; } catch (_) { /* No referrer. */ }
    const page = {page_location: `https://${host}${path}`, page_referrer: referrer, page_title: document.title};
    gtag('config', id, {...page, send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false, cookie_domain: 'none', cookie_path: prefix, cookie_prefix: 'pd', cookie_expires: 15552000, cookie_update: false});
    gtag('event', 'page_view', page);
    const script = document.createElement('script');
    script.async = true;
    script.referrerPolicy = 'origin';
    script.src = `https://www.googletagmanager.com/gtag/js?id=${id}`;
    document.head.appendChild(script);
    document.addEventListener('click', event => {
      if (!allowed) return;
      const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
      if (!link) return;
      const url = new URL(link.href, location.href);
      if (url.origin === 'https://github.com' && /^\/kunilingvistador\/ProfileDock\/releases(?:\/|$)/.test(url.pathname)) {
        gtag('event', 'download_click', {...page, destination: 'github_releases', transport_type: 'beacon'});
      }
    });
  }
  // No banner or floating control. A saved refusal from the previous version remains effective.
  function updateControl() {
    document.dispatchEvent(new CustomEvent('profiledock:analytics-state', {detail: allowed}));
  }
  function stop() {
    allowed = false;
    window[`ga-disable-${id}`] = true;
    clearCookies();
    updateControl();
    if (loaded) location.reload();
  }
  allowed = readChoice() !== 'denied';
  document.addEventListener('profiledock:analytics-query', updateControl);
  document.addEventListener('profiledock:analytics-toggle', () => {
    const next = !allowed;
    saveChoice(next ? 'granted' : 'denied');
    if (next) { allowed = true; updateControl(); start(); }
    else stop();
  });
  updateControl();
  if (allowed) start(); else stop();
  function syncChoice() {
    const next = readChoice() !== 'denied';
    if (!next && allowed) stop();
    else if (next && !allowed) { allowed = true; updateControl(); start(); }
  }
  window.addEventListener('storage', event => { if (event.key === key || event.key === null) syncChoice(); });
  document.addEventListener('visibilitychange', syncChoice);
})();

/* ProfileDock website analytics. Native macOS app has no analytics. */
(() => {
  'use strict';
  const id = 'G-VTDFFJ1TWQ'; // Public measurement ID of the ProfileDock website stream.
  const host = 'kunilingvistador.github.io';
  const prefix = '/ProfileDock/';
  const key = 'profiledock.analytics-consent.v1';
  const maxAge = 180 * 86400000;
  const paths = ['', 'en/', 'guides/', 'en/guides/', ...['chrome-profile-shortcuts-mac-dock', 'chrome-shortcut-existing-window', 'switch-chrome-profiles-keyboard-mac'].flatMap(slug => [`guides/${slug}/`, `en/guides/${slug}/`])];
  const path = location.pathname;
  if (!/^G-[A-Z0-9]+$/.test(id) || !paths.includes(path.slice(prefix.length)) || !path.startsWith(prefix)) return;
  const ru = document.documentElement.lang === 'ru';
  let loaded = false;
  let allowed = false;
  let lastFocus;
  const copy = ru ? {
    title: 'Помочь улучшить сайт?',
    body: 'С вашего согласия Google Analytics измерит посещения и переходы к скачиванию. Google получит данные об устройстве, странице и cookie-идентификатор; IP используется при обработке запроса. Данные профилей Chrome не передаются. Можно отказаться или изменить выбор позже.',
    yes: 'Разрешить аналитику', no: 'Без аналитики', settings: 'Настройки аналитики', details: 'Подробнее', close: 'Закрыть',
  } : {
    title: 'Help improve this website?',
    body: 'With your consent, Google Analytics measures visits and clicks to download. Google receives device and page details and a cookie identifier; your IP is used when processing the request. Chrome profile data is not sent. You can decline or change your choice later.',
    yes: 'Allow analytics', no: 'No analytics', settings: 'Analytics settings', details: 'Learn more', close: 'Close',
  };
  function readChoice() {
    try {
      const saved = JSON.parse(localStorage.getItem(key) || 'null');
      if (saved && ['granted', 'denied'].includes(saved.choice) && typeof saved.at === 'number' && saved.at <= Date.now() && Date.now() - saved.at < maxAge) return saved.choice;
    } catch (_) { /* Storage unavailable: default to no tracking. */ }
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
    gtag('consent', 'default', {analytics_storage: 'denied', ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied'});
    gtag('consent', 'update', {analytics_storage: 'granted'});
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
  const panel = document.createElement('section');
  panel.className = 'analytics-panel';
  panel.setAttribute('aria-label', copy.settings);
  const title = document.createElement('h2'); title.textContent = copy.title;
  const body = document.createElement('p'); body.textContent = copy.body;
  const details = document.createElement('a'); details.textContent = copy.details; details.href = `${prefix}${ru ? '' : 'en/'}#website-analytics`;
  const actions = document.createElement('div'); actions.className = 'analytics-actions';
  const yes = document.createElement('button'); yes.type = 'button'; yes.textContent = copy.yes;
  const no = document.createElement('button'); no.type = 'button'; no.textContent = copy.no;
  const close = document.createElement('button'); close.type = 'button'; close.textContent = copy.close;
  const settings = document.createElement('button'); settings.type = 'button'; settings.className = 'analytics-settings'; settings.textContent = copy.settings;
  function hide() { panel.hidden = true; settings.hidden = false; lastFocus?.focus(); }
  function choose(choice) {
    saveChoice(choice); allowed = choice === 'granted'; hide();
    if (allowed) start();
    else { window[`ga-disable-${id}`] = true; clearCookies(); if (loaded) location.reload(); }
  }
  yes.addEventListener('click', () => choose('granted'));
  no.addEventListener('click', () => choose('denied'));
  close.addEventListener('click', hide); // Dismissal never grants consent.
  panel.addEventListener('keydown', event => { if (event.key === 'Escape') hide(); });
  settings.addEventListener('click', () => { lastFocus = settings; panel.hidden = false; settings.hidden = true; no.focus(); });
  actions.append(yes, no, close); panel.append(title, body, details, actions);
  const initial = readChoice();
  panel.hidden = initial !== null; settings.hidden = initial === null;
  document.body.append(panel, settings);
  allowed = initial === 'granted';
  if (allowed) start(); else clearCookies();
  function syncChoice() {
    const next = readChoice() === 'granted';
    if (!next && loaded) { allowed = false; window[`ga-disable-${id}`] = true; clearCookies(); location.reload(); }
    else if (next && !allowed) { allowed = true; hide(); start(); }
  }
  window.addEventListener('storage', event => { if (event.key === key) syncChoice(); });
  document.addEventListener('visibilitychange', syncChoice);
})();

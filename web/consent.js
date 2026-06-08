/*
 * MSIXForcelets — cookie consent + Google Analytics gate (no framework).
 *
 * GDPR opt-in: Google Analytics loads ONLY after the visitor clicks "Accept".
 * Before a decision is made, content pages are blocked by a modal overlay so the
 * site cannot be used until the visitor chooses. BOTH choices are offered and
 * "Decline" grants full access (no GA) — this is a consent gate, not a cookie wall.
 *
 * The legal pages (legal/privacy/datenschutz) are NOT blocked, so the privacy
 * policy can be read before consenting. The visitor's choice is stored in
 * localStorage (not a cookie); Decline => GA never loads.
 *
 * To activate analytics: set GA_ID to your GA4 Measurement ID (e.g. "G-AB12CD34EF").
 * While GA_ID is the placeholder nothing is tracked. To go fully cookie-free again,
 * remove the <script src="consent.js"> tags.
 */
(function () {
  'use strict';

  var GA_ID  = 'G-XXXXXXXXXX';                                   // <-- set your GA4 Measurement ID
  var KEY    = 'msixf-consent';                                  // localStorage: 'granted' | 'denied'
  var EXEMPT = ['legal.html', 'privacy.html', 'datenschutz.html']; // readable without a decision

  function gaConfigured() { return GA_ID && GA_ID.indexOf('G-XXX') !== 0; }
  function stored()  { try { return localStorage.getItem(KEY); } catch (e) { return null; } }
  function remember(v) { try { localStorage.setItem(KEY, v); } catch (e) {} }

  function isExempt() {
    var page = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    return EXEMPT.indexOf(page) !== -1;
  }

  function loadGA() {
    if (!gaConfigured() || window.__gaLoaded) { return; }
    window.__gaLoaded = true;
    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(GA_ID);
    document.head.appendChild(s);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('js', new Date());
    window.gtag('config', GA_ID, { anonymize_ip: true });
  }

  function removeUI() {
    var el = document.getElementById('cookie-consent');
    if (el && el.parentNode) { el.parentNode.removeChild(el); }
    document.documentElement.classList.remove('consent-locked');
  }

  function decide(v) {
    remember(v);
    removeUI();
    if (v === 'granted') { loadGA(); }
  }

  var TEXT =
    '<p class="cookie-text">This site uses <strong>Google Analytics</strong> (which sets cookies) ' +
    'only if you accept. Please read the <a href="privacy.html">Privacy policy</a> / ' +
    '<a href="datenschutz.html">Datenschutz</a> first.</p>' +
    '<div class="cookie-actions">' +
    '<button type="button" class="btn btn-ghost" id="cookie-decline">Decline</button>' +
    '<button type="button" class="btn btn-primary" id="cookie-accept">Accept</button>' +
    '</div>';

  function showUI(blocking) {
    var el = document.createElement('div');
    el.id = 'cookie-consent';
    el.setAttribute('role', 'dialog');
    el.setAttribute('aria-label', 'Cookie consent');
    if (blocking) {
      el.className = 'consent-modal';
      el.setAttribute('aria-modal', 'true');
      el.innerHTML = '<div class="consent-box">' + TEXT + '</div>';
    } else {
      el.className = 'cookie-banner';
      el.innerHTML = TEXT;
    }
    document.body.appendChild(el);
    if (blocking) { document.documentElement.classList.add('consent-locked'); }
    document.getElementById('cookie-accept').addEventListener('click', function () { decide('granted'); });
    document.getElementById('cookie-decline').addEventListener('click', function () { decide('denied'); });
  }

  function init() {
    var c = stored();
    if (c === 'granted') { loadGA(); return; }
    if (c === 'denied')  { return; }
    showUI(!isExempt());   // block content pages; legal pages stay readable
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

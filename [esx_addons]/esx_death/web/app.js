/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const inGame = typeof GetParentResourceName === 'function';
  const preview = !inGame && new URLSearchParams(location.search).has('preview');
  let state = {}, visible = false, holdStart = null, holdFrame = null, previewClock;
  let locale = 'en', strings = {};
  const t = (key, values = {}) => String(strings[key] ?? window.DeathLocales.en[key] ?? '')
    .replace(/\{(\w+)\}/g, (match, name) => values[name] ?? match);
  function setLocale(value, translated) {
    locale = typeof value === 'string' && value ? value : 'en';
    strings = translated && typeof translated === 'object' ? translated : {};
    document.documentElement.lang = locale;
    document.title = t('pageTitle');
    for (const [id, key] of Object.entries({
      eyebrow: 'eyebrow', 'title-first': 'titleFirst', 'title-second': 'titleSecond',
      'title-accent': 'titleAccent', 'description-first': 'descriptionFirst',
      'description-second': 'descriptionSecond', 'automatic-transfer': 'automaticTransfer'
    })) $(id).textContent = t(key);
  }
  const number = value => Math.max(0, Number(value) || 0);
  const formatTime = value => {
    const seconds = Math.ceil(number(value));
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  };
  const timeParts = value => {
    const seconds = Math.ceil(number(value));
    return { time: formatTime(seconds), minutes: Math.floor(seconds / 60), seconds: seconds % 60 };
  };
  const formatNumber = value => {
    try { return value.toLocaleString(t('numberLocale')); } catch { return value.toLocaleString('en-US'); }
  };
  const defaultLogo = $('brand-logo').getAttribute('src');
  $('brand-logo').addEventListener('error', () => {
    if ($('brand-logo').getAttribute('src') !== defaultLogo) $('brand-logo').src = defaultLogo;
  });
  const rgb = value => {
    const match = /^#?([\da-f]{3}|[\da-f]{6})$/i.exec(String(value ?? '').trim());
    if (!match) return null;
    const hex = match[1].length === 3 ? [...match[1]].map(digit => digit + digit).join('') : match[1];
    return [0, 2, 4].map(offset => parseInt(hex.slice(offset, offset + 2), 16));
  };
  function applyTheme(theme) {
    if (!theme || typeof theme !== 'object') return;
    const root = document.documentElement.style;
    const primary = rgb(theme.primaryColor);
    if (primary) {
      root.setProperty('--brand', `rgb(${primary})`);
      root.setProperty('--brand-rgb', primary.join(','));
      root.setProperty('--brand-bright', `rgb(${primary.map(channel => Math.round(channel + (255 - channel) * 0.22))})`);
    }
    const background = rgb(theme.backgroundColor);
    if (background) root.setProperty('--background-rgb', background.join(','));
    for (const [property, value] of [['--secondary', theme.secondaryColor], ['--accent', theme.accentColor]]) {
      const color = rgb(value);
      if (color) root.setProperty(property, `rgb(${color})`);
    }
    const logoUrl = typeof theme.logoUrl === 'string' ? theme.logoUrl.trim() : '';
    $('brand-logo').src = logoUrl || defaultLogo;
  }
  const post = async (action, data = {}) => {
    if (!inGame) return { ok: true };
    try {
      const response = await fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
      });
      return await response.json();
    } catch {
      $('feedback').textContent = t('connectionError');
      return { ok: false };
    }
  };
  const hold = value => { $('hold-progress').style.width = `${Math.min(1, number(value)) * 100}%`; };
  const cancelHold = () => {
    holdStart = null;
    if (holdFrame !== null) cancelAnimationFrame(holdFrame);
    holdFrame = null;
    hold(0);
  };
  function render(data) {
    state = { ...state, ...data };
    visible = true;
    $('death-screen').hidden = false;
    const [minutes, seconds] = formatTime(state.remaining).split(':');
    $('countdown').replaceChildren(document.createTextNode(minutes), Object.assign(document.createElement('span'), { textContent: ':' }), document.createTextNode(seconds));
    $('countdown').setAttribute('aria-label', t('countdown', { minutes, seconds }));
    const percent = Math.min(100, number(state.remaining) / Math.max(1, number(state.total)) * 100);
    $('time-progress').style.width = `${percent}%`;
    $('time-percent').textContent = `${Math.ceil(percent)}%`;
    $('location').textContent = state.location || t('locationPending');
    $('zone').textContent = state.zone && state.zone !== 'NULL' ? state.zone : 'San Andreas';
    const cooldown = number(state.distressRemaining), early = number(state.earlyRemaining);
    $('death-reason').textContent = state.deathReason || '';
    $('distress').disabled = cooldown > 0 || !!state.distressPending || !!state.pending;
    $('distress-title').textContent = t(state.distressPending ? 'distressSending' : cooldown > 0 ? 'distressRequested' : state.distressSent ? 'distressRepeat' : 'distressRequest');
    $('distress-description').textContent = cooldown > 0 ? t('distressCooldown', { time: formatTime(cooldown) }) : t('distressDescription');
    $('respawn').disabled = early > 0 || !!state.pending;
    $('respawn-title').textContent = t(state.pending ? 'respawnPreparing' : 'respawnTitle');
    const cost = number(state.fine) > 0 && number(state.remaining) > 0
      ? `$${formatNumber(number(state.fine))}` : t('respawnFree');
    $('respawn-description').textContent = early > 0 ? t('respawnAvailable', timeParts(early))
      : state.pending ? t('respawnWait')
      : `${t('respawnHold', { duration: formatNumber(number(state.holdDuration || 1500) / 1000) })} · ${cost}`;
    if ($('respawn').disabled) cancelHold();
  }
  async function distress() {
    if (!visible || $('distress').disabled) return;
    if (preview) {
      render({ distressSent: true, distressRemaining: 60 });
      $('feedback').textContent = t('distressSent');
    } else {
      render({ distressPending: true });
      const response = await post('distress');
      if (!response.ok) render({ distressPending: false });
    }
  }
  async function respawn() {
    if (!visible || $('respawn').disabled) return;
    if (preview) {
      render({ pending: true });
      $('feedback').textContent = t('previewRespawn');
      clearInterval(previewClock);
    } else {
      render({ pending: true });
      const response = await post('respawn');
      if (!response.ok) render({ pending: false });
    }
  }
  function beginHold() {
    if (!visible || $('respawn').disabled || holdStart !== null) return;
    const duration = Math.max(1, number(state.holdDuration || 1500));
    holdStart = performance.now();
    const step = now => {
      if (holdStart === null) return;
      const progress = Math.min(1, (now - holdStart) / duration);
      hold(progress);
      if (progress >= 1) {
        cancelHold();
        void respawn();
        return;
      }
      holdFrame = requestAnimationFrame(step);
    };
    holdFrame = requestAnimationFrame(step);
  }
  $('distress').addEventListener('click', distress);
  $('respawn').addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    $('respawn').setPointerCapture(event.pointerId);
    beginHold();
  });
  for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) $('respawn').addEventListener(event, cancelHold);
  $('respawn').addEventListener('keydown', event => {
    if (event.code === 'Space' || event.code === 'Enter') { event.preventDefault(); beginHold(); }
  });
  $('respawn').addEventListener('keyup', event => {
    if (event.code === 'Space' || event.code === 'Enter') cancelHold();
  });
  window.addEventListener('blur', cancelHold);
  document.addEventListener('visibilitychange', () => { if (document.hidden) cancelHold(); });
  window.addEventListener('keydown', event => {
    if (!visible || event.repeat) return;
    if (event.code === 'KeyG') { event.preventDefault(); void distress(); }
    if (event.code === 'KeyE') { event.preventDefault(); beginHold(); }
    if (event.code === 'Escape' || event.code === 'F2') { cancelHold(); void post('releaseFocus'); }
  });
  window.addEventListener('keyup', event => { if (event.code === 'KeyE') cancelHold(); });
  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data.action !== 'string') return;
    switch (data.action) {
      case 'state': if (data.data && typeof data.data === 'object') render(data.data); break;
      case 'theme': applyTheme(data.data); break;
      case 'locale':
        if (data.data && typeof data.data === 'object') setLocale(data.data.locale, data.data.strings);
        if (visible) render({});
        break;
      case 'hide': visible = false; cancelHold(); $('death-screen').hidden = true; $('feedback').textContent = ''; $('death-reason').textContent = ''; state = {}; break;
      case 'hold': hold(data.data); break;
      case 'feedback': $('feedback').textContent = typeof data.data === 'string' ? data.data : ''; break;
    }
  });
  setLocale('en');
  if (preview) {
    document.body.classList.add('preview');
    render({ remaining: 584, earlyRemaining: 24, total: 660, distressRemaining: 0, playerId: 28,
      location: 'Vespucci Boulevard', zone: 'Pillbox Hill', holdDuration: 1500, fine: 0,
      deathReason: t('killedByPlayer') });
    previewClock = setInterval(() => render({ remaining: Math.max(0, state.remaining - 1),
      earlyRemaining: Math.max(0, state.earlyRemaining - 1), distressRemaining: Math.max(0, state.distressRemaining - 1) }), 1000);
  } else if (inGame) void post('ready');
})();

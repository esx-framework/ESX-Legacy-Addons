/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const inGame = typeof GetParentResourceName === 'function';
  const preview = !inGame && new URLSearchParams(location.search).has('preview');
  let state = {}, visible = false, holdStart = null, holdFrame = null, previewClock;
  const number = value => Math.max(0, Number(value) || 0);
  const formatTime = value => {
    const seconds = Math.ceil(number(value));
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  };
  const post = async (action, data = {}) => {
    if (!inGame) return { ok: true };
    try {
      const response = await fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
      });
      return await response.json();
    } catch {
      $('feedback').textContent = 'No se pudo conectar. Vuelve a intentarlo.';
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
    if (state.brand) {
      for (const [property, value] of [['--brand', state.brand.color], ['--brand-bright', state.brand.bright]]) {
        if (/^#[\da-f]{6}$/i.test(value)) document.documentElement.style.setProperty(property, value);
      }
    }
    const [minutes, seconds] = formatTime(state.remaining).split(':');
    $('countdown').replaceChildren(document.createTextNode(minutes), Object.assign(document.createElement('span'), { textContent: ':' }), document.createTextNode(seconds));
    $('countdown').setAttribute('aria-label', `${minutes} minutos y ${seconds} segundos hasta el traslado automático`);
    const percent = Math.min(100, number(state.remaining) / Math.max(1, number(state.total)) * 100);
    $('time-progress').style.width = `${percent}%`;
    $('time-percent').textContent = `${Math.ceil(percent)}%`;
    $('location').textContent = state.location || 'Ubicación pendiente';
    $('zone').textContent = state.zone && state.zone !== 'NULL' ? state.zone : 'San Andreas';
    const cooldown = number(state.distressRemaining), early = number(state.earlyRemaining);
    $('death-reason').textContent = state.deathReason || '';
    $('distress').disabled = cooldown > 0 || !!state.distressPending || !!state.pending;
    $('distress-title').textContent = state.distressPending ? 'Enviando aviso…' : cooldown > 0 ? 'Auxilio solicitado' : state.distressSent ? 'Repetir aviso de auxilio' : 'Solicitar auxilio';
    $('distress-description').textContent = cooldown > 0 ? `Ubicación compartida · Nuevo aviso en ${formatTime(cooldown)}` : 'Comparte tu ubicación con emergencias';
    $('respawn').disabled = early > 0 || !!state.pending;
    $('lock-icon').style.opacity = early > 0 ? '1' : '0';
    $('respawn-title').textContent = state.pending ? 'Preparando traslado…' : 'Traslado al hospital';
    $('respawn-description').textContent = early > 0 ? `Disponible en ${formatTime(early)}` : state.pending ? 'Espera un momento' : `Mantén E durante ${number(state.holdDuration || 1500) / 1000} s${number(state.fine) > 0 && number(state.remaining) > 0 ? ` · $${number(state.fine).toLocaleString('es-ES')}` : ' · Sin coste'}`;
    if ($('respawn').disabled) cancelHold();
  }
  async function distress() {
    if (!visible || $('distress').disabled) return;
    if (preview) {
      render({ distressSent: true, distressRemaining: 60 });
      $('feedback').textContent = 'Aviso enviado. Tu ubicación se ha compartido con emergencias.';
    } else await post('distress');
  }
  async function respawn() {
    if (!visible || $('respawn').disabled) return;
    if (preview) {
      render({ pending: true });
      $('feedback').textContent = 'Vista previa: traslado confirmado.';
      clearInterval(previewClock);
    } else await post('respawn');
  }
  function beginHold() {
    if (!visible || $('respawn').disabled || holdStart !== null) return;
    holdStart = performance.now();
    function step(now) {
      if (holdStart === null) return;
      const progress = Math.min(1, (now - holdStart) / number(state.holdDuration || 1500));
      hold(progress);
      if (progress >= 1) { cancelHold(); void respawn(); }
      else holdFrame = requestAnimationFrame(step);
    }
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
      case 'hide': visible = false; cancelHold(); $('death-screen').hidden = true; $('feedback').textContent = ''; $('death-reason').textContent = ''; state = {}; break;
      case 'hold': hold(data.data); break;
      case 'feedback': $('feedback').textContent = typeof data.data === 'string' ? data.data : ''; break;
    }
  });
  if (preview) {
    document.body.classList.add('preview');
    render({ remaining: 584, earlyRemaining: 24, total: 660, distressRemaining: 0, playerId: 28,
      location: 'Vespucci Boulevard', zone: 'Pillbox Hill', holdDuration: 1500, fine: 0,
      deathReason: 'Matado por un jugador' });
    previewClock = setInterval(() => render({ remaining: Math.max(0, state.remaining - 1),
      earlyRemaining: Math.max(0, state.earlyRemaining - 1), distressRemaining: Math.max(0, state.distressRemaining - 1) }), 1000);
  } else if (inGame) void post('ready');
})();

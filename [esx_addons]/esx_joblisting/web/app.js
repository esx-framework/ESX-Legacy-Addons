/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const state = { jobs: [], profile: {}, view: 'home', selected: null, busy: false, revision: 0, text: {}, logo: '' };
  const native = typeof GetParentResourceName === 'function';
  const LOGO = 'assets/esx-logo.png';
  const TEXT = {
    ui_center: 'Job Center', ui_home: 'Job Center home', ui_brand: 'Job {accent}', ui_brand_accent: 'Center', ui_greeting_center: 'Job center', ui_greeting: '{center} welcomes you {name}',
    ui_your_profile: 'Your Profile', ui_close: 'Close Job Center', ui_jobs_list: 'Available jobs', ui_job_details: 'Job details', ui_current_tasks: 'Current tasks', ui_no_tasks: 'No tasks available.',
    ui_available_position: 'Available position', ui_no_jobs: 'No jobs available.', ui_welcome_title: 'Welcome to Job {accent}',
    ui_welcome_text: 'Welcome to the City Job Center — the place where your professional story begins!\n\nThis office gathers all available jobs across the city, whether you want to earn an honest living, help others, or simply try something new.\n\nOn the left, you’ll find a list of professions. Choose one to learn what the job is about, what the requirements are, and how much you can earn.\n\nEvery profession has its own character — some demand strength, others precision or courage. Find the one that fits you and your story best.\n\nOnce you’re ready, click to apply and head out to work. Your career starts now — good luck!',
    ui_signature: 'Mayor of Los Santos', ui_task: 'Task', ui_job_description: 'Job Description:', ui_default_description: 'Apply for this position at the City Job Center. Your starting salary is shown below.',
    ui_difficulty: '{rating} out of 5 difficulty', ui_mark_location: 'Mark job location', ui_no_requirements: 'No requirements', ui_applying: 'Applying…', ui_current_job: 'Current Job', ui_apply: 'Apply',
    ui_hours_format: '{hours}h {minutes}min', ui_salary: 'Salary', ui_tasks_completed: 'Tasks Completed', ui_status: 'Status', ui_unemployed: 'Unemployed', ui_active: 'Active',
    ui_your_information: 'Your Information', ui_player_id: 'Player ID: {id}', ui_name: 'Name', ui_age: 'Age', ui_gender: 'Gender', ui_phone: 'Phone', ui_job: 'Job', ui_please_wait: 'Please wait', ui_quit_job: 'Quit Job',
    ui_job_statistics: 'Job statistics', ui_job_stats: 'Job Stats', ui_total_earnings: 'Total Earnings', ui_hours_worked: 'Hours Worked', ui_current_rank: 'Current Rank', ui_days_on_job: 'Days on Job', ui_days: '{days} days',
    ui_progress_task: 'Progress task:', ui_close_failed: 'Unable to close. Please try again.', ui_change_failed: 'Unable to change jobs. Please try again at the Job Center.', ui_left_job: 'You have left your job.',
    ui_new_job_ready: 'Your new job is ready. Good luck!', ui_no_response: 'The server did not respond. Please try again.', ui_location_marked: 'Job location marked on your map.', ui_location_unavailable: 'Location unavailable.', ui_location_failed: 'Unable to mark the location.'
  };
  let toastTimer, messageTimer;
  const escape = (value) => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const t = key => typeof state.text[key] === 'string' ? state.text[key] : TEXT[key] ?? key;
  const fill = (key, values) => t(key).replace(/\{(\w+)\}/g, (match, name) => values[name] ?? match);
  const markup = (key, parts) => escape(t(key)).replace(/\{(\w+)\}/g, (match, name) => parts[name] ?? match);
  const branded = key => markup(key, { accent: `<em>${escape(t('ui_brand_accent'))}</em>` });
  const logo = () => escape(state.logo || LOGO);
  const array = value => Array.isArray(value) ? value : [];
  const money = value => value == null ? '—' : `<em>$</em>${escape(Number(value).toLocaleString('en-US'))}`;
  const asset = value => typeof value === 'string' && /^assets\/[a-zA-Z0-9_./-]+$/.test(value) && !value.includes('..') ? value : '';
  const icon = (name, cls = '') => `<span class="icon-box ${cls}"><img src="assets/${name}.svg" alt=""></span>`;
  const row = (label, value, accent = false) => `<div class="data-row"><span>${escape(label)}:</span><span${accent ? ' class="accent"' : ''}>${accent ? `<em>${value}</em>` : value}</span></div>`;
  const progress = task => Math.max(0, Math.min(100, Number(task.target) > 0 ? Math.round((Number(task.current) || 0) / Number(task.target) * 100) : 0));
  const taskRows = (tasks, counts = false) => array(tasks).length ? array(tasks).map(task => `<div class="task-row"><strong>${escape(task.title)}</strong><small>${escape(task.description)}</small>${counts ? `<span class="task-count">${escape(task.current ?? 0)}/${escape(task.target ?? 0)}</span>` : `<span class="progress-badge" style="--progress:${progress(task)}%">${progress(task)}%</span>`}</div>`).join('') : `<p class="empty">${escape(t('ui_no_tasks'))}</p>`;
  const rgb = value => { const match = /^#([0-9a-f]{3}|[0-9a-f]{6})([0-9a-f]{2})?$/i.exec(String(value ?? '').trim()); if (!match) return null; const hex = match[1].length === 3 ? [...match[1]].map(c => c + c).join('') : match[1]; return [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16)); };

  async function request(action, data = {}) {
    if (!native) return { ok: true, preview: true };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 17000);
    try {
      const response = await fetch(`https://${GetParentResourceName()}/${action}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data), signal: controller.signal });
      if (!response.ok) throw new Error('Request failed');
      return await response.json();
    } finally { clearTimeout(timer); }
  }

  function notify(message) {
    clearTimeout(messageTimer);
    $('message').textContent = message;
    $('message').hidden = false;
    messageTimer = setTimeout(() => { $('message').hidden = true; }, 5000);
  }
  function scale() { document.documentElement.style.setProperty('--scale', Math.min(innerWidth / 1920, innerHeight / 1080)); }
  function clock() {
    const now = new Date();
    $('date').textContent = state.preview ? '17.10.2025' : now.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
    $('clock').textContent = state.preview ? '22:05' : now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  }
  function applyText() {
    document.querySelectorAll('[data-text]').forEach(node => { node.textContent = t(node.dataset.text); });
    document.querySelectorAll('[data-label]').forEach(node => node.setAttribute('aria-label', t(node.dataset.label)));
    $('home-button').innerHTML = branded('ui_brand');
  }
  function applyTheme(theme) {
    const root = document.documentElement.style;
    const colors = { '--accent': theme.primaryColor, '--base': theme.backgroundColor, '--panel': theme.secondaryColor, '--raised': theme.accentColor };
    for (const [name, value] of Object.entries(colors)) value ? root.setProperty(name, value) : root.removeProperty(name);
    const primary = rgb(theme.primaryColor);
    if (primary) { root.setProperty('--accent-rgb', primary.join(',')); root.setProperty('--accent-shade', `rgb(${primary.map(c => Math.round(c * .594)).join(',')})`); }
    else { root.removeProperty('--accent-rgb'); root.removeProperty('--accent-shade'); }
    state.logo = typeof theme.logoUrl === 'string' ? theme.logoUrl.trim() : '';
  }
  function configure(data) {
    if (data.locale && typeof data.locale === 'object') { state.text = data.locale; document.documentElement.lang = typeof data.language === 'string' ? data.language : 'en'; applyText(); }
    if (data.theme && typeof data.theme === 'object') applyTheme(data.theme);
  }
  function renderJobs() {
    $('jobs').innerHTML = state.jobs.length ? state.jobs.map(job => `<button class="job" data-job="${escape(job.name)}" aria-current="${state.view === 'job' && state.selected === job.name}"><img class="job-icon" src="assets/job-tile.svg" alt=""><span class="job-title">${escape(job.label)}</span><span class="job-subtitle">${escape(job.subtitle || t('ui_available_position'))}</span></button>`).join('') : `<p class="empty">${escape(t('ui_no_jobs'))}</p>`;
  }
  function home() {
    return `<article class="home-view"><img class="welcome-art" src="assets/welcome.png" alt=""><h1>${branded('ui_welcome_title')}</h1><div class="welcome-line"></div><div class="welcome-copy">${t('ui_welcome_text').split(/\n{2,}/).map(paragraph => `<p>${escape(paragraph)}</p>`).join('')}</div><p class="signature">${escape(t('ui_signature'))}</p></article>`;
  }
  function detail(job) {
    const rating = Math.max(0, Math.min(5, Number(job.rating) || 0));
    const current = state.profile.job?.name === job.name;
    const photo = asset(job.image);
    const requirement = escape(job.requirement || t('ui_no_requirements'));
    return `<article class="detail-view"><img class="detail-background" src="assets/job-background.png" alt=""><img class="detail-glow" src="assets/job-glow.svg" alt=""><h2 class="section-heading detail-heading">${icon('pickaxe')}${escape(job.label)}</h2><h2 class="section-heading task-heading">${icon('tasks')}${escape(t('ui_task'))}</h2>${photo ? `<img class="job-photo" src="${photo}" alt="${escape(job.label)}">` : `<div class="job-photo photo-fallback"><img src="${logo()}" alt="ESX" data-logo></div>`}<div class="task-list detail-tasks">${taskRows(job.tasks)}</div><div class="job-description"><h2>${escape(t('ui_job_description'))}</h2>${escape(job.description || t('ui_default_description'))}</div><footer class="detail-footer"><div class="badge rating" aria-label="${escape(fill('ui_difficulty', { rating }))}">${Array.from({length:5}, (_, i) => `<img src="assets/${i < rating ? 'star' : 'star-empty'}.svg" alt="">`).join('')}</div><button class="badge location-button" id="waypoint" aria-label="${escape(t('ui_mark_location'))}" title="${escape(t('ui_mark_location'))}" ${job.location ? '' : 'disabled'}><img src="assets/location.svg" alt=""></button><span class="badge salary">${money(job.salary)}</span><span class="badge requirement" title="${requirement}">${requirement}</span><button class="primary apply" id="apply" ${current || state.busy ? 'disabled' : ''}>${escape(t(state.busy ? 'ui_applying' : current ? 'ui_current_job' : 'ui_apply'))}</button></footer></article>`;
  }
  function profile() {
    const p = state.profile, job = p.job || {}, stats = p.stats || {};
    const tasks = array(p.tasks);
    const unemployed = job.unemployed ?? job.name === 'unemployed';
    const status = escape(t(unemployed ? 'ui_unemployed' : 'ui_active'));
    const hours = stats.minutes == null ? '—' : fill('ui_hours_format', { hours: Math.floor(stats.minutes / 60), minutes: Math.floor(stats.minutes % 60) });
    const extra = array(stats.extra).slice(0,3);
    const defaults = [[t('ui_salary'), money(job.salary)], [t('ui_tasks_completed'), String(tasks.filter(task => progress(task) === 100).length)], [t('ui_status'), status]];
    return `<article class="profile-view"><section class="profile-card" aria-label="${escape(t('ui_your_information'))}"><div class="brand-banner"><div class="brand-pattern" aria-hidden="true">${'<img src="assets/brand-pattern.png" alt="">'.repeat(132)}</div><img class="esx-logo" src="${logo()}" alt="ESX" data-logo></div><img class="avatar" src="assets/avatar.svg" alt=""><p class="identity-name" title="${escape(p.name)}">${escape(p.name)}</p><p class="player-id">${escape(fill('ui_player_id', { id: String(p.id ?? '').padStart(4,'0') }))}</p><h2 class="info-heading">${escape(t('ui_your_information'))}</h2><div class="info-table">${row(t('ui_name'),escape(p.name || '—'))}${row(t('ui_age'),escape(p.age ?? '—'))}${row(t('ui_gender'),escape(p.gender || '—'))}${row(t('ui_phone'),escape(p.phone || '—'))}</div><h2 class="current-heading">${escape(t('ui_current_job'))}</h2><div class="current-table">${row(t('ui_job'),escape(job.label || '—'))}${row(t('ui_salary'),money(job.salary))}${row(t('ui_status'),status,true)}<button id="quit" class="primary quit" ${unemployed || !job.name || state.busy ? 'disabled' : ''}>${escape(t(state.busy ? 'ui_please_wait' : 'ui_quit_job'))}</button></div></section><section class="stats-card" aria-label="${escape(t('ui_job_statistics'))}"><h2 class="stats-heading">${icon('pickaxe')}${escape(job.label || t('ui_job'))}</h2><h3 class="stats-caption">${escape(t('ui_job_stats'))}</h3><div class="stats-table">${row(t('ui_total_earnings'),money(stats.earnings))}${row(t('ui_hours_worked'),escape(hours),true)}${row(t('ui_current_rank'),escape(job.gradeLabel || '—'))}${row(t('ui_days_on_job'),stats.days == null ? '—' : escape(fill('ui_days', { days: stats.days })),true)}${defaults.map(([label,value],i) => extra[i] ? row(extra[i].label,escape(extra[i].value)) : row(label,value)).join('')}</div><h3 class="tasks-caption">${escape(t('ui_task'))}</h3><div class="task-list profile-tasks">${taskRows(tasks)}</div></section></article>`;
  }
  function render() {
    $('greeting').innerHTML = markup('ui_greeting', { center: `<em>${escape(t('ui_greeting_center'))}</em>`, name: `<em>${escape(state.profile.name || '')}</em>` });
    renderJobs();
    const job = state.jobs.find(j => j.name === state.selected);
    $('content').innerHTML = state.view === 'profile' ? profile() : state.view === 'job' && job ? detail(job) : home();
    $('profile-button').setAttribute('aria-pressed', state.view === 'profile');
  }
  function open(data) {
    state.revision++;
    state.jobs = array(data.jobs);
    state.profile = data.profile || {};
    state.preview = !native && Boolean(data.preview);
    state.view = 'home'; state.selected = null; state.busy = false;
    $('message').hidden = true; $('center').hidden = false;
    render(); clock(); $('center').focus({ preventScroll: true });
  }
  async function close() {
    state.revision++; state.busy = false;
    $('center').hidden = true;
    try { await request('close'); } catch { $('center').hidden = false; notify(t('ui_close_failed')); }
  }
  async function changeJob(action) {
    if (state.busy) return;
    state.busy = true;
    const revision = state.revision;
    render();
    try {
      const result = await request(action, { job: state.selected });
      if (revision !== state.revision) return;
      if (!result.ok) { notify(result.message || t('ui_change_failed')); return; }
      if (result.preview) {
        const j = action === 'quit' ? {name:'unemployed',label:t('ui_unemployed'),salary:200,gradeLabel:t('ui_unemployed')} : state.jobs.find(j => j.name === state.selected);
        state.profile = {...state.profile,job:{...j,gradeLabel:j.gradeLabel || 'Recruit'}};
      } else if (result.profile) state.profile = result.profile;
      state.view = 'profile';
      notify(t(action === 'quit' ? 'ui_left_job' : 'ui_new_job_ready'));
    } catch { if (revision === state.revision) notify(t('ui_no_response')); }
    finally { if (revision === state.revision) { state.busy = false; render(); } }
  }
  function hud(data) {
    $('task-hud').hidden = !data.visible;
    if (data.visible) $('task-hud').innerHTML = `${icon('tasks-large','hud-icon')}<h2 class="hud-title">${escape(t('ui_task'))}</h2><p class="hud-subtitle"><em>${escape(data.grade || '')}</em></p><img class="hud-glow" src="assets/tasks-glow.svg" alt=""><div class="hud-tasks">${taskRows(data.tasks,true)}</div>`;
  }
  function toast(task) {
    clearTimeout(toastTimer);
    $('task-toast').innerHTML = `${icon('tasks-large','hud-icon')}<h2 class="hud-title">${escape(task.title)}</h2><p class="hud-subtitle">${escape(t('ui_progress_task'))} <em>${escape(task.current ?? 0)}/${escape(task.target ?? 0)}</em></p><img class="toast-glow" src="assets/toast-glow.svg" alt=""><div class="toast-track"><span style="height:${progress(task)}%"></span></div>`;
    $('task-toast').hidden = false;
    toastTimer = setTimeout(() => { $('task-toast').hidden = true; }, 5000);
  }
  $('home-button').addEventListener('click', () => { state.view='home'; render(); });
  $('profile-button').addEventListener('click', () => { state.view='profile'; render(); });
  $('close-button').addEventListener('click', close);
  $('jobs').addEventListener('click', event => { const button=event.target.closest('[data-job]'); if (button) { state.selected=button.dataset.job; state.view='job'; render(); } });
  $('content').addEventListener('click', async event => {
    const button=event.target.closest('button');
    if (!button || button.disabled) return;
    if (button.id==='apply' || button.id==='quit') return changeJob(button.id);
    if (button.id==='waypoint') {
      try { const result=await request('waypoint',{job:state.selected}); notify(t(result.ok ? 'ui_location_marked' : 'ui_location_unavailable')); } catch { notify(t('ui_location_failed')); }
    }
  });
  $('center').addEventListener('error', event => { const image=event.target; if (image.dataset?.logo !== undefined && image.getAttribute('src') !== LOGO) image.src=LOGO; }, true);
  addEventListener('keydown', event => {
    if ($('center').hidden) return;
    if (event.key==='Escape') { event.preventDefault(); close(); }
    if (event.key==='Tab') {
      const controls=[...$('center').querySelectorAll('button:not(:disabled)')];
      const first=controls[0], last=controls[controls.length-1];
      if (event.shiftKey && document.activeElement===first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement===last) { event.preventDefault(); first.focus(); }
    }
  });
  addEventListener('message', ({data}) => {
    if (!data || typeof data!=='object') return;
    configure(data);
    if (data.action==='open') open(data);
    if (data.action==='close') { state.revision++; state.busy=false; $('center').hidden=true; }
    if (data.action==='profile' && data.profile) {
      state.profile=data.profile;
      const job=state.jobs.find(job=>job.name===data.profile.job?.name);
      if (job) job.tasks=array(data.profile.tasks);
      if (!$('center').hidden) render();
    }
    if (data.action==='tasks') hud(data);
    if (data.action==='taskProgress' && data.task) toast(data.task);
  });
  addEventListener('resize',scale); scale(); clock(); setInterval(()=>{ if (!$('center').hidden) clock(); },1000);
})();

/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const state = { jobs: [], profile: {}, view: 'home', selected: null, busy: false, revision: 0 };
  const native = typeof GetParentResourceName === 'function';
  let toastTimer, messageTimer;
  const escape = (value) => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const array = value => Array.isArray(value) ? value : [];
  const money = value => value == null ? '—' : `<em>$</em>${escape(Number(value).toLocaleString('en-US'))}`;
  const asset = value => typeof value === 'string' && /^assets\/[a-zA-Z0-9_./-]+$/.test(value) && !value.includes('..') ? value : '';
  const icon = (name, cls = '') => `<span class="icon-box ${cls}"><img src="assets/${name}.svg" alt=""></span>`;
  const row = (label, value, accent = false) => `<div class="data-row"><span>${escape(label)}:</span><span${accent ? ' class="accent"' : ''}>${accent ? `<em>${value}</em>` : value}</span></div>`;
  const progress = task => Math.max(0, Math.min(100, Number(task.target) > 0 ? Math.round((Number(task.current) || 0) / Number(task.target) * 100) : 0));
  const taskRows = (tasks, counts = false) => array(tasks).length ? array(tasks).map(task => `<div class="task-row"><strong>${escape(task.title)}</strong><small>${escape(task.description)}</small>${counts ? `<span class="task-count">${escape(task.current ?? 0)}/${escape(task.target ?? 0)}</span>` : `<span class="progress-badge" style="--progress:${progress(task)}%">${progress(task)}%</span>`}</div>`).join('') : '<p class="empty">No tasks available.</p>';

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
  function renderJobs() {
    $('jobs').innerHTML = state.jobs.length ? state.jobs.map(job => `<button class="job" data-job="${escape(job.name)}" aria-current="${state.view === 'job' && state.selected === job.name}"><img class="job-icon" src="assets/job-tile.svg" alt=""><span class="job-title">${escape(job.label)}</span><span class="job-subtitle">${escape(job.subtitle || 'Available position')}</span></button>`).join('') : '<p class="empty">No jobs available.</p>';
  }
  function home() {
    return `<article class="home-view"><img class="welcome-art" src="assets/welcome.png" alt=""><h1>Welcome to Job <em>Center</em></h1><div class="welcome-line"></div><div class="welcome-copy"><p>Welcome to the City Job Center — the place where your professional story begins!</p><p>This office gathers all available jobs across the city, whether you want to earn an honest living, help others, or simply try something new.</p><p>On the left, you’ll find a list of professions. Choose one to learn what the job is about, what the requirements are, and how much you can earn.</p><p>Every profession has its own character — some demand strength, others precision or courage. Find the one that fits you and your story best.</p><p>Once you’re ready, click to apply and head out to work. Your career starts now — good luck!</p></div><p class="signature">Mayor of Los Santos</p></article>`;
  }
  function detail(job) {
    const rating = Math.max(0, Math.min(5, Number(job.rating) || 0));
    const current = state.profile.job?.name === job.name;
    const photo = asset(job.image);
    return `<article class="detail-view"><img class="detail-background" src="assets/job-background.png" alt=""><img class="detail-glow" src="assets/job-glow.svg" alt=""><h2 class="section-heading detail-heading">${icon('pickaxe')}${escape(job.label)}</h2><h2 class="section-heading task-heading">${icon('tasks')}Task</h2>${photo ? `<img class="job-photo" src="${photo}" alt="${escape(job.label)}">` : '<div class="job-photo photo-fallback"><img src="assets/esx-logo.png" alt="ESX"></div>'}<div class="task-list detail-tasks">${taskRows(job.tasks)}</div><div class="job-description"><h2>Job Description:</h2>${escape(job.description || 'Apply for this position at the City Job Center. Your starting salary is shown below.')}</div><footer class="detail-footer"><div class="badge rating" aria-label="${rating} out of 5 difficulty">${Array.from({length:5}, (_, i) => `<img src="assets/${i < rating ? 'star' : 'star-empty'}.svg" alt="">`).join('')}</div><button class="badge location-button" id="waypoint" aria-label="Mark job location" title="Mark job location" ${job.location ? '' : 'disabled'}><img src="assets/location.svg" alt=""></button><span class="badge salary">${money(job.salary)}</span><span class="badge requirement" title="${escape(job.requirement || 'No requirements')}">${escape(job.requirement || 'No requirements')}</span><button class="primary apply" id="apply" ${current || state.busy ? 'disabled' : ''}>${state.busy ? 'Applying…' : current ? 'Current Job' : 'Apply'}</button></footer></article>`;
  }
  function profile() {
    const p = state.profile, job = p.job || {}, stats = p.stats || {};
    const tasks = array(p.tasks);
    const hours = stats.minutes == null ? '—' : `${Math.floor(stats.minutes / 60)}h ${Math.floor(stats.minutes % 60)}min`;
    const extra = array(stats.extra).slice(0,3);
    const defaults = [['Salary', money(job.salary)], ['Tasks Completed', String(tasks.filter(t => progress(t) === 100).length)], ['Status', escape((job.unemployed ?? job.name === 'unemployed') ? 'Unemployed' : 'Active')]];
    return `<article class="profile-view"><section class="profile-card" aria-label="Your information"><div class="brand-banner"><div class="brand-pattern" aria-hidden="true">${'<img src="assets/brand-pattern.png" alt="">'.repeat(132)}</div><img class="esx-logo" src="assets/esx-logo.png" alt="ESX"></div><img class="avatar" src="assets/avatar.svg" alt=""><p class="identity-name" title="${escape(p.name)}">${escape(p.name)}</p><p class="player-id">Player ID: ${escape(String(p.id ?? '').padStart(4,'0'))}</p><h2 class="info-heading">Your Information</h2><div class="info-table">${row('Name',escape(p.name || '—'))}${row('Age',escape(p.age ?? '—'))}${row('Gender',escape(p.gender || '—'))}${row('Phone',escape(p.phone || '—'))}</div><h2 class="current-heading">Current Job</h2><div class="current-table">${row('Job',escape(job.label || '—'))}${row('Salary',money(job.salary))}${row('Status',escape((job.unemployed ?? job.name === 'unemployed') ? 'Unemployed' : 'Active'),true)}<button id="quit" class="primary quit" ${(job.unemployed ?? job.name === 'unemployed') || !job.name || state.busy ? 'disabled' : ''}>${state.busy ? 'Please wait' : 'Quit Job'}</button></div></section><section class="stats-card" aria-label="Job statistics"><h2 class="stats-heading">${icon('pickaxe')}${escape(job.label || 'Job')}</h2><h3 class="stats-caption">Job Stats</h3><div class="stats-table">${row('Total Earnings',money(stats.earnings))}${row('Hours Worked',escape(hours),true)}${row('Current Rank',escape(job.gradeLabel || '—'))}${row('Days on Job',stats.days == null ? '—' : `${escape(stats.days)} days`,true)}${defaults.map(([label,value],i) => extra[i] ? row(extra[i].label,escape(extra[i].value)) : row(label,value)).join('')}</div><h3 class="tasks-caption">Task</h3><div class="task-list profile-tasks">${taskRows(tasks)}</div></section></article>`;
  }
  function render() {
    $('player-name').textContent = state.profile.name || '';
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
    try { await request('close'); } catch { $('center').hidden = false; notify('Unable to close. Please try again.'); }
  }
  async function changeJob(action) {
    if (state.busy) return;
    state.busy = true;
    const revision = state.revision;
    render();
    try {
      const result = await request(action, { job: state.selected });
      if (revision !== state.revision) return;
      if (!result.ok) { notify(result.message || 'Unable to change jobs. Please try again at the Job Center.'); return; }
      if (result.preview) {
        const j = action === 'quit' ? {name:'unemployed',label:'Unemployed',salary:200,gradeLabel:'Unemployed'} : state.jobs.find(j => j.name === state.selected);
        state.profile = {...state.profile,job:{...j,gradeLabel:j.gradeLabel || 'Recruit'}};
      } else if (result.profile) state.profile = result.profile;
      state.view = 'profile';
      notify(action === 'quit' ? 'You have left your job.' : 'Your new job is ready. Good luck!');
    } catch { if (revision === state.revision) notify('The server did not respond. Please try again.'); }
    finally { if (revision === state.revision) { state.busy = false; render(); } }
  }
  function hud(data) {
    $('task-hud').hidden = !data.visible;
    if (data.visible) $('task-hud').innerHTML = `${icon('tasks-large','hud-icon')}<h2 class="hud-title">Task</h2><p class="hud-subtitle"><em>${escape(data.grade || '')}</em></p><img class="hud-glow" src="assets/tasks-glow.svg" alt=""><div class="hud-tasks">${taskRows(data.tasks,true)}</div>`;
  }
  function toast(task) {
    clearTimeout(toastTimer);
    $('task-toast').innerHTML = `${icon('tasks-large','hud-icon')}<h2 class="hud-title">${escape(task.title)}</h2><p class="hud-subtitle">Progress task: <em>${escape(task.current ?? 0)}/${escape(task.target ?? 0)}</em></p><img class="toast-glow" src="assets/toast-glow.svg" alt=""><div class="toast-track"><span style="height:${progress(task)}%"></span></div>`;
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
      try { const result=await request('waypoint',{job:state.selected}); notify(result.ok ? 'Job location marked on your map.' : 'Location unavailable.'); } catch { notify('Unable to mark the location.'); }
    }
  });
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

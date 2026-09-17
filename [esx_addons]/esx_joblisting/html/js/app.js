/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
(() => {
  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'esx_joblisting';
  const get = (id) => document.getElementById(id);
  const app = get('app');
  const search = get('searchInput');
  const searchClear = get('searchClear');

  const lucide = window.lucide;

  const state = {
    open: false,
    jobs: [],
    currentJob: null,
    selectedJob: null,
    locale: {
      language: 'en',
      title: 'Job Centre',
      subtitle: 'Choose your career',
      search: 'Search',
      searchPlaceholder: 'Search jobs...',
      close: 'Close',
      currentTag: 'Current',
      salary: 'Salary',
      noJobs: 'No jobs are available right now.',
      noResults: 'No jobs match your search.',
      apply: 'Apply',
      confirmTitle: 'Apply for this job?',
      confirmYes: 'Confirm',
      confirmNo: 'Cancel',
      applied: 'New job assigned:',
      requestFailed: 'Action failed. Please try again.'
    }
  };

  const t = (key) => state.locale[key] || key;

  let toastTimer;
  let requestQueue = Promise.resolve();

  function icon(name, options = {}) {
    return lucide.createElement(lucide[name] || lucide.Wrench, {
      'aria-hidden': 'true',
      focusable: 'false',
      'stroke-width': 1.75,
      'data-lucide-icon': name,
      ...options
    });
  }

  function hydrate(root = document) {
    root.querySelectorAll('[data-icon]').forEach((node) => {
      const opts = {};
      if (node.dataset.iconFill === 'true') opts.fill = 'currentColor';
      node.replaceChildren(icon(node.dataset.icon, opts));
    });
  }

  async function fetchNui(action, data = {}) {
    const pending = requestQueue.then(async () => {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 10000);
      try {
        const result = await fetch(`https://${resourceName}/${action}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=UTF-8' },
          body: JSON.stringify(data),
          signal: controller.signal
        });
        if (!result.ok) throw new Error('NUI request failed');
        const json = await result.json();
        if (json && typeof json.ok === 'boolean') return json;
        return { ok: true, data: json };
      } catch {
        if (action !== 'close') showToast(t('requestFailed'), true);
        return { ok: true };
      } finally {
        clearTimeout(timer);
      }
    });
    requestQueue = pending.catch(() => ({ ok: true }));
    return requestQueue;
  }

  function updateSearchClear() {
    searchClear.classList.toggle('hidden', search.value.length === 0);
  }

  function showToast(message, error = false) {
    if (!message) return;
    const toast = get('toast');
    toast.textContent = message;
    toast.classList.remove('hidden');
    toast.classList.toggle('error', error);
    toast.classList.toggle('success', !error);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 2800);
  }

  function applyLocale() {
    document.documentElement.lang = t('language');
    get('jobTitle').textContent = t('title');
    get('jobSubtitle').textContent = t('subtitle');
    const closeBtn = get('closeBtn');
    closeBtn.setAttribute('aria-label', t('close'));
    closeBtn.dataset.tooltip = t('close');
    search.placeholder = t('searchPlaceholder');
    search.setAttribute('aria-label', t('search'));
    get('confirmTitle').textContent = t('confirmTitle');
    get('confirmYes').textContent = t('confirmYes');
    get('confirmNo').textContent = t('confirmNo');
  }

  function applyTheme(theme) {
    if (!theme) return;
    const root = document.documentElement;
    if (theme.primaryColor) root.style.setProperty('--brand-color', theme.primaryColor);
    if (theme.secondaryColor) root.style.setProperty('--dark-color', theme.secondaryColor);
    if (theme.backgroundColor) root.style.setProperty('--darkest-color', theme.backgroundColor);
    if (theme.accentColor) root.style.setProperty('--mid-color', theme.accentColor);
  }

  function rowJob(matches) {
    return state.jobs.filter((job) => {
      if (!matches) return true;
      const query = matches.toLowerCase();
      return (job.label || '').toLowerCase().includes(query) || (job.name || '').toLowerCase().includes(query);
    });
  }

  function fmtMoney(value) {
    return `$${Number(value).toLocaleString('en-US')}`;
  }

  function formatSalary(job) {
    const min = Number(job.salaryMin) || 0;
    const max = Number(job.salaryMax) || 0;
    if (max <= 0) return '';
    const range = min && min !== max ? `${fmtMoney(min)}–${fmtMoney(max)}` : fmtMoney(max);
    return `${t('salary')} · ${range}`;
  }

  function jobDetail(job) {
    return job.description || formatSalary(job);
  }

  function renderJobList() {
    const list = get('jobList');
    const query = search.value.trim();
    const matches = rowJob(query);

    list.innerHTML = '';

    if (state.jobs.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'list-empty';
      empty.append(icon('Inbox'));
      const msg = document.createElement('span');
      msg.textContent = t('noJobs');
      empty.append(msg);
      list.append(empty);
      return;
    }

    if (matches.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'list-empty';
      empty.append(icon('SearchX'));
      const msg = document.createElement('span');
      msg.textContent = t('noResults');
      empty.append(msg);
      list.append(empty);
      return;
    }

    const fragment = document.createDocumentFragment();

    matches.forEach((job) => {
      const isCurrent = state.currentJob && job.name === state.currentJob.name;

      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'job-row';
      if (isCurrent) row.classList.add('current');
      row.setAttribute('role', 'option');
      row.setAttribute('aria-selected', isCurrent ? 'true' : 'false');

      const iconEl = document.createElement('span');
      iconEl.className = 'job-icon';
      iconEl.append(icon(job.icon || 'Briefcase'));

      const name = document.createElement('span');
      name.className = 'job-name';
      name.textContent = job.label || job.name;
      const detail = jobDetail(job);
      if (detail) {
        const small = document.createElement('small');
        small.textContent = detail;
        name.append(small);
      }

      const right = document.createElement('span');
      right.className = 'job-right';

      if (isCurrent) {
        const tag = document.createElement('span');
        tag.className = 'job-tag';
        tag.append(icon('CircleCheck'));
        tag.append(t('currentTag'));
        right.append(tag);
      } else {
        const chevron = document.createElement('span');
        chevron.className = 'job-chevron';
        chevron.append(icon('ChevronRight'));
        right.append(chevron);
      }

      row.append(iconEl, name, right);
      row.addEventListener('click', () => openConfirm(job));
      fragment.append(row);
    });

    list.append(fragment);
  }

  function openConfirm(job) {
    state.selectedJob = job;
    get('confirmText').textContent = job.label || job.name;
    get('confirmYes').disabled = false;
    get('confirmModal').classList.remove('hidden');
  }

  function closeConfirm() {
    state.selectedJob = null;
    get('confirmModal').classList.add('hidden');
  }

  async function submitApply() {
    const job = state.selectedJob;
    if (!job) return;
    get('confirmYes').disabled = true;

    const response = await fetchNui('apply', { job: job.name });
    closeConfirm();
    renderJobList();

    if (response.ok && response.data && response.data.label) {
      showToast(`${t('applied')} ${response.data.label}`);
      setTimeout(() => fetchNui('close'), 1300);
    } else {
      showToast(t('requestFailed'), true);
    }
  }

  function open() {
    state.open = true;
    search.value = '';
    updateSearchClear();
    app.classList.remove('hidden');
    renderJobList();
  }

  function close() {
    state.open = false;
    state.selectedJob = null;
    closeConfirm();
    app.classList.add('hidden');
    get('toast').classList.add('hidden');
    clearTimeout(toastTimer);
  }

  function applyState(data) {
    if (data.locale) state.locale = { ...state.locale, ...data.locale };
    if (data.theme) applyTheme(data.theme);
    if (Array.isArray(data.jobs)) state.jobs = data.jobs;
    if (data.currentJob) state.currentJob = data.currentJob;
    else if (data.currentJob === null && data.hasOwnProperty('currentJob')) state.currentJob = null;
    applyLocale();
    if (state.open) renderJobList();
  }

  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'open') {
      applyState(data);
      open();
    } else if (data.action === 'close') {
      close();
    } else if (data.action === 'toast') {
      showToast(data.message, data.success === false);
    }
  });

  search.addEventListener('input', () => {
    updateSearchClear();
    renderJobList();
  });
  searchClear.addEventListener('click', () => {
    search.value = '';
    updateSearchClear();
    renderJobList();
    search.focus();
  });

  get('closeBtn').addEventListener('click', () => fetchNui('close'));
  get('confirmYes').addEventListener('click', submitApply);
  get('confirmNo').addEventListener('click', closeConfirm);

  document.addEventListener('keydown', (event) => {
    if (!state.open || event.repeat) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (!get('confirmModal').classList.contains('hidden')) {
        closeConfirm();
      } else {
        fetchNui('close');
      }
    } else if (event.key === 'Enter' && !get('confirmModal').classList.contains('hidden')) {
      event.preventDefault();
      submitApply();
    }
  });

  fetchNui('ready', {})
    .then((response) => {
      if (response.ok && response.data && response.data.theme) applyTheme(response.data.theme);
    })
    .catch(() => {});

  hydrate();
})();
/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
(() => {
  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'esx_animations';
  const { renderCategories: renderCatTabs, renderItems } = AnimationsUI.catalog;
  const { create, hydrate } = AnimationsUI.icons;
  const get = (id) => document.getElementById(id);
  const app = get('app');
  const search = get('searchInput');

  const state = {
    open: false,
    activeCategory: null,
    activeItem: null,
    playing: false,
    categories: [],
    locale: {
      language: 'en',
      title: 'Animations',
      categoryPlaceholder: 'Select a category',
      search: 'Search animations',
    noResults: 'No matching animations.',
    close: 'Close',
    stop: 'Stop Animation',
    idle: 'Select an animation',
    subtitle: 'Choose an animation',
      playing: 'Playing',
      requestFailed: 'Action failed. Please try again.'
    }
  };

  const t = (key) => state.locale[key] || key;
  let toastTimer;
  let requestQueue = Promise.resolve();

  function showToast(message, error = false) {
    if (!message || !state.open) return;
    const toast = get('toast');
    toast.textContent = message;
    toast.classList.remove('hidden');
    toast.classList.toggle('error', error);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 2600);
  }

  function fetchNui(action, data = {}) {
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
        if (json && typeof json.ok === 'boolean') {
          return json;
        }
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

  function labelButton(id, label) {
    const btn = get(id);
    if (btn) {
      btn.setAttribute('aria-label', label);
      btn.dataset.tooltip = label;
    }
  }

  function applyLocale() {
    document.documentElement.lang = t('language');
    get('animTitle').textContent = t('title');
    get('categoryName').textContent = t('subtitle') || 'Choose an animation';
    labelButton('closeBtn', t('close'));
    get('searchInput').placeholder = t('search');
    get('searchInput').setAttribute('aria-label', t('search'));
    renderStopButton();
  }

  function renderCategoryTabs() {
    renderCatTabs({
      container: get('categoryTabs'),
      categories: state.categories,
      active: state.activeCategory,
      t: t
    });
  }

  function renderItemList() {
    const cat = state.categories.find((c) => c.name === state.activeCategory);
    const items = (cat && cat.items) || [];
    renderItems({
      container: get('itemList'),
      items: items,
      active: state.activeItem,
      query: search.value,
      t: t,
      onSelect: (item) => playAnimation(item)
    });
  }

  function renderStopButton() {
    const btn = get('stopBtn');
    const iconSpan = btn.querySelector('[data-icon]');
    const labelSpan = btn.querySelector('.btn-label');

    if (state.playing) {
      btn.disabled = false;
      btn.classList.remove('idle');
      btn.classList.add('active');
      if (iconSpan) {
        iconSpan.dataset.icon = 'Square';
        iconSpan.dataset.iconFill = 'true';
      }
      if (labelSpan) labelSpan.textContent = t('stop');
    } else {
      btn.disabled = true;
      btn.classList.remove('active');
      btn.classList.add('idle');
      if (iconSpan) {
        iconSpan.dataset.icon = 'Play';
        iconSpan.dataset.iconFill = 'false';
      }
      if (labelSpan) labelSpan.textContent = t('idle');
    }
    hydrate(btn);
  }

  async function playAnimation(item) {
    if (!item) return;
    state.activeItem = item;
    state.playing = true;
    renderItemList();
    renderStopButton();

    const response = await fetchNui('play', item);
    if (!response.ok) {
      state.activeItem = null;
      state.playing = false;
      renderItemList();
    }
    renderStopButton();
  }

  function open() {
    state.open = true;
    state.activeCategory = state.categories.length > 0 ? state.categories[0].name : null;
    state.activeItem = null;
    state.playing = false;
    search.value = '';
    hideCategoryTooltip();
    app.classList.remove('hidden');
    renderCategoryTabs();
    renderItemList();
    renderStopButton();
  }

  function close() {
    state.open = false;
    state.playing = false;
    state.activeItem = null;
    hideCategoryTooltip();
    app.classList.add('hidden');
    get('toast').classList.add('hidden');
    clearTimeout(toastTimer);
  }

  function applyState(data) {
    if (data.locale) {
      state.locale = { ...state.locale, ...data.locale };
    }
    if (Array.isArray(data.categories)) {
      state.categories = data.categories;
    }
    if (data.playing !== undefined) {
      state.playing = data.playing;
    }
    if (data.activeItem !== undefined) {
      state.activeItem = data.activeItem;
    }
    if (data.currentCategory !== undefined) {
      state.activeCategory = data.currentCategory;
    }
    if (data.theme) {
      const root = document.documentElement;
      if (data.theme.primaryColor) root.style.setProperty('--brand-color', data.theme.primaryColor);
      if (data.theme.secondaryColor) root.style.setProperty('--dark-color', data.theme.secondaryColor);
      if (data.theme.backgroundColor) root.style.setProperty('--darkest-color', data.theme.backgroundColor);
      if (data.theme.accentColor) root.style.setProperty('--mid-color', data.theme.accentColor);
    }
    applyLocale();
    if (state.open) {
      renderCategoryTabs();
      renderItemList();
      renderStopButton();
    }
  }

  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;

    if (data.action === 'open') {
      applyState(data);
      open();
    } else if (data.action === 'close') {
      close();
    } else if (data.action === 'state') {
      applyState(data);
    } else if (data.action === 'toast') {
      showToast(data.message, data.success === false);
    }
  });

  // Category tooltip — floating label outside the scrolling rail
  const categoryRail = get('categoryTabs');
  let categoryTooltip = get('categoryTooltip');
  if (!categoryTooltip) {
    categoryTooltip = document.createElement('div');
    categoryTooltip.id = 'categoryTooltip';
    categoryTooltip.className = 'category-tooltip';
    categoryTooltip.setAttribute('role', 'tooltip');
    (document.querySelector('.anim-shell') || document.body).appendChild(categoryTooltip);
  }
  let tooltipTimer;

  function showCategoryTooltip(tab) {
    if (!categoryTooltip || !tab) return;
    const label = tab.getAttribute('data-label');
    if (!label) return;
    const anchor = categoryTooltip.offsetParent || document.querySelector('.anim-shell');
    const anchorRect = anchor.getBoundingClientRect();
    const tabRect = tab.getBoundingClientRect();
    categoryTooltip.textContent = label;
    categoryTooltip.style.left = `${tabRect.right - anchorRect.left + 8}px`;
    categoryTooltip.style.top = `${tabRect.top - anchorRect.top + tabRect.height / 2}px`;
    categoryTooltip.classList.add('visible');
  }

  function hideCategoryTooltip() {
    clearTimeout(tooltipTimer);
    if (categoryTooltip) categoryTooltip.classList.remove('visible');
  }

  categoryRail.addEventListener('mouseover', (event) => {
    const tab = event.target.closest('.category-tab');
    if (!tab) return;
    clearTimeout(tooltipTimer);
    tooltipTimer = setTimeout(() => showCategoryTooltip(tab), 160);
  });
  categoryRail.addEventListener('mouseout', (event) => {
    if (event.target.closest('.category-tab')) hideCategoryTooltip();
  });
  categoryRail.addEventListener('focusin', (event) => {
    const tab = event.target.closest('.category-tab');
    if (tab) showCategoryTooltip(tab);
  });
  categoryRail.addEventListener('focusout', hideCategoryTooltip);

  // Category selection
  document.addEventListener('categorySelect', (event) => {
    if (!state.open) return;
    state.activeCategory = event.detail.name;
    state.activeItem = null;
    state.playing = false;
    search.value = '';
    renderCategoryTabs();
    renderItemList();
    renderStopButton();
    fetchNui('category', { name: state.activeCategory });
  });

  // Search
  search.addEventListener('input', () => {
    renderItemList();
  });

  // Close button
  get('closeBtn').addEventListener('click', () => fetchNui('close'));

  // Stop button
  get('stopBtn').addEventListener('click', () => {
    if (state.playing) {
      state.playing = false;
      state.activeItem = null;
      fetchNui('stop');
      renderItemList();
      renderStopButton();
    }
  });

  // ESC key handling
  document.addEventListener('keydown', (event) => {
    if (!state.open || event.repeat) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      fetchNui('close');
    } else if (event.key === 'Backspace') {
      event.preventDefault();
      state.activeItem = null;
      state.playing = false;
      fetchNui('stop');
      renderItemList();
      renderStopButton();
    }
  });

  // Theme from convars — works before UI is open
  fetchNui('ready', {})
    .then((response) => {
      if (response.ok && response.data && response.data.theme) {
        const root = document.documentElement;
        const theme = response.data.theme;
        if (theme.primaryColor) root.style.setProperty('--brand-color', theme.primaryColor);
        if (theme.secondaryColor) root.style.setProperty('--dark-color', theme.secondaryColor);
        if (theme.backgroundColor) root.style.setProperty('--darkest-color', theme.backgroundColor);
        if (theme.accentColor) root.style.setProperty('--mid-color', theme.accentColor);
      }
    })
    .catch(() => {});

  hydrate();
})();

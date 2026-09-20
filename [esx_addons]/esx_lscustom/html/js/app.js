/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
(() => {
  const isLocalPreview = typeof GetParentResourceName !== 'function';
  const resourceName = isLocalPreview ? 'esx_lscustom' : GetParentResourceName();
  const { icons, catalog, createCart } = WorkshopUI;
  const get = (id) => document.getElementById(id);
  const app = get('app');
  const search = get('searchInput');
  const state = {
    currency: '$', menu: null, root: [], cart: [], total: 0, stats: null,
    active: null, layout: 'list', busy: false, open: false, parents: new Map(),
    locale: {
      language: 'en', camera: 'Camera', close: 'Close', view: 'View', front: 'Front', back: 'Rear', left: 'Left side', right: 'Right side',
      top: 'Top', free: 'Free', rotateLeft: 'Rotate left', rotateRight: 'Rotate right', zoomIn: 'Zoom in', zoomOut: 'Zoom out',
      stats: 'Vehicle stats', speed: 'Speed', accel: 'Acceleration', brake: 'Braking', handling: 'Handling',
      backButton: 'Back', add: 'Add', pay: 'Pay', cart: 'Cart', clear: 'Clear', total: 'Total', installed: 'Installed',
      noOptions: 'No options available.', emptyCart: 'No pending changes.', mod: 'Mod',
      customize: 'Customization', search: 'Search options', noResults: 'No matching options.', selection: 'Selection',
      inCart: 'In cart', addToCart: 'Add to cart', list: 'List', grid: 'Grid', requestFailed: 'Action failed. Please try again.',
      freeCameraHelp: 'Free camera | mouse: orbit | wheel: zoom | E: back'
    }
  };
  const t = (key) => state.locale[key] || key;
  const money = (amount) => `${state.currency}${Number(amount || 0).toLocaleString('en-US')}`;
  const cart = createCart({ t, money, onPay: () => request('checkout'), onClear: () => request('clearCart') });
  let toastTimer;
  let requestQueue = Promise.resolve();
  let session = 0;

  const previewMenus = {
    main: {
      id: 'main', title: 'LS CUSTOMS', parent: null,
      elements: [
        { label: 'Upgrades', value: 'upgrades', action: 'menu' },
        { label: 'Cosmetics', value: 'cosmetics', action: 'menu' },
        { label: 'Camera', value: 'cameraMenu', action: 'camera' },
        { label: 'Checkout cart', value: 'cartCheckout', action: 'checkout', disabled: true },
        { label: 'Clear cart', value: 'cartClear', action: 'clear' }
      ]
    },
    upgrades: {
      id: 'upgrades', title: 'Upgrades', parent: 'main',
      elements: [
        { label: 'Engine level 1', menuKey: 'modEngine', modType: 'modEngine', modNum: 0, price: 6975, action: 'mod' },
        { label: 'Brakes level 2', menuKey: 'modBrakes', modType: 'modBrakes', modNum: 1, price: 4650, action: 'mod' },
        { label: 'Transmission level 3', menuKey: 'modTransmission', modType: 'modTransmission', modNum: 2, price: 23255, action: 'mod' },
        { label: 'Turbo', menuKey: 'modTurbo', modType: 'modTurbo', modNum: true, price: 27905, action: 'mod' }
      ]
    },
    cosmetics: {
      id: 'cosmetics', title: 'Cosmetics', parent: 'main',
      elements: [
        { label: 'Primary respray', value: 'primaryRespray', action: 'menu', color: 'red' },
        { label: 'Window tint', menuKey: 'windowTint', modType: 'windowTint', modNum: 2, price: 2500, action: 'mod' },
        { label: 'Neon blue', menuKey: 'neonColor', modType: 'neonColor', modNum: [0, 80, 255], price: 3500, action: 'mod' },
        { label: 'Xenon lights', menuKey: 'modXenon', modType: 'modXenon', modNum: true, price: 4500, action: 'mod' }
      ]
    },
    primaryRespray: {
      id: 'primaryRespray', title: 'Primary respray', parent: 'cosmetics',
      elements: [
        { label: 'Classic red', menuKey: 'color1', modType: 'color1', modNum: 27, price: 3200, action: 'mod', color: 'red' },
        { label: 'Racing blue', menuKey: 'color1', modType: 'color1', modNum: 64, price: 3200, action: 'mod', color: 'blue' },
        { label: 'Matte black', menuKey: 'color1', modType: 'color1', modNum: 12, price: 3200, action: 'mod', color: 'black' }
      ]
    }
  };

  function showToast(message, error = false) {
    if (!message || !state.open) return;
    get('toast').textContent = message;
    get('toast').classList.remove('hidden');
    get('toast').classList.toggle('error', error);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => get('toast').classList.add('hidden'), 2600);
  }

  function setControlGuide(visible, message) {
    const guide = get('controlGuide');
    guide.textContent = message || t('freeCameraHelp');
    guide.classList.toggle('hidden', !visible);
  }

  // Serialize previews and mutations so a rapid selection cannot apply out of order.
  function request(action, data = {}) {
    if (!state.open) return Promise.resolve();
    if (isLocalPreview) return Promise.resolve(handlePreviewRequest(action, data));
    const requestSession = session;
    const mutation = ['addToCart', 'checkout', 'clearCart', 'openMenu'].includes(action);
    if (mutation && state.busy) return Promise.resolve();
    if (mutation) { state.busy = true; renderActions(); }
    const pending = requestQueue.then(async () => {
      if (requestSession !== session || !state.open) return;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 10000);
      try {
        const result = await fetch(`https://${resourceName}/${action}`, {
          method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
          body: JSON.stringify(data), signal: controller.signal
        });
        if (!result.ok) throw new Error('NUI request failed');
      } finally { clearTimeout(timer); }
    });
    requestQueue = pending.catch(() => {
      if (requestSession === session) showToast(t('requestFailed'), true);
    }).finally(() => {
      if (mutation && requestSession === session) { state.busy = false; renderActions(); }
    });
    return requestQueue;
  }

  function updatePreviewCheckoutState() {
    previewMenus.main.elements.forEach((item) => {
      if (item.action === 'checkout') item.disabled = state.total <= 0;
    });
  }

  function handlePreviewRequest(action, data = {}) {
    if (action === 'openMenu') {
      updatePreviewCheckoutState();
      applyServerState({ menu: previewMenus[data.value] || previewMenus.cosmetics, root: previewMenus.main.elements, cart: state.cart, total: state.total, stats: state.stats });
    } else if (action === 'preview') {
      state.active = data;
      applyServerState({
        stats: {
          speed: { value: 72, delta: data.modType === 'modTurbo' ? 8 : 1 },
          accel: { value: 68, delta: data.modType === 'modTurbo' ? 12 : 2 },
          brake: { value: 58, delta: data.modType === 'modBrakes' ? 9 : 0 },
          handling: { value: 61, delta: 1 }
        }
      });
    } else if (action === 'addToCart') {
      if (!catalog.isQueued(data, state.cart)) state.cart = [...state.cart, data];
      state.total = state.cart.reduce((sum, item) => sum + Number(item.price || 0), 0);
      updatePreviewCheckoutState();
      applyServerState({ menu: state.menu, cart: state.cart, total: state.total });
      showToast(`${t('addToCart')}: ${money(data.price)}`);
    } else if (action === 'clearCart') {
      state.cart = [];
      state.total = 0;
      updatePreviewCheckoutState();
      applyServerState({ menu: state.menu, cart: state.cart, total: state.total });
      showToast('Cart cleared.');
    } else if (action === 'checkout') {
      showToast(state.total > 0 ? `Preview payment: ${money(state.total)}` : t('emptyCart'), state.total <= 0);
    } else if (action === 'camera') {
      const view = data.value === 'free' ? 'free' : data.value || 'default';
      setCamera(view);
      setControlGuide(view === 'free');
    } else if (action === 'close') {
      app.classList.add('hidden');
      state.open = false;
    }
  }

  function labelButton(id, label) {
    get(id).setAttribute('aria-label', label);
    get(id).dataset.tooltip = label;
  }

  function applyLocale() {
    document.documentElement.lang = t('language');
    get('cameraDock').setAttribute('aria-label', t('camera'));
    labelButton('closeBtn', t('close'));
    labelButton('cartCloseBtn', t('close'));
    labelButton('clearBtn', t('clear'));
    labelButton('backBtn', t('backButton'));
    labelButton('listViewBtn', t('list'));
    labelButton('gridViewBtn', t('grid'));
    get('rail').setAttribute('aria-label', t('customize'));
    get('statsPanel').setAttribute('aria-label', t('stats'));
    get('statsTitle').textContent = t('stats');
    get('selectionLabel').textContent = t('selection');
    search.placeholder = t('search');
    search.setAttribute('aria-label', t('search'));
    for (const [name, key] of Object.entries({ Speed: 'speed', Accel: 'accel', Brake: 'brake', Handling: 'handling' })) {
      get(`label${name}`).textContent = t(key);
    }
    document.querySelectorAll('[data-camera]').forEach((button) => {
      const key = button.dataset.camera === 'default' ? 'view' : button.dataset.camera;
      button.dataset.tooltip = t(key);
      button.setAttribute('aria-label', t(key));
    });
  }

  function renderStats(stats) {
    for (const [name, key] of Object.entries({ Speed: 'speed', Accel: 'accel', Brake: 'brake', Handling: 'handling' })) {
      const value = Math.max(0, Math.min(100, Number(stats?.[key]?.value) || 0));
      const delta = Math.round(Number(stats?.[key]?.delta) || 0);
      get(`stat${name}`).style.width = `${value}%`;
      get(`stat${name}Value`).textContent = `${Math.round(value)}${delta > 0 ? ` +${delta}` : ''}`;
      get(`stat${name}Value`).classList.toggle('up', delta > 0);
    }
  }

  function renderActions() {
    const item = state.active;
    const queued = item && catalog.isQueued(item, state.cart);
    get('selectionName').textContent = item?.label || '--';
    get('selectionPrice').textContent = item ? money(item.price) : '--';
    get('addBtn').disabled = state.busy || !item || item.installed || item.disabled || queued;
    get('addBtn').querySelector('[data-label]').textContent = t(queued ? 'inCart' : item?.installed ? 'installed' : 'addToCart');
    get('backBtn').hidden = !state.menu?.parent || state.menu.parent === 'main';
    get('backBtn').disabled = state.busy;
    cart.render(state.cart, state.total, state.busy);
  }

  function renderRail() {
    let ancestor = state.menu?.id;
    const visited = new Set();
    while (state.parents.get(ancestor) && state.parents.get(ancestor) !== 'main' && !visited.has(ancestor)) {
      visited.add(ancestor);
      ancestor = state.parents.get(ancestor);
    }
    get('rail').replaceChildren(...state.root.filter((item) => item.action === 'menu').map((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'category-tab';
      button.classList.toggle('active', ancestor === item.value);
      button.setAttribute('aria-pressed', String(ancestor === item.value));
      button.disabled = Boolean(item.disabled);
      button.append(icons.create(icons.forItem(item)), catalog.text('', item.label));
      button.addEventListener('click', () => request('openMenu', { value: item.value }));
      return button;
    }));
  }

  function renderOptions() {
    const items = (state.menu?.elements || []).filter((item) => item.action === 'mod' || (item.action === 'menu' && state.menu?.id !== 'main'));
    get('optionCount').textContent = catalog.render({
      container: get('optionList'), items, cart: state.cart, active: state.active,
      query: search.value, layout: state.layout, t, money,
      onSelect: (item) => {
        if (state.busy || item.disabled) return false;
        if (item.action === 'menu') {
          request('openMenu', { value: item.value, color: item.color });
        } else {
          state.active = item;
          // Installed options are previewable too, allowing a return to the original finish.
          request('preview', item);
          renderActions();
        }
      }
    });
  }

  function applyServerState(data) {
    if (data.locale) state.locale = { ...state.locale, ...data.locale };
    if (data.currency) state.currency = data.currency;
    if (Array.isArray(data.cart)) state.cart = data.cart;
    if (Array.isArray(data.root)) state.root = data.root;
    if (typeof data.total === 'number') state.total = data.total;
    if (data.menu) {
      const changed = data.menu.id !== state.menu?.id;
      const previous = state.active && catalog.key(state.active);
      state.menu = data.menu;
      state.parents.set(data.menu.id, data.menu.parent);
      if (data.menu.id === 'main') state.root = data.menu.elements;
      state.active = changed ? null : data.menu.elements.find((item) => catalog.key(item) === previous) || null;
      if (changed) { search.value = ''; get('optionList').scrollTop = 0; }
    }
    if (data.stats) state.stats = data.stats;
    if (data.features) {
      get('cameraDock').hidden = data.features.camera === false;
      get('statsPanel').hidden = data.features.stats === false;
    }
    applyLocale();
    get('menuTitle').textContent = state.menu?.id === 'main' ? t('customize') : state.menu?.title || t('customize');
    get('headingIcon').replaceChildren(icons.create(icons.forItem({ value: state.menu?.id })));
    renderRail();
    renderOptions();
    renderActions();
    renderStats(state.stats);
  }

  function setCamera(view) {
    document.querySelectorAll('[data-camera][aria-pressed]').forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.camera === view));
    });
  }

  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'open') {
      session += 1;
      state.open = true;
      state.menu = null;
      state.root = [];
      state.active = null;
      state.busy = false;
      state.parents.clear();
      search.value = '';
      cart.setOpen(false, false);
      setCamera('default');
      get('vehicleName').textContent = data.subtitle || 'VEHICLE';
      app.classList.remove('hidden');
      setControlGuide(false);
      applyServerState(data);
    } else if (data.action === 'close') {
      session += 1;
      state.open = false;
      state.busy = false;
      cart.setOpen(false, false);
      app.classList.add('hidden');
      get('toast').classList.add('hidden');
      setControlGuide(false);
      clearTimeout(toastTimer);
    } else if (!state.open) {
      return;
    } else if (data.action === 'state') {
      applyServerState(data);
    } else if (data.action === 'stats') {
      state.stats = data.stats;
      renderStats(state.stats);
    } else if (data.action === 'cameraState') {
      setCamera(data.view);
      setControlGuide(data.view === 'free');
    } else if (data.action === 'controlGuide') {
      setControlGuide(data.visible === true, data.message);
    } else if (data.action === 'toast' || data.action === 'purchaseResult') {
      showToast(data.message, data.success === false);
    }
  });

  search.addEventListener('input', renderOptions);
  get('addBtn').addEventListener('click', () => {
    if (state.active && !get('addBtn').disabled) request('addToCart', state.active);
  });
  get('closeBtn').addEventListener('click', () => request('close'));
  get('backBtn').addEventListener('click', () => {
    if (state.menu?.parent && state.menu.parent !== 'main') request('openMenu', { value: state.menu.parent });
  });
  for (const layout of ['list', 'grid']) {
    get(`${layout}ViewBtn`).addEventListener('click', () => {
      state.layout = layout;
      get('listViewBtn').setAttribute('aria-pressed', String(layout === 'list'));
      get('gridViewBtn').setAttribute('aria-pressed', String(layout === 'grid'));
      renderOptions();
    });
  }
  document.querySelectorAll('[data-camera]').forEach((button) => {
    button.addEventListener('click', () => request('camera', { value: button.dataset.camera }));
  });
  document.addEventListener('keydown', (event) => {
    if (!state.open || event.repeat) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (cart.isOpen()) cart.setOpen(false);
      else if (search.value) { search.value = ''; renderOptions(); }
      else request('close');
    } else if (event.key === 'Backspace' && event.target.tagName !== 'INPUT' && !event.target.isContentEditable && state.menu?.parent) {
      event.preventDefault();
      if (state.menu.parent !== 'main') request('openMenu', { value: state.menu.parent });
    }
  });
  icons.hydrate();

  if (isLocalPreview) {
    window.dispatchEvent(new MessageEvent('message', {
      data: {
        action: 'open',
        title: 'LS CUSTOMS',
        subtitle: 'LOCAL PREVIEW',
        features: { camera: true, stats: true },
        menu: previewMenus.cosmetics,
        root: previewMenus.main.elements,
        cart: [],
        total: 0,
        currency: '$',
        stats: {
          speed: { value: 64, delta: 0 },
          accel: { value: 56, delta: 0 },
          brake: { value: 48, delta: 0 },
          handling: { value: 52, delta: 0 }
        }
      }
    }));
  }
})();

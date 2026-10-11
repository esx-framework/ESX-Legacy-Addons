/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
WorkshopUI.catalog = (() => {
  const { create, forItem } = WorkshopUI.icons;
  const colors = {
    black: '#151515', white: '#f2f2f2', grey: '#969696', red: '#d44242', pink: '#ea8db6',
    blue: '#4981bb', yellow: '#e9cb54', green: '#54955d', orange: '#fb9b04', brown: '#81563a',
    purple: '#8f6bb0', chrome: '#c5cbd0', gold: '#c8a451'
  };
  const identity = (item) => JSON.stringify([item?.modType, item?.modNum, item?.wheelType]);
  const key = (item) => JSON.stringify([item?.value, item?.color, item?.menuKey, identity(item)]);
  const isQueued = (item, cart) => Boolean(item.modType) && cart.some((entry) => identity(entry) === identity(item));

  function text(className, value, tag = 'span') {
    const node = document.createElement(tag);
    node.className = className;
    node.textContent = value;
    return node;
  }

  function visual(item) {
    const node = text('option-icon', '');
    const rgb = item.modNum;
    let color = colors[item.color];
    if (['neonColor', 'tyreSmokeColor'].includes(item.modType) && Array.isArray(rgb) && rgb.length === 3 && rgb.every((v) => Number.isFinite(v) && v >= 0 && v <= 255)) {
      color = `rgb(${rgb.join(',')})`;
    }
    if (color) {
      const swatch = text('color-swatch', '');
      swatch.style.backgroundColor = color;
      node.append(swatch);
    } else {
      node.append(create(forItem(item)));
    }
    return node;
  }

  function render({ container, items, cart, active, query, layout, t, money, onSelect }) {
    const term = query.trim().toLocaleLowerCase();
    const filtered = items.filter((item) => String(item.label || '').toLocaleLowerCase().includes(term));
    const grid = document.createElement('div');
    grid.className = `option-grid${layout === 'grid' ? ' tiles' : ''}`;
    const activeKey = active && key(active);

    filtered.forEach((item) => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'option-row';
      row.dataset.key = key(item);
      row.disabled = Boolean(item.disabled);
      const selected = row.dataset.key === activeKey;
      row.classList.toggle('active', selected);
      if (item.action === 'mod') row.setAttribute('aria-pressed', String(selected));

      const copy = text('option-copy', '');
      copy.append(text('option-name', item.label || t('mod')));
      const meta = text('option-meta', '');
      const queued = isQueued(item, cart);
      if (queued || item.installed) {
        const status = text(`status-tag${queued ? ' queued' : ''}`, '');
        status.append(create(queued ? 'ShoppingCart' : 'Check'), document.createTextNode(t(queued ? 'inCart' : 'installed')));
        meta.append(status);
      } else if (item.action === 'mod') {
        meta.append(text('option-price', money(item.price)));
      }
      if (meta.childNodes.length) copy.append(meta);
      const indicator = text('option-indicator', '');
      indicator.append(create(item.action === 'menu' ? 'ChevronRight' : selected ? 'CircleCheck' : 'Circle'));
      row.append(visual(item), copy, indicator);
      row.addEventListener('click', () => {
        if (onSelect(item) === false) return;
        if (item.action === 'mod') {
          grid.querySelectorAll('.option-row').forEach((other) => {
            other.classList.toggle('active', other === row);
            other.setAttribute('aria-pressed', String(other === row));
            other.querySelector('.option-indicator').replaceChildren(create(other === row ? 'CircleCheck' : 'Circle'));
          });
        }
      });
      grid.append(row);
    });

    if (!filtered.length) {
      const empty = text('list-empty', '');
      empty.append(create(term ? 'SearchX' : 'Wrench'), text('', t(term ? 'noResults' : 'noOptions'), 'p'));
      container.replaceChildren(empty);
    } else {
      container.replaceChildren(grid);
    }
    return filtered.length;
  }

  return { render, key, isQueued, text };
})();

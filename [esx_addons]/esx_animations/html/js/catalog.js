/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
AnimationsUI.catalog = (() => {
  const { create, forItem } = AnimationsUI.icons;

  function text(className, value, tag = 'span') {
    const node = document.createElement(tag);
    node.className = className;
    node.textContent = value;
    return node;
  }

  function typeBadge(type) {
    return text('type-badge', type);
  }

   function renderCategories({ container, categories, active, t }) {
     container.replaceChildren(...categories.map((cat) => {
       const button = document.createElement('button');
       button.type = 'button';
       button.className = 'category-tab';
       const isActive = active === cat.name;
       button.classList.toggle('active', isActive);
       button.setAttribute('aria-pressed', String(isActive));
       button.setAttribute('data-label', cat.label);
       button.setAttribute('aria-label', cat.label);
       button.append(create(forItem(cat)));
       button.addEventListener('click', () => {
         const event = new CustomEvent('categorySelect', { detail: { name: cat.name } });
         document.dispatchEvent(event);
       });
       return button;
     }));
   }

  function renderItems({ container, items, active, query, t, onSelect }) {
    const term = query.trim().toLocaleLowerCase();
    const filtered = items.filter((item) =>
      String(item.label || '').toLocaleLowerCase().includes(term)
    );

    const activeKey = active && active.name;
    const rows = filtered.map((item) => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'item-row';
      const selected = activeKey === item.name;
      row.classList.toggle('active', selected);

      const icon = text('item-icon', '');
      icon.append(create(forItem({ type: item.type })));

      const name = text('item-name', item.label || t('itemLabel'));
      const badge = typeBadge(item.type || t('unknown'));

      row.append(icon, name, badge);
      row.addEventListener('click', () => onSelect(item));
      return row;
    });

    container.replaceChildren(...rows);

    if (!rows.length) {
      const empty = text('list-empty', '');
      empty.append(create('Search'), text('', t('noResults'), 'p'));
      container.appendChild(empty);
    }

    return filtered.length;
  }

  return { renderCategories, renderItems, text };
})();

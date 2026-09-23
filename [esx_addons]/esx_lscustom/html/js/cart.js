/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
WorkshopUI.createCart = ({ t, money, onPay, onClear }) => {
  const { create, forItem } = WorkshopUI.icons;
  const { text } = WorkshopUI.catalog;
  const panel = document.getElementById('cartPanel');
  const toggle = document.getElementById('cartToggle');
  const list = document.getElementById('cartList');
  const pay = document.getElementById('payBtn');
  const clear = document.getElementById('clearBtn');

  function setOpen(open, focus = true) {
    panel.hidden = !open;
    toggle.setAttribute('aria-expanded', String(open));
    if (focus) (open ? document.getElementById('cartCloseBtn') : toggle).focus({ preventScroll: true });
  }

  function render(items, total, busy) {
    const rows = items.map((item) => {
      const row = document.createElement('div');
      row.className = 'cart-item';
      row.append(create(forItem(item)), text('', item.label || t('mod')), text('', money(item.price), 'b'));
      return row;
    });
    if (!rows.length) {
      const empty = text('cart-empty', '');
      empty.append(create('ShoppingCart'), text('', t('emptyCart'), 'p'));
      rows.push(empty);
    }
    list.replaceChildren(...rows);
    document.getElementById('cartTitle').textContent = t('cart');
    document.getElementById('cartTotalLabel').textContent = t('total');
    document.getElementById('cartTotal').textContent = money(total);
    document.getElementById('cartCount').textContent = items.length;
    const badge = document.getElementById('cartBadge');
    badge.textContent = items.length > 99 ? '99+' : items.length;
    badge.hidden = !items.length;
    toggle.setAttribute('aria-label', `${t('cart')}: ${items.length}, ${money(total)}`);
    toggle.dataset.tooltip = `${t('cart')} ${money(total)}`;
    pay.querySelector('[data-label]').textContent = t('pay');
    pay.disabled = busy || !items.length || total <= 0;
    clear.disabled = busy || !items.length;
  }

  toggle.addEventListener('click', () => setOpen(panel.hidden));
  document.getElementById('cartCloseBtn').addEventListener('click', () => setOpen(false));
  document.addEventListener('pointerdown', (event) => {
    if (!panel.hidden && !panel.contains(event.target) && !toggle.contains(event.target)) setOpen(false, false);
  });
  pay.addEventListener('click', onPay);
  clear.addEventListener('click', onClear);
  return { render, setOpen, isOpen: () => !panel.hidden };
};

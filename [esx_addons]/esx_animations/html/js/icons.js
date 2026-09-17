/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
window.AnimationsUI = window.AnimationsUI || {};

AnimationsUI.icons = (() => {
  const names = {
    festives: 'PartyPopper',
    greetings: 'Handshake',
    work: 'Briefcase',
    humors: 'Smile',
    sports: 'Dumbbell',
    misc: 'Box',
    attitudem: 'User',
    porn: 'AlertTriangle',
    anim: 'Play',
    scenario: 'PlaySquare',
    attitude: 'PersonStanding'
  };

  function forItem(item) {
    if (item && item.type) {
      return names[item.type] || 'Play';
    }
    const key = item && (item.name || item.value);
    return names[key] || 'Wrench';
  }

  function create(name, options = {}) {
    return lucide.createElement(lucide[name] || lucide.Wrench, {
      'aria-hidden': 'true', focusable: 'false', 'stroke-width': 1.75,
      'data-lucide-icon': name, ...options
    });
  }

  function hydrate(root = document) {
    root.querySelectorAll('[data-icon]').forEach((node) => {
      const opts = {};
      if (node.dataset.iconFill === 'true') opts.fill = 'currentColor';
      node.replaceChildren(create(node.dataset.icon, opts));
    });
  }

  return { create, forItem, hydrate };
})();

/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework */
window.WorkshopUI = window.WorkshopUI || {};

WorkshopUI.icons = (() => {
  const names = {
    main: 'Wrench', upgrades: 'SlidersHorizontal', cosmetics: 'Paintbrush',
    cartCheckout: 'ShoppingCart', cartClear: 'Trash2', vehicleStats: 'Gauge', cameraMenu: 'Camera',
    modEngine: 'Gauge', modEngineBlock: 'Cog', modBrakes: 'Disc3', modTransmission: 'Cog',
    modSuspension: 'BetweenVerticalStart', modArmor: 'ShieldCheck', modTurbo: 'Zap',
    bodyparts: 'Car', windowTint: 'PanelsTopLeft', modHorns: 'Volume2', neonColor: 'Lightbulb',
    resprays: 'Paintbrush', primaryRespray: 'PaintBucket', secondaryRespray: 'PaintBucket',
    pearlescentRespray: 'Palette', color1: 'PaintBucket', color2: 'PaintBucket', pearlescentColor: 'Palette',
    xenonColor: 'Lamp', modXenon: 'Lamp', plateIndex: 'RectangleEllipsis', wheels: 'Disc3',
    modFrontWheelsColor: 'Palette', wheelColor: 'Palette', tyreSmokeColor: 'Cloud',
    modPlateHolder: 'RectangleEllipsis', modVanityPlate: 'RectangleEllipsis', modTrimA: 'Car',
    modOrnaments: 'Gem', modDashboard: 'PanelsTopLeft', modDial: 'Gauge', modDoorSpeaker: 'Speaker',
    modSeats: 'Armchair', modSteeringWheel: 'ShipWheel', modShifterLeavers: 'GitFork',
    modAPlate: 'RectangleEllipsis', modSpeakers: 'Speaker', modTrunk: 'PackageOpen',
    modHydrolic: 'ArrowUpDown', modAirFilter: 'Wind', modStruts: 'BetweenVerticalStart',
    modArchCover: 'CircleDashed', modAerials: 'Antenna', modTrimB: 'Car', modTank: 'Fuel',
    modWindows: 'PanelsTopLeft', modLivery: 'Sticker', modSpoilers: 'Rows2',
    modFrontBumper: 'CarFront', modRearBumper: 'Car', modSideSkirt: 'Car', modExhaust: 'Wind',
    modFrame: 'Shield', modGrille: 'Grid2X2', modHood: 'CarFront', modFender: 'CircleDashed',
    modRightFender: 'CircleDashed', modRoof: 'Car'
  };

  function forItem(item = {}) {
    const key = item.menuKey || item.modType || item.value;
    return names[key] || (/Wheels/.test(key) ? 'Disc3' : 'Wrench');
  }

  function create(name) {
    return lucide.createElement(lucide[name] || lucide.Wrench, {
      'aria-hidden': 'true', focusable: 'false', 'stroke-width': 1.75,
      'data-lucide-icon': name
    });
  }

  function hydrate(root = document) {
    root.querySelectorAll('[data-icon]').forEach((node) => node.replaceChildren(create(node.dataset.icon)));
  }

  return { create, forItem, hydrate };
})();

/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { ShopCategory, ShopData, ShopItem, ShopLocales, ShopMode, WeaponDetailsTab, WeaponUpgrades, WeaponState } from '@/types/shop';
import { getDocsWeaponImage } from '@utils/weaponImage';

const EMPTY_UPGRADES: WeaponUpgrades = {
  supported: true,
  ammo: null,
  components: [],
  tints: []
};

const EMPTY_STATE: WeaponState = {
  owned: false,
  ammo: 0,
  tintIndex: 0,
  components: []
};

const PISTOL_UPGRADES: WeaponUpgrades = {
  supported: true,
  ammo: {
    label: 'Rounds',
    pricePerRound: 5,
    defaultAmount: 30,
    minAmount: 1,
    maxAmount: 250,
    quickAmounts: [30, 60, 120, 250],
    maxAmmo: 250
  },
  components: [
    { name: 'clip_extended', label: 'Extended Clip', price: 650 },
    { name: 'flashlight', label: 'Flashlight', price: 250 },
    { name: 'suppressor', label: 'Suppressor', price: 1250 },
    { name: 'luxary_finish', label: 'Luxury Finish', price: 1800 }
  ],
  tints: [
    { index: 0, label: 'Default', price: 0, color: '#9A9A9A' },
    { index: 1, label: 'Green', price: 250, color: '#3E8F45' },
    { index: 2, label: 'Gold', price: 750, color: '#D6A536' },
    { index: 3, label: 'Pink', price: 350, color: '#D96AA7' },
    { index: 4, label: 'Army', price: 450, color: '#6C7A45' },
    { index: 5, label: 'LSPD', price: 500, color: '#3A6EA5' },
    { index: 6, label: 'Orange', price: 400, color: '#D87522' },
    { index: 7, label: 'Platinum', price: 900, color: '#D8DDE2' }
  ]
};

const OWNED_PISTOL_STATE: WeaponState = {
  owned: true,
  ammo: 42,
  tintIndex: 0,
  components: ['flashlight']
};

/**
 * Mock data for development - Categories
 */
const MOCK_CATEGORIES: ShopCategory[] = [
  { id: 'all', label: 'All' },
  { id: 'handguns', label: 'Handguns' },
  { id: 'melee', label: 'Melee' },
  { id: 'rifles', label: 'Rifles' },
  { id: 'misc', label: 'Misc' }
];

/**
 * Mock data for development - Items
 * Images always come from FiveM docs in the browser
 */
const MOCK_ITEMS: ShopItem[] = [
  { name: 'WEAPON_PISTOL', label: 'Pistol', price: 500, category: 'handguns', image: getDocsWeaponImage('WEAPON_PISTOL'), upgrades: PISTOL_UPGRADES, state: OWNED_PISTOL_STATE },
  { name: 'WEAPON_COMBATPISTOL', label: 'Combat Pistol', price: 800, category: 'handguns', image: getDocsWeaponImage('WEAPON_COMBATPISTOL'), upgrades: PISTOL_UPGRADES, state: EMPTY_STATE },
  { name: 'WEAPON_BAT', label: 'Baseball Bat', price: 50, category: 'melee', image: getDocsWeaponImage('WEAPON_BAT'), upgrades: EMPTY_UPGRADES, state: EMPTY_STATE },
  { name: 'WEAPON_MACHETE', label: 'Machete', price: 110, category: 'melee', image: getDocsWeaponImage('WEAPON_MACHETE'), upgrades: EMPTY_UPGRADES, state: EMPTY_STATE },
  { name: 'WEAPON_ASSAULTRIFLE', label: 'Assault Rifle', price: 11000, category: 'rifles', image: getDocsWeaponImage('WEAPON_ASSAULTRIFLE'), upgrades: PISTOL_UPGRADES, state: EMPTY_STATE },
  { name: 'WEAPON_CARBINERIFLE', label: 'Carbine Rifle', price: 13000, category: 'rifles', image: getDocsWeaponImage('WEAPON_CARBINERIFLE'), upgrades: PISTOL_UPGRADES, state: EMPTY_STATE },
  { name: 'WEAPON_FIREEXTINGUISHER', label: 'Fire Extinguisher', price: 100, category: 'misc', image: getDocsWeaponImage('WEAPON_FIREEXTINGUISHER'), upgrades: EMPTY_UPGRADES, state: EMPTY_STATE }
];

const DEFAULT_LOCALES: ShopLocales = {
  searchPlaceholder: 'Search weapons...',
  buy: 'Buy',
  apply: 'Apply',
  owned: 'Owned',
  equipped: 'Equipped',
  unavailable: 'Unavailable',
  noWeaponSelected: 'Select a weapon to inspect',
  noImageAvailable: 'No image available',
  licenseTitle: 'License Shop',
  licenseDescription: 'A weapon license is required to purchase from this shop.',
  buyLicense: 'Buy weapon license?',
  cancel: 'Cancel',
  tabWeapon: 'Weapon',
  tabAmmo: 'Ammo',
  tabComponents: 'Attachments',
  tabTints: 'Tints',
  ammo: 'Ammo',
  ammoUnit: 'rounds',
  pricePerRound: 'Per round',
  total: 'Total',
  buyAmmo: 'Buy Ammo',
  ammoFull: 'Ammo full',
  components: 'Attachments',
  tints: 'Tints',
  requiresWeapon: 'Buy this weapon first',
  noAmmoAvailable: 'Ammo is not available for this weapon',
  noComponentsAvailable: 'No attachments available',
  noTintsAvailable: 'No tints available'
};

/**
 * Shop Store - Centralized state management using Svelte 5 runes
 * Note: Use within .svelte components to access reactive state
 */
class ShopStore {
  /** Available items in shop */
  items: ShopItem[] = $state([]);

  /** Available categories */
  categories: ShopCategory[] = $state([]);

  /** Currently active category filter */
  activeCategory: string = $state('all');

  /** Search query for filtering items */
  searchQuery: string = $state('');

  /** Shop display name */
  shopName: string = $state('Ammu-Nation');

  /** Whether this is a legal shop */
  legal: boolean = $state(true);

  /** Current NUI view mode */
  mode: ShopMode = $state('shop');

  /** Weapon license price */
  licensePrice: number = $state(5000);

  /** Configured fallback image for missing weapon pictures */
  fallbackImage: string = $state('');

  /** Localized UI strings */
  locales: ShopLocales = $state(DEFAULT_LOCALES);

  /** Currently selected weapon name */
  selectedName: string | null = $state(null);

  /** Whether a purchase request is in flight */
  buying: boolean = $state(false);

  /** Active details panel tab */
  activeDetailsTab: WeaponDetailsTab = $state('weapon');

  /** Selected ammo amount for the ammo tab */
  ammoAmount: number = $state(30);

  /**
   * Filtered items based on category and search
   * Uses $derived for automatic memoization and performance
   */
  filteredItems: ShopItem[] = $derived.by(() => {
    let result = this.items;

    if (this.activeCategory !== 'all') {
      result = result.filter((item: ShopItem) => item.category === this.activeCategory);
    }

    const query = this.searchQuery.trim().toLowerCase();
    if (query) {
      result = result.filter((item: ShopItem) =>
        item.label.toLowerCase().includes(query) ||
        item.name.toLowerCase().includes(query)
      );
    }

    return result;
  });

  /**
   * Currently selected weapon, if any
   */
  selectedItem: ShopItem | null = $derived.by(() => {
    if (!this.selectedName) {
      return null;
    }

    return this.items.find((item: ShopItem) => item.name === this.selectedName) ?? null;
  });

  /**
   * Maximum ammo amount currently purchasable for the selected weapon.
   */
  ammoPurchaseLimit: number = $derived.by(() => {
    const item = this.selectedItem;
    const ammo = item?.upgrades.ammo;

    if (!item || !ammo) {
      return 0;
    }

    const configuredMax = this.getWeaponAmmoLimit(ammo);
    if (configuredMax === null) {
      return ammo.maxAmount;
    }

    const currentAmmo = item.state.owned ? item.state.ammo : 0;
    const remainingAmmo = Math.max(configuredMax - currentAmmo, 0);

    return Math.min(ammo.maxAmount, remainingAmmo);
  });

  /**
   * Whether the selected ammo amount can be bought now.
   */
  canBuySelectedAmmo: boolean = $derived.by(() => {
    const ammo = this.selectedItem?.upgrades.ammo;

    return Boolean(
      this.selectedItem?.state.owned &&
      ammo &&
      this.ammoPurchaseLimit >= ammo.minAmount &&
      this.ammoAmount >= ammo.minAmount &&
      this.ammoAmount <= this.ammoPurchaseLimit
    );
  });

  private getWeaponAmmoLimit(ammo: NonNullable<ShopItem['upgrades']['ammo']>): number | null {
    return typeof ammo.maxAmmo === 'number' && Number.isFinite(ammo.maxAmmo) && ammo.maxAmmo > 0
      ? Math.floor(ammo.maxAmmo)
      : null;
  }

  /**
   * Sets shop data from external source (NUI)
   * @param data - Shop configuration data
   */
  setShopData(data: ShopData): void {
    this.items = data.items;
    this.categories = data.categories;
    this.shopName = data.shopName;
    this.legal = data.legal;
    this.mode = data.mode;
    this.licensePrice = data.licensePrice;
    this.fallbackImage = typeof data.fallbackImage === 'string' ? data.fallbackImage : '';
    this.locales = data.locales;
    this.activeCategory = 'all';
    this.searchQuery = '';
    this.buying = false;
    this.activeDetailsTab = 'weapon';
    this.selectedName = data.selectedName && data.items.some((item) => item.name === data.selectedName)
      ? data.selectedName
      : (data.items[0]?.name ?? null);
    this.syncAmmoAmount();
  }

  /**
   * Loads mock data for development
   */
  loadMockData(): void {
    this.items = MOCK_ITEMS;
    this.categories = MOCK_CATEGORIES;
    this.fallbackImage = '';
    this.selectedName = MOCK_ITEMS[0]?.name ?? null;
    this.syncAmmoAmount();
  }

  /**
   * Sets active category filter
   * @param categoryId - Category identifier
   */
  setActiveCategory(categoryId: string): void {
    this.activeCategory = categoryId;
  }

  /**
   * Updates search query
   * @param query - Search string
   */
  setSearchQuery(query: string): void {
    this.searchQuery = query;
  }

  /**
   * Selects a weapon in the details panel
   * @param itemName - Weapon identifier
   */
  selectItem(itemName: string): void {
    this.selectedName = itemName;
    this.activeDetailsTab = 'weapon';
    this.syncAmmoAmount();
  }

  /**
   * Sets active details tab
   * @param tab - Details tab identifier
   */
  setDetailsTab(tab: WeaponDetailsTab): void {
    this.activeDetailsTab = tab;
    this.syncAmmoAmount();
  }

  /**
   * Sets a bounded ammo amount for the selected weapon
   * @param amount - Ammo amount
   */
  setAmmoAmount(amount: number): void {
    const ammo = this.selectedItem?.upgrades.ammo;
    if (!ammo) {
      this.ammoAmount = 0;
      return;
    }

    if (this.ammoPurchaseLimit < ammo.minAmount) {
      this.ammoAmount = 0;
      return;
    }

    if (!Number.isFinite(amount)) {
      this.ammoAmount = ammo.minAmount;
      return;
    }

    this.ammoAmount = Math.max(ammo.minAmount, Math.min(this.ammoPurchaseLimit, Math.floor(amount)));
  }

  /**
   * Resets ammo selector to the selected weapon default.
   */
  syncAmmoAmount(): void {
    const ammo = this.selectedItem?.upgrades.ammo;

    if (!ammo) {
      this.ammoAmount = 0;
      return;
    }

    if (this.ammoPurchaseLimit < ammo.minAmount) {
      this.ammoAmount = 0;
      return;
    }

    this.ammoAmount = Math.max(ammo.minAmount, Math.min(this.ammoPurchaseLimit, ammo.defaultAmount));
  }

  /**
   * Resets transient UI state when the shop closes
   */
  reset(): void {
    this.searchQuery = '';
    this.activeCategory = 'all';
    this.selectedName = null;
    this.buying = false;
    this.mode = 'shop';
    this.fallbackImage = '';
    this.activeDetailsTab = 'weapon';
    this.ammoAmount = 30;
  }
}

/**
 * Global shop store instance
 */
export const shopStore = new ShopStore();

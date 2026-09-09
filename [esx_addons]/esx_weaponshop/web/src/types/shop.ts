/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

/**
 * Shop item representation
 */
export interface ShopItem {
  /** Unique weapon identifier */
  name: string;
  /** Display label */
  label: string;
  /** Price in currency */
  price: number;
  /** Category identifier */
  category: string;
  /** Image URL */
  image: string;
  /** Available upgrades for this weapon */
  upgrades: WeaponUpgrades;
  /** Current player state for this weapon */
  state: WeaponState;
}

export interface WeaponAmmoUpgrade {
  label: string;
  pricePerRound: number;
  defaultAmount: number;
  minAmount: number;
  maxAmount: number;
  quickAmounts: number[];
  maxAmmo?: number | null;
}

export interface WeaponComponentUpgrade {
  name: string;
  label: string;
  price: number;
}

export interface WeaponTintUpgrade {
  index: number;
  label: string;
  price: number;
  color: string;
}

export interface WeaponUpgrades {
  supported: boolean;
  ammo: WeaponAmmoUpgrade | null;
  components: WeaponComponentUpgrade[];
  tints: WeaponTintUpgrade[];
}

export interface WeaponState {
  owned: boolean;
  ammo: number;
  tintIndex: number;
  components: string[];
}

export type WeaponDetailsTab = 'weapon' | 'ammo' | 'components' | 'tints';

/**
 * Shop category representation
 */
export interface ShopCategory {
  /** Unique category identifier */
  id: string;
  /** Display label */
  label: string;
}

/**
 * Localized UI strings from Lua
 */
export interface ShopLocales {
  /** Search input placeholder */
  searchPlaceholder: string;
  /** Buy button label */
  buy: string;
  /** Apply button label */
  apply: string;
  /** Owned state label */
  owned: string;
  /** Equipped state label */
  equipped: string;
  /** Unavailable state label */
  unavailable: string;
  /** Empty details-panel message */
  noWeaponSelected: string;
  /** Shown when a weapon has no usable image */
  noImageAvailable: string;
  /** License view title */
  licenseTitle: string;
  /** License view description */
  licenseDescription: string;
  /** License purchase button label */
  buyLicense: string;
  /** Cancel button label */
  cancel: string;
  tabWeapon: string;
  tabAmmo: string;
  tabComponents: string;
  tabTints: string;
  ammo: string;
  ammoUnit: string;
  pricePerRound: string;
  total: string;
  buyAmmo: string;
  ammoFull: string;
  components: string;
  tints: string;
  requiresWeapon: string;
  noAmmoAvailable: string;
  noComponentsAvailable: string;
  noTintsAvailable: string;
}

/**
 * NUI shop mode
 */
export type ShopMode = 'shop' | 'license';

/**
 * Shop data structure from NUI
 */
export interface ShopData {
  /** Shop name/title */
  shopName: string;
  /** Available weapons */
  items: ShopItem[];
  /** Available categories */
  categories: ShopCategory[];
  /** Localized UI strings */
  locales: ShopLocales;
  /** Configured fallback image for missing weapon pictures */
  fallbackImage?: string;
  /** Whether this is a legal shop */
  legal: boolean;
  /** Current view mode */
  mode: ShopMode;
  /** Weapon license price */
  licensePrice: number;
  /** Weapon selected after a shop refresh */
  selectedName?: string | null;
}

/**
 * Theme convar configuration
 */
export interface ThemeConvars {
  /** Primary UI color */
  primaryColor?: string;
  /** Secondary UI color */
  secondaryColor?: string;
  /** Background color */
  backgroundColor?: string;
  /** Accent color */
  accentColor?: string;
  /** Logo URL */
  logoUrl?: string;
}

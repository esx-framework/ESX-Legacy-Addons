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
}

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
  /** Whether this is a legal shop */
  legal: boolean;
  /** Current view mode */
  mode: ShopMode;
  /** Weapon license price */
  licensePrice: number;
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

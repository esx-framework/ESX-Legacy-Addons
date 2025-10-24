/**
 * Shop item representation
 */
export interface ShopItem {
  /** Unique item identifier */
  name: string;
  /** Display label */
  label: string;
  /** Price in currency */
  price: number;
  /** Category identifier */
  category: string;
  /** Image URL (optional, falls back to placeholder) */
  image?: string;
}

/**
 * Shop category representation
 */
export interface ShopCategory {
  /** Unique category identifier */
  id: string;
  /** Display label */
  label: string;
  /** FontAwesome icon class (e.g., "fa-solid fa-burger") - Find icons at https://fontawesome.com/icons */
  icon?: string;
}

/**
 * Cart item with quantity
 */
export interface CartItem extends ShopItem {
  /** Quantity in cart */
  quantity: number;
}

/**
 * Shop data structure from NUI
 */
export interface ShopData {
  /** Shop name/title */
  shopName: string;
  /** Available items */
  items: ShopItem[];
  /** Available categories */
  categories?: ShopCategory[];
  /** Dynamic tax rate for player (0.0 - 0.19) */
  taxRate?: number;
  /** Optional tax message (e.g., "Thanks for your service!") */
  taxMessage?: string | null;
}

/**
 * Payment method types
 */
export type PaymentMethod = 'cash' | 'bank';

/**
 * Purchase request data
 */
export interface PurchaseRequest {
  /** Items to purchase */
  items: Array<{
    name: string;
    quantity: number;
    price: number;
  }>;
  /** Total amount */
  total: number;
  /** Payment method */
  paymentMethod: PaymentMethod;
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

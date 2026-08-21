import type { ShopCategory, ShopData, ShopItem, ShopLocales, ShopMode } from '@/types/shop';
import { getDocsWeaponImage } from '@utils/weaponImage';

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
  { name: 'WEAPON_PISTOL', label: 'Pistol', price: 500, category: 'handguns', image: getDocsWeaponImage('WEAPON_PISTOL') },
  { name: 'WEAPON_COMBATPISTOL', label: 'Combat Pistol', price: 800, category: 'handguns', image: getDocsWeaponImage('WEAPON_COMBATPISTOL') },
  { name: 'WEAPON_BAT', label: 'Baseball Bat', price: 50, category: 'melee', image: getDocsWeaponImage('WEAPON_BAT') },
  { name: 'WEAPON_MACHETE', label: 'Machete', price: 110, category: 'melee', image: getDocsWeaponImage('WEAPON_MACHETE') },
  { name: 'WEAPON_ASSAULTRIFLE', label: 'Assault Rifle', price: 11000, category: 'rifles', image: getDocsWeaponImage('WEAPON_ASSAULTRIFLE') },
  { name: 'WEAPON_CARBINERIFLE', label: 'Carbine Rifle', price: 13000, category: 'rifles', image: getDocsWeaponImage('WEAPON_CARBINERIFLE') },
  { name: 'WEAPON_FIREEXTINGUISHER', label: 'Fire Extinguisher', price: 100, category: 'misc', image: getDocsWeaponImage('WEAPON_FIREEXTINGUISHER') }
];

const DEFAULT_LOCALES: ShopLocales = {
  searchPlaceholder: 'Search weapons...',
  buy: 'Buy',
  noWeaponSelected: 'Select a weapon to inspect',
  noImageAvailable: 'No image available',
  licenseTitle: 'License Shop',
  licenseDescription: 'A weapon license is required to purchase from this shop.',
  buyLicense: 'Buy weapon license?',
  cancel: 'Cancel'
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

  /** Localized UI strings */
  locales: ShopLocales = $state(DEFAULT_LOCALES);

  /** Currently selected weapon name */
  selectedName: string | null = $state(null);

  /** Whether a purchase request is in flight */
  buying: boolean = $state(false);

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
    this.locales = data.locales;
    this.activeCategory = 'all';
    this.searchQuery = '';
    this.buying = false;
    this.selectedName = data.items[0]?.name ?? null;
  }

  /**
   * Loads mock data for development
   */
  loadMockData(): void {
    this.items = MOCK_ITEMS;
    this.categories = MOCK_CATEGORIES;
    this.selectedName = MOCK_ITEMS[0]?.name ?? null;
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
  }
}

/**
 * Global shop store instance
 */
export const shopStore = new ShopStore();

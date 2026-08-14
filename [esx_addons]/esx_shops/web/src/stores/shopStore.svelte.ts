import type { ShopItem, ShopCategory, CartItem, ShopData } from '@/types/shop';
import { TAX_RATE } from '@/constants/ui';

/**
 * Mock data for development - Categories
 */
const MOCK_CATEGORIES: ShopCategory[] = [
  { id: 'all', label: 'All' },
  { id: 'drinks', label: 'Drinks' },
  { id: 'food', label: 'Food' },
  { id: 'essentials', label: 'Essentials' }
];

/**
 * Mock data for development - Items
 */
const MOCK_ITEMS: ShopItem[] = [
  {
    name: 'bread',
    label: 'Bread',
    price: 50,
    category: 'food',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/bread.png'
  },
  {
    name: 'water',
    label: 'Water',
    price: 100,
    category: 'drinks',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/water.png'
  },
  {
    name: 'sprunk',
    label: 'Sprunk',
    price: 150,
    category: 'drinks',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/sprunk.png'
  },
  {
    name: 'donut',
    label: 'Donut',
    price: 80,
    category: 'food',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/donut.png'
  },
  {
    name: 'pizza',
    label: 'Pizza Slice',
    price: 120,
    category: 'food',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/pizza_ham_slice.png'
  },
  {
    name: 'lockpick',
    label: 'Lockpick',
    price: 500,
    category: 'essentials',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/lockpick.png'
  },
  {
    name: 'phone',
    label: 'Phone',
    price: 1000,
    category: 'essentials',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/phone.png'
  },
  {
    name: 'bandage',
    label: 'Bandage',
    price: 200,
    category: 'essentials',
    image: 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/bandage.png'
  }
];

/**
 * Shop Store - Centralized state management using Svelte 5 runes
 * Note: Use within .svelte components to access reactive state
 */
class ShopStore {
  /** Available items in shop */
  items: ShopItem[] = $state([]);

  /** Available categories */
  categories: ShopCategory[] = $state([]);

  /** Shopping cart items */
  cart: CartItem[] = $state([]);

  /** Currently active category filter */
  activeCategory: string = $state('all');

  /** Search query for filtering items */
  searchQuery: string = $state('');

  /** Shop display name */
  shopName: string = $state('24/7 SHOP');

  /** Dynamic tax rate (0.0 - 0.19) */
  taxRate: number = $state(TAX_RATE);

  /** Optional tax message */
  taxMessage: string | null = $state(null);

  /**
   * Filtered items based on category and search
   * Uses $derived for automatic memoization and performance
   */
  filteredItems: ShopItem[] = $derived.by(() => {
    let result = this.items;

    // Category filter
    if (this.activeCategory !== 'all') {
      result = result.filter((item: ShopItem) => item.category === this.activeCategory);
    }

    // Search filter
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
   * Total price of all items in cart
   * Uses $derived for automatic memoization
   */
  cartTotal: number = $derived(
    this.cart.reduce((total: number, item: CartItem) => total + (item.price * item.quantity), 0)
  );

  /**
   * Total number of items in cart
   * Uses $derived for automatic memoization
   */
  cartCount: number = $derived(
    this.cart.reduce((count: number, item: CartItem) => count + item.quantity, 0)
  );

  /**
   * Cart subtotal (sum of net prices before tax)
   * Uses $derived for automatic memoization
   */
  cartSubtotal: number = $derived(
    this.cart.reduce((total: number, item: CartItem) => {
      const netPrice = this.getNetPrice(item.price);
      return total + (netPrice * item.quantity);
    }, 0)
  );

  /**
   * Total tax amount for all items in cart
   * Uses $derived for automatic memoization
   */
  cartTaxTotal: number = $derived(
    this.cart.reduce((total: number, item: CartItem) => {
      const taxAmount = this.getTaxAmount(item.price);
      return total + (taxAmount * item.quantity);
    }, 0)
  );

  /**
   * Calculates net price from gross price
   * @param grossPrice - Price including tax
   * @returns Net price without tax
   */
  getNetPrice(grossPrice: number): number {
    return grossPrice / (1 + this.taxRate);
  }

  /**
   * Calculates tax amount from gross price
   * @param grossPrice - Price including tax
   * @returns Tax amount
   */
  getTaxAmount(grossPrice: number): number {
    return grossPrice - this.getNetPrice(grossPrice);
  }

  /**
   * Sets shop data from external source (NUI)
   * @param data - Shop configuration data
   */
  setShopData(data: Partial<ShopData>): void {
    this.items = data.items ?? MOCK_ITEMS;

    // Ensure "All" category is always present as first option
    const categories = data.categories ?? MOCK_CATEGORIES;
    const hasAllCategory = categories.some((cat: ShopCategory) => cat.id === 'all');

    if (!hasAllCategory) {
      this.categories = [
        { id: 'all', label: 'All' },
        ...categories
      ];
    } else {
      this.categories = categories;
    }

    this.shopName = data.shopName ?? '24/7 SHOP';
    this.taxRate = data.taxRate ?? TAX_RATE;
    this.taxMessage = data.taxMessage ?? null;
  }

  /**
   * Loads mock data for development
   */
  loadMockData(): void {
    this.items = MOCK_ITEMS;
    this.categories = MOCK_CATEGORIES;
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
   * Adds item to cart or increases quantity if already exists
   * @param item - Item to add
   */
  addToCart(item: ShopItem): void {
    const existingItem = this.cart.find((cartItem: CartItem) => cartItem.name === item.name);

    if (existingItem) {
      existingItem.quantity += 1;
    } else {
      this.cart.push({ ...item, quantity: 1 });
    }
  }

  /**
   * Removes item from cart
   * @param itemName - Item identifier
   */
  removeFromCart(itemName: string): void {
    this.cart = this.cart.filter((item: CartItem) => item.name !== itemName);
  }

  /**
   * Updates quantity for cart item
   * @param itemName - Item identifier
   * @param quantity - New quantity (min 1)
   */
  updateQuantity(itemName: string, quantity: number): void {
    const item = this.cart.find((cartItem: CartItem) => cartItem.name === itemName);
    if (item) {
      item.quantity = Math.max(1, quantity);
    }
  }

  /**
   * Clears all items from cart
   */
  clearCart(): void {
    this.cart = [];
  }

  /**
   * Gets cart data for purchase request
   * @returns Array of cart items with essential data
   */
  getCartData(): Array<{ name: string; quantity: number; price: number }> {
    return this.cart.map((item: CartItem) => ({
      name: item.name,
      quantity: item.quantity,
      price: item.price
    }));
  }
}

/**
 * Global shop store instance
 */
export const shopStore = new ShopStore();

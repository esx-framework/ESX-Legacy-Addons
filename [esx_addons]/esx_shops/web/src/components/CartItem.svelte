<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { colors } from '@/lib/theme';
  import type { CartItem as CartItemType } from '@/types/shop';

  interface Props {
    item: CartItemType;
  }

  let { item }: Props = $props();

  // Placeholder for items without images or failed loads
  const PLACEHOLDER_IMAGE = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24"%3E%3Crect width="24" height="24" fill="%23252525"/%3E%3Cpath fill="%23969696" d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/%3E%3C/svg%3E';

  let imageLoaded = $state<boolean>(false);
  let currentImageSrc = $state<string>(item.image || PLACEHOLDER_IMAGE);

  /**
   * Handles image load success
   */
  function handleImageLoad(): void {
    imageLoaded = true;
  }

  /**
   * Handles image load error - fallback to placeholder
   */
  function handleImageError(): void {
    imageLoaded = true;
    currentImageSrc = PLACEHOLDER_IMAGE;
  }

  /**
   * Increases item quantity by 1
   */
  function increaseQuantity(): void {
    shopStore.updateQuantity(item.name, item.quantity + 1);
  }

  /**
   * Decreases item quantity by 1 (minimum 1)
   */
  function decreaseQuantity(): void {
    if (item.quantity > 1) {
      shopStore.updateQuantity(item.name, item.quantity - 1);
    }
  }

  /**
   * Handles manual quantity input
   */
  function handleQuantityInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    const value = parseInt(input.value) || 1;
    shopStore.updateQuantity(item.name, value);
  }

  /**
   * Removes item from cart
   */
  function removeItem(): void {
    shopStore.removeFromCart(item.name);
  }
</script>

<div class="cart-item">
  <div class="cart-item-left">
    <div class="cart-item-img">
      <img
        src={currentImageSrc}
        alt={item.label}
        onload={handleImageLoad}
        onerror={handleImageError}
      />
    </div>
    <div class="cart-item-info">
      <div class="cart-item-label">{item.label}</div>
      <div class="cart-item-price">{item.price} $</div>
    </div>
  </div>

  <div class="cart-item-right">
    <div class="cart-item-count">
      <div class="count-options">
        <button class="decrease" onclick={decreaseQuantity} aria-label="Decrease quantity">
          −
        </button>
        <input
          type="number"
          class="count"
          value={item.quantity}
          min="1"
          oninput={handleQuantityInput}
          aria-label="Quantity"
        />
        <button class="increase" onclick={increaseQuantity} aria-label="Increase quantity">
          +
        </button>
      </div>
    </div>
    <button
      class="count-remove"
      onclick={removeItem}
      aria-label="Remove item"
      style="background-color: {colors.error.rgba(0.2)};"
      onmouseover={(e) => (e.currentTarget.style.backgroundColor = colors.error.rgba(0.3))}
      onmouseout={(e) => (e.currentTarget.style.backgroundColor = colors.error.rgba(0.2))}
      onfocus={(e) => (e.currentTarget.style.backgroundColor = colors.error.rgba(0.3))}
      onblur={(e) => (e.currentTarget.style.backgroundColor = colors.error.rgba(0.2))}
    >
      <i class="fa-solid fa-trash-can" style="color: {colors.error.rgb};"></i>
    </button>
  </div>
</div>

<style>
  .cart-item {
    background-color: var(--dark-color);
    display: flex;
    align-items: center;
    margin-bottom: 0.5rem;
    border-radius: 0.2rem;
    gap: 0.5rem;
    color: white;
    justify-content: space-between;
    padding: 0.3rem;
  }

  .cart-item-left,
  .cart-item-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .cart-item-img img {
    width: 2rem;
    height: 2rem;
    border-radius: 0.2rem;
    object-fit: contain;
  }

  .cart-item-info {
    color: white;
    font-weight: 500;
  }

  .cart-item-label {
    font-size: 0.6rem;
  }

  .cart-item-price {
    font-size: 0.7rem;
  }

  .count-options {
    display: flex;
    align-items: center;
    gap: 0.3rem;
  }

  .decrease,
  .increase {
    background-color: rgba(var(--lightest-color-rgb), 0.1);
    color: inherit;
    border: none;
    cursor: pointer;
    height: 1.2rem;
    width: 1.2rem;
    border-radius: 0.1rem;
    font-size: 0.8rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s ease;
  }

  .decrease:hover,
  .increase:hover {
    background-color: rgba(var(--lightest-color-rgb), 0.2);
  }

  .count {
    background: none;
    color: inherit;
    border: none;
    width: 2.5rem;
    font-size: 0.8rem;
    font-family: 'Poppins', sans-serif;
    text-align: center;
  }

  .count-remove {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 1.2rem;
    width: 1.2rem;
    border-radius: 0.1rem;
    border: none;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .count-remove i {
    font-size: 0.6rem;
    line-height: 0;
    transform: translateY(0.05rem);
  }
</style>

<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import type { ShopItem as ShopItemType } from '@/types/shop';

  interface Props {
    item: ShopItemType;
  }

  let { item }: Props = $props();

  // Placeholder image for items without images or failed loads
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
   * Adds item to shopping cart
   */
  function handleAddToCart(): void {
    shopStore.addToCart(item);
  }

  /**
   * Handles keyboard interaction for accessibility
   */
  function handleKeyDown(event: KeyboardEvent): void {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleAddToCart();
    }
  }
</script>

<div
  class="shop-item"
  role="button"
  tabindex="0"
  onclick={handleAddToCart}
  onkeydown={handleKeyDown}
>
  <div class="item-info">
    <div class="item-label">{item.label}</div>
    <div class="item-price">$ {item.price}</div>
  </div>

  <div class="item-image">
    {#if !imageLoaded}
      <div class="image-skeleton" aria-label="Loading image"></div>
    {/if}
    <img
      src={currentImageSrc}
      alt={item.label}
      class:loaded={imageLoaded}
      onload={handleImageLoad}
      onerror={handleImageError}
    />
  </div>

  <div class="item-cart">
    <div class="item-cart-icon">
      <i class="fa-solid fa-basket-shopping"></i>
    </div>
    <div class="item-cart-label">Add to Cart</div>
  </div>
</div>

<style>
  .shop-item {
    display: flex;
    flex-direction: column;
    background-color: rgba(var(--lightest-color-rgb), 0.05);
    border-radius: 0.3rem;
    cursor: pointer;
    transition: all 0.3s ease;
    border: 1px solid transparent;
  }

  .shop-item:hover {
    background: linear-gradient(
      180deg,
      rgba(var(--brand-color-rgb), 0.1) 0%,
      rgba(var(--brand-color-rgb), 0) 100%
    );
    box-shadow: 0 0 0.25rem 0 rgba(var(--brand-color-rgb), 0.25) inset;
    border: 1px solid rgba(var(--brand-color-rgb), 0.5);
  }

  .item-info {
    display: flex;
    justify-content: space-between;
    padding: 0.3rem;
  }

  .item-label {
    color: var(--lightest-color);
    font-weight: 500;
    font-size: 0.8rem;
  }

  .item-price {
    background: rgba(var(--lightest-color-rgb), 0.1);
    padding: 0.1rem 0.2rem;
    font-weight: 600;
    font-size: 0.6rem;
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 0.15rem;
  }

  .item-image {
    padding: 1rem 0;
    display: flex;
    justify-content: center;
    align-items: center;
    position: relative;
    min-height: 6rem;
  }

  .item-image img {
    width: 4rem;
    height: 4rem;
    object-fit: contain;
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  .item-image img.loaded {
    opacity: 1;
  }

  .image-skeleton {
    position: absolute;
    width: 4rem;
    height: 4rem;
    background: linear-gradient(
      90deg,
      rgba(var(--lightest-color-rgb), 0.05) 25%,
      rgba(var(--lightest-color-rgb), 0.1) 50%,
      rgba(var(--lightest-color-rgb), 0.05) 75%
    );
    background-size: 200% 100%;
    animation: skeleton-loading 1.5s ease-in-out infinite;
    border-radius: 0.3rem;
  }

  @keyframes skeleton-loading {
    0% {
      background-position: 200% 0;
    }
    100% {
      background-position: -200% 0;
    }
  }

  .item-cart {
    display: flex;
    background: rgba(var(--lightest-color-rgb), 0.1);
    justify-content: center;
    align-items: center;
    padding: 0.2rem;
    gap: 0.5rem;
    border-bottom-left-radius: 0.3rem;
    border-bottom-right-radius: 0.3rem;
    transition: background 0.3s ease;
  }

  .shop-item:hover .item-cart {
    background: var(--brand-color);
  }

  .item-cart-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: var(--lightest-color);
    font-size: 0.8rem;
    transition: color 0.3s ease;
  }

  .item-cart-label {
    display: inline-block;
    color: var(--lightest-color);
    font-size: 0.7rem;
    transition: color 0.3s ease;
    transform: translateY(1px);
  }

  .shop-item:hover .item-cart-icon,
  .shop-item:hover .item-cart-label {
    color: var(--darkest-color);
    font-weight: 600;
  }
</style>

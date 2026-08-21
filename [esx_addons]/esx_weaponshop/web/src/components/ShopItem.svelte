<!--
  @component ShopItem
  Displays a selectable weapon card in the item grid
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import type { ShopItem as ShopItemType } from '@/types/shop';
  import WeaponImage from './WeaponImage.svelte';

  interface Props {
    item: ShopItemType;
  }

  let { item }: Props = $props();

  let selected = $derived(shopStore.selectedName === item.name);

  /**
   * Selects this weapon in the details panel
   */
  function selectItem(): void {
    shopStore.selectItem(item.name);
  }

  /**
   * Handles keyboard interaction for accessibility
   */
  function handleKeyDown(event: KeyboardEvent): void {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      selectItem();
    }
  }
</script>

<div
  class="shop-item"
  class:selected
  role="button"
  tabindex="0"
  onclick={selectItem}
  onkeydown={handleKeyDown}
>
  <div class="item-image">
    <WeaponImage name={item.name} image={item.image} alt={item.label} />
  </div>
  <div class="item-info">
    <div class="item-label">{item.label}</div>
    <div class="item-price">${item.price.toLocaleString()}</div>
  </div>
</div>

<style>
  .shop-item {
    display: flex;
    flex-direction: column;
    background-color: rgba(var(--lightest-color-rgb), 0.05);
    border-radius: 0.3rem;
    cursor: pointer;
    transition: all 0.2s ease;
    border: 1px solid transparent;
    overflow: hidden;
  }

  .shop-item:hover,
  .shop-item.selected {
    background: linear-gradient(
      180deg,
      rgba(var(--brand-color-rgb), 0.12) 0%,
      rgba(var(--brand-color-rgb), 0) 100%
    );
    border-color: rgba(var(--brand-color-rgb), 0.55);
  }

  .item-image {
    padding: 1.1rem 0.6rem 0.6rem;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 7rem;
    height: 7rem;
  }

  .item-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.4rem;
    padding: 0.45rem 0.5rem 0.55rem;
  }

  .item-label {
    color: var(--lightest-color);
    font-weight: 500;
    font-size: 0.78rem;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .item-price {
    background: rgba(var(--lightest-color-rgb), 0.1);
    padding: 0.12rem 0.28rem;
    font-weight: 600;
    font-size: 0.65rem;
    color: white;
    border-radius: 0.15rem;
    flex-shrink: 0;
  }

  .shop-item.selected .item-price {
    background: var(--brand-color);
    color: var(--darkest-color);
  }
</style>

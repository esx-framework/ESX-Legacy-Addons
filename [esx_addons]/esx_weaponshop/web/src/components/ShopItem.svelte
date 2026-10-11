<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

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
    height: 100%;
    min-height: 0;
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
    --weapon-image-width: auto;
    --weapon-image-max-width: 64%;
    --weapon-image-max-height: 3.95rem;
    padding: 0.85rem 0.75rem 0.45rem;
    display: flex;
    justify-content: center;
    align-items: center;
    flex: 1 1 auto;
    min-height: 0;
  }

  .item-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.4rem;
    flex: 0 0 2.35rem;
    min-height: 2.35rem;
    padding: 0.4rem 0.6rem 0.5rem;
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

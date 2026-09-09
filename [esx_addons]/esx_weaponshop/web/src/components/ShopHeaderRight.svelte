<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<!--
  @component ShopHeaderRight
  Displays search bar and close button in the right header section
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { closeUI } from '@utils/nui';
  import { DEBOUNCE_DELAY_MS } from '@/constants/ui';

  let searchValue = $state<string>('');
  let debounceTimeout: ReturnType<typeof setTimeout> | null = null;

  /**
   * Handles search input with debouncing
   * Delays the actual search query update to avoid excessive filtering
   */
  function handleSearchInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    searchValue = input.value;

    if (debounceTimeout) {
      clearTimeout(debounceTimeout);
    }

    debounceTimeout = setTimeout(() => {
      shopStore.setSearchQuery(searchValue);
    }, DEBOUNCE_DELAY_MS);
  }

  /**
   * Closes the shop UI
   */
  function handleClose(): void {
    closeUI();
  }
</script>

<div class="shop-header-right">
  <div class="shop-search-icon">
    <span class="search-icon" aria-hidden="true"></span>
    <input
      type="text"
      placeholder={shopStore.locales.searchPlaceholder}
      value={searchValue}
      oninput={handleSearchInput}
    />
  </div>
  <button class="shop-close" onclick={handleClose} aria-label="Close shop">
    <span class="close-icon" aria-hidden="true"></span>
  </button>
</div>

<style>
  .shop-header-right {
    position: relative;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    height: var(--shop-toolbar-height, 2.35rem);
    width: 100%;
    margin-bottom: var(--shop-toolbar-content-gap, 1rem);
    padding-right: 0;
  }

  .shop-search-icon {
    position: relative;
    flex: 1;
    height: var(--shop-toolbar-height, 2.35rem);
  }

  .shop-search-icon input {
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    background: rgba(var(--lightest-color-rgb), 0.12);
    color: var(--lightest-color);
    font-family: var(--font-family);
    font-weight: 400;
    font-size: 0.9rem;
    border-radius: 0.25rem;
    padding: 0 0.5rem 0 2rem;
    height: var(--shop-toolbar-height, 2.35rem);
    line-height: var(--shop-toolbar-height, 2.35rem);
    width: 100%;
  }

  .shop-search-icon input:focus {
    border-color: rgba(var(--brand-color-rgb), 0.35);
    background: rgba(var(--lightest-color-rgb), 0.14);
  }

  .search-icon {
    position: absolute;
    left: 0.5rem;
    top: 50%;
    transform: translateY(-50%);
    pointer-events: none;
    width: 0.72rem;
    height: 0.72rem;
    border: 0.12rem solid #aaa;
    border-radius: 50%;
  }

  .search-icon::after {
    content: '';
    position: absolute;
    width: 0.36rem;
    height: 0.12rem;
    right: -0.28rem;
    bottom: -0.16rem;
    background: #aaa;
    transform: rotate(45deg);
    transform-origin: center;
  }

  .shop-close {
    background-color: rgba(var(--lightest-color-rgb), 0.12);
    color: var(--lightest-color);
    height: var(--shop-toolbar-height, 2.35rem);
    width: var(--shop-toolbar-height, 2.35rem);
    min-width: var(--shop-toolbar-height, 2.35rem);
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 0.25rem;
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    cursor: pointer;
    transition: all 0.2s ease;
    position: absolute;
    top: calc(var(--shop-header-top-offset, 0.75rem) - var(--shop-header-height, 4.6vh) - var(--shop-toolbar-top-gap, 0.5rem));
    right: 0;
    z-index: 2;
  }

  .shop-close:hover {
    background: rgba(var(--brand-color-rgb), 0.2);
    color: var(--brand-color);
    border-color: rgba(var(--brand-color-rgb), 0.35);
  }

  .close-icon {
    width: 0.95rem;
    height: 0.95rem;
    position: relative;
    display: block;
  }

  .close-icon::before,
  .close-icon::after {
    content: '';
    position: absolute;
    left: 50%;
    top: 50%;
    width: 1rem;
    height: 0.13rem;
    background: currentColor;
    transform-origin: center;
  }

  .close-icon::before {
    transform: translate(-50%, -50%) rotate(45deg);
  }

  .close-icon::after {
    transform: translate(-50%, -50%) rotate(-45deg);
  }
</style>

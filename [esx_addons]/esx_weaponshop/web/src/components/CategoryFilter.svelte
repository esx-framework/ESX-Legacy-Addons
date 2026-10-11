<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';

  /**
   * Sets active category filter
   */
  function selectCategory(categoryId: string): void {
    shopStore.setActiveCategory(categoryId);
  }
</script>

<div class="category-filter">
  <div class="categories-scroller">
    {#each shopStore.categories as category (category.id)}
      <button
        class="category-wrap"
        class:active={shopStore.activeCategory === category.id}
        onclick={() => selectCategory(category.id)}
      >
        {category.label}
      </button>
    {/each}
  </div>
</div>

<style>
  .category-filter {
    overflow-x: auto;
    scrollbar-width: none;
    max-width: 100%;
    height: 100%;
  }

  .category-filter::-webkit-scrollbar {
    display: none;
  }

  .categories-scroller {
    display: flex;
    gap: 0.5rem;
    align-items: stretch;
    height: 100%;
    min-width: fit-content;
  }

  .category-wrap {
    background: rgba(var(--lightest-color-rgb), 0.1);
    color: rgba(var(--lightest-color-rgb), 0.5);
    font-family: var(--font-family);
    font-weight: 500;
    font-size: 0.8rem;
    height: 100%;
    min-height: var(--shop-toolbar-height, 2.35rem);
    padding: 0 0.75rem;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 0.3rem;
    white-space: nowrap;
    text-transform: uppercase;
    flex-shrink: 0;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .category-wrap:hover {
    background: rgba(var(--brand-color-rgb), 0.2);
    color: var(--brand-color);
  }

  .category-wrap.active {
    background: var(--brand-color);
    color: var(--darkest-color);
  }
</style>

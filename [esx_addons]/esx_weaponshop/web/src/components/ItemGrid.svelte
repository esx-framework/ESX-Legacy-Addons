<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<!--
  @component ItemGrid
  Displays shop items in a responsive grid layout.
  Automatically renders filtered items from the shop store.
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { GRID_COLUMNS } from '@/constants/ui';
  import ShopItem from './ShopItem.svelte';
</script>

<div class="item-grid" style="--grid-columns: {GRID_COLUMNS};">
  {#each shopStore.filteredItems as item (item.name)}
    <ShopItem {item} />
  {/each}
</div>

<style>
  .item-grid {
    --row-gap: 0.55rem;
    --bottom-safe-space: 0.35rem;
    display: grid;
    grid-template-columns: repeat(var(--grid-columns), minmax(0, 1fr));
    grid-template-rows: repeat(4, minmax(0, 1fr));
    grid-auto-rows: 9.55rem;
    gap: var(--row-gap);
    height: 100%;
    max-height: 100%;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0 0 var(--bottom-safe-space);
    scrollbar-width: none;
  }

  .item-grid::-webkit-scrollbar {
    display: none;
  }
</style>

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
    display: grid;
    grid-template-columns: repeat(var(--grid-columns), 1fr);
    gap: 0.5rem;
    max-height: 64vh;
    overflow-y: auto;
    overflow-x: hidden;
    padding-right: 0.5rem;
  }
</style>

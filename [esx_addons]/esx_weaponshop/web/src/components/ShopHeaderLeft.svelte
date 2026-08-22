<!--
  @component ShopHeaderLeft
  Displays shop name and icon in the left header section
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
</script>

<div class="shop-header-left">
  <div class="shop-icon">
    <i class="fa-solid fa-crosshairs"></i>
  </div>
  <div class="shop-title">{shopStore.shopName}</div>
  {#if !shopStore.legal}
    <div class="illegal-badge">BLACK MARKET</div>
  {/if}
</div>

<style>
  .shop-header-left {
    display: flex;
    align-items: center;
    font-family: 'Poppins', sans-serif;
    gap: 0.5rem;
    height: 5vh;
    margin-left: 1rem;
  }

  .shop-title {
    color: var(--lightest-color);
    font-weight: 600;
    font-size: 1rem;
  }

  .shop-icon {
    color: var(--brand-color);
    font-size: 1rem;
  }

  .illegal-badge {
    margin-left: 0.25rem;
    font-size: 0.62rem;
    font-weight: 700;
    letter-spacing: 0.04em;
    color: var(--darkest-color);
    background: #f45b69;
    border-radius: 0.15rem;
    padding: 0.12rem 0.35rem;
  }
</style>

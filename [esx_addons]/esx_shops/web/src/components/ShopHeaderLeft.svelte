<!--
  @component ShopHeaderLeft
  Displays shop name and icon in the left header section
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
</script>

<div class="shop-header-left">
  <div class="shop-icon">
    <i class="fa-solid fa-shop"></i>
  </div>
  <div class="shop-title">{shopStore.shopName}</div>
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
    font-family: 'Poppins', sans-serif;
    font-weight: 600;
    font-size: 1rem;
  }

  .shop-icon {
    color: var(--lightest-color);
    font-size: 1rem;
  }
</style>

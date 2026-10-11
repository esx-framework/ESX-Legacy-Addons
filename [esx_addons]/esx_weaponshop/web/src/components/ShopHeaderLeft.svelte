<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<!--
  @component ShopHeaderLeft
  Displays shop name and icon in the left header section
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
</script>

<div class="shop-header-left">
  <div class="shop-icon" aria-hidden="true">
    <span class="crosshair-icon"></span>
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
    font-family: var(--font-family);
    gap: 0.65rem;
    height: var(--shop-header-height, 4.6vh);
    margin-left: 1rem;
  }

  .shop-title {
    color: var(--lightest-color);
    font-weight: 800;
    font-size: 1.08rem;
    line-height: 1;
    text-transform: uppercase;
    text-shadow: 0 0.08rem 0 rgba(0, 0, 0, 0.45);
  }

  .shop-icon {
    color: var(--brand-color);
    width: 1.35rem;
    height: 1.35rem;
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: 0 0 1.35rem;
  }

  .crosshair-icon {
    width: 1.1rem;
    height: 1.1rem;
    border: 0.13rem solid currentColor;
    border-radius: 50%;
    position: relative;
    display: block;
  }

  .crosshair-icon::before,
  .crosshair-icon::after {
    content: '';
    position: absolute;
    background: currentColor;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
  }

  .crosshair-icon::before {
    width: 0.14rem;
    height: 1.42rem;
  }

  .crosshair-icon::after {
    width: 1.42rem;
    height: 0.14rem;
  }

  .illegal-badge {
    margin-left: 0.25rem;
    font-size: 0.62rem;
    font-weight: 700;
    color: var(--darkest-color);
    background: #f45b69;
    border-radius: 0.15rem;
    padding: 0.12rem 0.35rem;
  }
</style>

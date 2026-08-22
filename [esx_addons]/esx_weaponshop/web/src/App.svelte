<script lang="ts">
  import { onMount } from 'svelte';
  import ScaleProvider from '@lib/ScaleProvider.svelte';
  import ShopHeaderLeft from '@components/ShopHeaderLeft.svelte';
  import ShopHeaderRight from '@components/ShopHeaderRight.svelte';
  import CategoryFilter from '@components/CategoryFilter.svelte';
  import ItemGrid from '@components/ItemGrid.svelte';
  import WeaponDetails from '@components/WeaponDetails.svelte';
  import LicenseView from '@components/LicenseView.svelte';
  import { shopStore } from '@stores/shopStore.svelte';
  import { onNuiMessage, registerEscapeListener, closeUI, isEnvBrowser } from '@utils/nui';
  import type { ShopData } from '@/types/shop';

  let isVisible = $state<boolean>(false);

  /**
   * Validates if data is a valid ShopData object
   * @param data - Data to validate
   * @returns True if data is valid ShopData
   */
  function isValidShopData(data: unknown): data is ShopData {
    if (!data || typeof data !== 'object') {
      return false;
    }

    const d = data as Record<string, unknown>;
    return (
      typeof d['shopName'] === 'string' &&
      Array.isArray(d['items']) &&
      Array.isArray(d['categories']) &&
      (d['mode'] === 'shop' || d['mode'] === 'license')
    );
  }

  onMount(() => {
    if (isEnvBrowser()) {
      shopStore.loadMockData();
      isVisible = true;
    }

    /**
     * Handles NUI messages from Lua
     */
    const cleanupNuiListener = onNuiMessage((data: Record<string, unknown>) => {
      switch (data['type']) {
        case 'openShop':
          if (data['shopData'] && isValidShopData(data['shopData'])) {
            shopStore.setShopData(data['shopData']);
            isVisible = true;
          } else {
            console.error('[esx_weaponshop] Invalid shop data received from NUI:', data['shopData']);
          }
          break;

        case 'closeShop':
          isVisible = false;
          shopStore.reset();
          break;
      }
    });

    /**
     * Handles ESC key to close UI
     */
    const cleanupEscListener = registerEscapeListener(() => {
      if (isVisible) {
        isVisible = false;
        closeUI();
      }
    });

    return () => {
      cleanupNuiListener();
      cleanupEscListener();
    };
  });
</script>

<ScaleProvider>
  {#if isVisible}
    <div class="shop-container" class:illegal={!shopStore.legal}>
      {#if shopStore.mode === 'license'}
        <LicenseView />
      {:else}
        <div class="shop-content">
          <div class="left-panel">
            <ShopHeaderLeft />
            <div class="category-section">
              <CategoryFilter />
            </div>
            <div class="items-section">
              <ItemGrid />
            </div>
          </div>
          <div class="right-panel">
            <ShopHeaderRight />
            <WeaponDetails />
          </div>
        </div>
      {/if}
    </div>
  {/if}
</ScaleProvider>

<style>
  .shop-container {
    background: var(--darkest-color);
    width: 80vw;
    height: 80vh;
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    flex-direction: column;
  }

  .shop-content {
    display: flex;
    width: 100%;
    height: 100%;
    overflow: hidden;
    gap: 1rem;
  }

  .left-panel {
    width: 70%;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .right-panel {
    width: 28%;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .category-section {
    margin: 0.5rem 0 1rem 1rem;
  }

  .items-section {
    margin-left: 1rem;
    flex: 1;
    overflow: hidden;
  }
</style>

<script lang="ts">
  import { onMount } from 'svelte';
  import ScaleProvider from '@lib/ScaleProvider.svelte';
  import ShopHeaderLeft from '@components/ShopHeaderLeft.svelte';
  import ShopHeaderRight from '@components/ShopHeaderRight.svelte';
  import CategoryFilter from '@components/CategoryFilter.svelte';
  import ItemGrid from '@components/ItemGrid.svelte';
  import ShoppingCart from '@components/ShoppingCart.svelte';
  import CheckoutModal from '@components/CheckoutModal.svelte';
  import { shopStore } from '@stores/shopStore.svelte';
  import { onNuiMessage, registerEscapeListener, closeUI } from '@utils/nui';
  import type { ShopData } from '@/types/shop';

  let isVisible = $state<boolean>(false);
  let isCheckoutModalOpen = $state<boolean>(false);

  /**
   * Validates if data is a valid ShopData object
   * @param data - Data to validate
   * @returns True if data is valid ShopData
   */
  function isValidShopData(data: unknown): data is ShopData {
    if (!data || typeof data !== 'object') return false;
    const d = data as Record<string, unknown>;
    return (
      typeof d['shopName'] === 'string' &&
      Array.isArray(d['items']) &&
      (d['categories'] === undefined || Array.isArray(d['categories']))
    );
  }

  /**
   * Opens the checkout modal
   */
  function openCheckoutModal(): void {
    isCheckoutModalOpen = true;
  }

  /**
   * Closes the checkout modal
   */
  function closeCheckoutModal(): void {
    isCheckoutModalOpen = false;
  }

  onMount(() => {
    // Load mock data for development
    shopStore.loadMockData();

    /**
     * Handles NUI messages from Lua
     */
    const cleanupNuiListener = onNuiMessage((data: Record<string, unknown>) => {
      switch (data['type']) {
        case 'openShop':
          if (data['shopData'] && isValidShopData(data['shopData'])) {
            shopStore.setShopData(data['shopData']);
          } else {
            console.error('[esx_shops] Invalid shop data received from NUI:', data['shopData']);
          }
          // Theme is loaded via ready callback in main.ts
          isVisible = true;
          break;

        case 'closeShop':
          isVisible = false;
          shopStore.clearCart();
          break;
      }
    });

    /**
     * Handles ESC key to close UI
     * Priority: Close modal first if open, otherwise close entire shop
     */
    const cleanupEscListener = registerEscapeListener(() => {
      if (isVisible) {
        // Close checkout modal if open, otherwise close shop
        if (isCheckoutModalOpen) {
          closeCheckoutModal();
        } else {
          isVisible = false;
          closeUI();
        }
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
    <div class="shop-container">
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
          <ShoppingCart onCheckout={openCheckoutModal} />
        </div>
      </div>
    </div>

    {#if isCheckoutModalOpen}
      <CheckoutModal onClose={closeCheckoutModal} />
    {/if}
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

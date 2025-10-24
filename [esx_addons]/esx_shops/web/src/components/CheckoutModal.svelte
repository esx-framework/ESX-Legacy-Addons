<!--
  @component CheckoutModal
  Modal displaying cart items with tax breakdown and payment options
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { fetchNui } from '@utils/nui';
  import CheckoutModalItem from './CheckoutModalItem.svelte';
  import type { PaymentMethod } from '@/types/shop';

  interface Props {
    onClose: () => void;
  }

  let { onClose }: Props = $props();

  let isProcessing = $state<boolean>(false);
  let shakeError = $state<boolean>(false);

  /**
   * Processes purchase with specified payment method
   */
  async function handlePurchase(paymentMethod: PaymentMethod): Promise<void> {
    if (isProcessing) return;

    isProcessing = true;

    try {
      const purchaseData = {
        items: shopStore.getCartData(),
        total: shopStore.cartTotal,
        paymentMethod
      };

      const response = await fetchNui('purchaseItems', purchaseData, {
        timeout: 10000
      });

      if (!response.ok) {
        // Trigger shake animation on error
        shakeError = true;
        setTimeout(() => (shakeError = false), 500);
        console.error('Purchase failed:', response.error?.message);
        return;
      }

      // Success - just close, backend sends ESX notification
      shopStore.clearCart();
      onClose();

    } catch (error) {
      console.error('Purchase error:', error);
      shakeError = true;
      setTimeout(() => (shakeError = false), 500);
    } finally {
      isProcessing = false;
    }
  }

  /**
   * Handles Enter/Space key on overlay to close modal
   */
  function handleOverlayKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      onClose();
    }
  }

  // Note: ESC key handling is done in App.svelte to prevent double-handling
</script>

<div
  class="modal-overlay"
  onclick={onClose}
  onkeydown={handleOverlayKeydown}
  role="button"
  tabindex="0"
  aria-label="Close modal"
>
  <div
    class="modal-content"
    onclick={(e) => e.stopPropagation()}
    onkeydown={(e) => e.stopPropagation()}
    role="dialog"
    aria-modal="true"
    aria-labelledby="modal-title"
    tabindex="-1"
  >
    <div class="modal-header">
      <h2 id="modal-title">CHECKOUT</h2>
      <button class="modal-close" onclick={onClose} aria-label="Close modal">
        <i class="fa-solid fa-xmark"></i>
      </button>
    </div>

    <div class="modal-body">
      <div class="modal-items">
        {#each shopStore.cart as item (item.name)}
          <CheckoutModalItem {item} />
        {/each}
      </div>

      <div class="modal-summary">
        <div class="summary-row">
          <span class="summary-label">Subtotal (Net):</span>
          <span class="summary-value">{shopStore.cartSubtotal.toFixed(2)}$</span>
        </div>
        <div class="summary-row">
          <span class="summary-label">Tax ({(shopStore.taxRate * 100).toFixed(0)}%):</span>
          <span class="summary-value">{shopStore.cartTaxTotal.toFixed(2)}$</span>
        </div>

        <div class="divider-container">
          {#if shopStore.taxMessage}
            <div class="divider-line left"></div>
            <span class="tax-message">⭐ {shopStore.taxMessage}</span>
            <div class="divider-line right"></div>
          {:else}
            <div class="divider-line full"></div>
          {/if}
        </div>

        <div class="summary-row total">
          <span class="summary-label">Total (Gross):</span>
          <span class="summary-value">{shopStore.cartTotal.toFixed(2)}$</span>
        </div>
      </div>
    </div>

    <div class="modal-footer">
      <button
        class="payment-button cash"
        class:shake={shakeError}
        onclick={() => handlePurchase('cash')}
        disabled={isProcessing}
      >
        {#if isProcessing}
          <i class="fa-solid fa-spinner fa-spin"></i>
        {:else}
          <i class="fa-solid fa-dollar-sign"></i>
        {/if}
        <span>PAY CASH</span>
      </button>
      <button
        class="payment-button bank"
        class:shake={shakeError}
        onclick={() => handlePurchase('bank')}
        disabled={isProcessing}
      >
        {#if isProcessing}
          <i class="fa-solid fa-spinner fa-spin"></i>
        {:else}
          <i class="fa-solid fa-building-columns"></i>
        {/if}
        <span>PAY BANK</span>
      </button>
    </div>
  </div>
</div>

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal-content {
    background: var(--darkest-color);
    border: 1px solid rgba(var(--lightest-color-rgb), 0.1);
    border-radius: 0.5rem;
    width: 90%;
    max-width: 500px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid rgba(var(--lightest-color-rgb), 0.1);
  }

  .modal-header h2 {
    font-family: 'Poppins', sans-serif;
    font-size: 1.2rem;
    font-weight: 600;
    color: var(--lightest-color);
    margin: 0;
  }

  .modal-close {
    background: rgba(var(--lightest-color-rgb), 0.1);
    border: none;
    color: var(--lightest-color);
    width: 2rem;
    height: 2rem;
    border-radius: 0.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .modal-close:hover {
    background: rgba(var(--brand-color-rgb), 0.2);
    color: var(--brand-color);
  }

  .modal-close i {
    font-size: 1rem;
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .modal-items {
    display: flex;
    flex-direction: column;
  }

  .modal-summary {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem;
    background: rgba(var(--lightest-color-rgb), 0.03);
    border-radius: 0.3rem;
    border: 1px solid rgba(var(--lightest-color-rgb), 0.1);
  }

  .summary-row {
    display: flex;
    align-items: center;
    font-family: 'Poppins', sans-serif;
    font-size: 0.9rem;
  }

  .divider-container {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin: 0.5rem 0;
  }

  .divider-line {
    height: 1px;
    background: rgba(var(--lightest-color-rgb), 0.2);
  }

  .divider-line.full {
    flex: 1;
  }

  .divider-line.left,
  .divider-line.right {
    flex: 1;
  }

  .divider-container .tax-message {
    font-size: 0.75rem;
    color: var(--brand-color);
    font-weight: 600;
    white-space: nowrap;
  }

  .summary-row.total {
    padding-top: 0.5rem;
    font-size: 1rem;
    font-weight: 600;
  }

  .summary-label {
    flex: 0 0 150px;
    color: rgba(var(--lightest-color-rgb), 0.7);
  }

  .summary-value {
    flex: 1;
    text-align: right;
    color: var(--lightest-color);
    font-weight: 500;
  }

  .summary-row.total .summary-value {
    color: var(--brand-color);
  }

  .modal-footer {
    display: flex;
    gap: 0.5rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid rgba(var(--lightest-color-rgb), 0.1);
  }

  .payment-button {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.8rem;
    border-radius: 0.3rem;
    border: none;
    font-family: 'Poppins', sans-serif;
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .payment-button.cash {
    background: var(--brand-color);
    color: var(--darkest-color);
  }

  .payment-button.bank {
    background: rgba(var(--lightest-color-rgb), 0.1);
    color: var(--lightest-color);
  }

  .payment-button:not(:disabled):hover {
    opacity: 0.9;
    transform: translateY(-1px);
  }

  .payment-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .payment-button i {
    font-size: 1rem;
  }

  .payment-button.shake {
    animation: shake 0.5s ease;
  }

  @keyframes shake {
    0%, 100% {
      transform: translateX(0);
    }
    10%, 30%, 50%, 70%, 90% {
      transform: translateX(-5px);
    }
    20%, 40%, 60%, 80% {
      transform: translateX(5px);
    }
  }
</style>

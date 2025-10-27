<!--
  @component CheckoutModalItem
  Read-only cart item display in checkout modal showing tax breakdown
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import type { CartItem } from '@/types/shop';

  interface Props {
    item: CartItem;
  }

  let { item }: Props = $props();

  // Placeholder for items without images or failed loads
  const PLACEHOLDER_IMAGE = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24"%3E%3Crect width="24" height="24" fill="%23252525"/%3E%3Cpath fill="%23969696" d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/%3E%3C/svg%3E';

  let imageLoaded = $state<boolean>(false);
  let currentImageSrc = $state<string>(item.image || PLACEHOLDER_IMAGE);

  /**
   * Handles image load success
   */
  function handleImageLoad(): void {
    imageLoaded = true;
  }

  /**
   * Handles image load error - fallback to placeholder
   */
  function handleImageError(): void {
    imageLoaded = true;
    currentImageSrc = PLACEHOLDER_IMAGE;
  }

  const netPrice = $derived(shopStore.getNetPrice(item.price));
  const taxAmount = $derived(shopStore.getTaxAmount(item.price));
  const totalGross = $derived(item.price * item.quantity);
</script>

<div class="modal-item">
  <div class="modal-item-left">
    <div class="modal-item-img">
      <img
        src={currentImageSrc}
        alt={item.label}
        onload={handleImageLoad}
        onerror={handleImageError}
      />
    </div>
    <div class="modal-item-info">
      <div class="modal-item-label">{item.label}</div>
      <div class="modal-item-quantity">Quantity: {item.quantity}</div>
    </div>
  </div>

  <div class="modal-item-right">
    <div class="modal-item-breakdown">
      <div class="breakdown-row">
        <span class="breakdown-label">Net:</span>
        <span class="breakdown-value">{netPrice.toFixed(2)}$</span>
      </div>
      <div class="breakdown-row">
        <span class="breakdown-label">Tax:</span>
        <span class="breakdown-value">{taxAmount.toFixed(2)}$</span>
      </div>
      <div class="breakdown-row total">
        <span class="breakdown-label">Total:</span>
        <span class="breakdown-value">{totalGross.toFixed(2)}$</span>
      </div>
    </div>
  </div>
</div>

<style>
  .modal-item {
    background-color: rgba(var(--lightest-color-rgb), 0.05);
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.5rem;
    border-radius: 0.3rem;
    padding: 0.5rem;
    gap: 1rem;
  }

  .modal-item-left {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex: 1;
  }

  .modal-item-img img {
    width: 2.5rem;
    height: 2.5rem;
    border-radius: 0.2rem;
    object-fit: contain;
  }

  .modal-item-info {
    color: var(--lightest-color);
    font-family: 'Poppins', sans-serif;
  }

  .modal-item-label {
    font-size: 0.8rem;
    font-weight: 600;
    margin-bottom: 0.2rem;
  }

  .modal-item-quantity {
    font-size: 0.7rem;
    opacity: 0.7;
  }

  .modal-item-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }

  .modal-item-breakdown {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .breakdown-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    font-family: 'Poppins', sans-serif;
    font-size: 0.7rem;
  }

  .breakdown-row.total {
    margin-top: 0.2rem;
    padding-top: 0.2rem;
    border-top: 1px solid rgba(var(--lightest-color-rgb), 0.2);
    font-weight: 600;
  }

  .breakdown-label {
    color: rgba(var(--lightest-color-rgb), 0.7);
  }

  .breakdown-value {
    color: var(--lightest-color);
    font-weight: 500;
  }

  .breakdown-row.total .breakdown-value {
    color: var(--brand-color);
  }
</style>

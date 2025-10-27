<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';

  interface Props {
    onCheckout: () => void;
  }

  let { onCheckout }: Props = $props();
</script>

<div class="checkout-panel">
  <div class="checkout-price">
    <span>TOTAL PRICE:</span>
    <span>{shopStore.cartTotal}$</span>
  </div>

  <button
    class="checkout-button"
    onclick={onCheckout}
    disabled={shopStore.cart.length === 0}
  >
    <i class="fa-solid fa-shopping-cart"></i>
    <span>CHECKOUT</span>
  </button>
</div>

<style>
  .checkout-panel {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem 0;
  }

  .checkout-price {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.4rem 0;
  }

  .checkout-price span {
    font-family: 'Poppins', sans-serif;
    color: var(--lightest-color);
    font-weight: 600;
    font-size: 0.9rem;
  }

  .checkout-button {
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: var(--brand-color);
    width: 100%;
    color: var(--darkest-color);
    padding: 0.6rem;
    border-radius: 0.3rem;
    font-family: 'Poppins', sans-serif;
    gap: 0.5rem;
    font-weight: 600;
    font-size: 0.9rem;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .checkout-button:not(:disabled):hover {
    opacity: 0.9;
    transform: translateY(-1px);
  }

  .checkout-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: rgba(var(--lightest-color-rgb), 0.1);
    color: rgba(var(--lightest-color-rgb), 0.349);
  }

  .checkout-button i {
    font-size: 0.9rem;
  }
</style>

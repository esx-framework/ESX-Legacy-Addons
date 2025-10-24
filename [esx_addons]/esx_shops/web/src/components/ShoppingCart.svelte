<!--
  @component ShoppingCart
  Main shopping cart container displaying all cart items and checkout functionality.
  Shows an empty state when no items are present, otherwise displays the list of cart items
  and the checkout panel with total price and purchase button.
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import CartItem from './CartItem.svelte';
  import EmptyCart from './EmptyCart.svelte';
  import CheckoutPanel from './CheckoutPanel.svelte';

  interface Props {
    onCheckout: () => void;
  }

  let { onCheckout }: Props = $props();
</script>

<div class="shopping-cart">
  <div class="cart-title">
    <i class="fa-solid fa-basket-shopping"></i>
    <span>SHOPPING CART</span>
  </div>

  <div class="cart-items">
    {#if shopStore.cart.length === 0}
      <EmptyCart />
    {:else}
      {#each shopStore.cart as item (item.name)}
        <CartItem {item} />
      {/each}
    {/if}
  </div>

  <CheckoutPanel {onCheckout} />
</div>

<style>
  .shopping-cart {
    width: 100%;
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .cart-title {
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .cart-title span {
    color: white;
    font-family: 'Poppins', sans-serif;
    font-weight: 600;
    font-size: 0.9rem;
  }

  .cart-title i {
    color: var(--lightest-color);
    font-size: 0.8rem;
  }

  .cart-items {
    flex: 1;
    margin-top: 1.5rem;
    width: 100%;
    overflow-y: auto;
    padding-right: 0.5rem;
    display: flex;
    flex-direction: column;
    position: relative;
  }
</style>

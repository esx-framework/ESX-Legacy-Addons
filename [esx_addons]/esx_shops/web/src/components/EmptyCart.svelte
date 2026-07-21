<!--
  @component EmptyCart
  Displays an empty state message when the shopping cart contains no items.
  Shows a basket icon with descriptive text prompting the user to add items.
-->
<div class="empty-cart">
  <i class="fa-solid fa-basket-shopping" aria-hidden="true"></i>
  <span class="empty-cart-title">Your basket is empty</span>
  <span class="empty-cart-subtitle">Add something to checkout</span>
</div>

<style>
  .empty-cart {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    pointer-events: none;
  }

  .empty-cart i {
    font-size: 5rem;
    color: rgba(var(--lightest-color-rgb), 0.281);
  }

  .empty-cart span {
    text-align: center;
    color: rgba(var(--lightest-color-rgb), 0.281);
    font-family: 'Poppins', sans-serif;
  }

  .empty-cart-title {
    margin-top: 0.4rem;
    text-transform: uppercase;
    font-size: 1rem;
    font-weight: 600;
  }

  .empty-cart-subtitle {
    font-size: 0.7rem;
    margin-top: 0.2rem;
    font-weight: 300;
  }
</style>

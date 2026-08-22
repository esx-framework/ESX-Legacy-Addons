<!--
  @component LicenseView
  Displays the weapon license purchase prompt
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { closeUI, fetchNui } from '@utils/nui';
  import { NUI_EVENTS } from '@/types/nui';

  /**
   * Purchases a weapon license and returns to the shop on success
   */
  async function buyLicense(): Promise<void> {
    if (shopStore.buying) {
      return;
    }

    shopStore.buying = true;
    await fetchNui(NUI_EVENTS.BUY_LICENSE);
    shopStore.buying = false;
  }

  /**
   * Closes the license view without purchasing
   */
  function cancel(): void {
    closeUI();
  }
</script>

<div class="license">
  <div class="card">
    <div class="icon">
      <i class="fa-regular fa-id-card"></i>
    </div>
    <div class="title">{shopStore.locales.licenseTitle}</div>
    <div class="description">{shopStore.locales.licenseDescription}</div>
    <div class="price">${shopStore.licensePrice.toLocaleString()}</div>
    <button class="buy" disabled={shopStore.buying} onclick={buyLicense}>
      {shopStore.locales.buyLicense}
    </button>
    <button class="cancel" onclick={cancel}>
      {shopStore.locales.cancel}
    </button>
  </div>
</div>

<style>
  .license {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .card {
    width: 28rem;
    background: var(--dark-color);
    border-radius: 0.4rem;
    padding: 2rem 1.75rem;
    text-align: center;
  }

  .icon {
    color: var(--brand-color);
    font-size: 2rem;
    margin-bottom: 0.85rem;
  }

  .title {
    font-size: 1.25rem;
    font-weight: 700;
  }

  .description {
    margin-top: 0.55rem;
    color: var(--light-color);
    font-size: 0.88rem;
    line-height: 1.45;
  }

  .price {
    margin-top: 1.1rem;
    color: var(--brand-color);
    font-size: 1.5rem;
    font-weight: 700;
  }

  .buy,
  .cancel {
    width: 100%;
    margin-top: 0.7rem;
    border: none;
    border-radius: 0.3rem;
    font-family: 'Poppins', sans-serif;
    font-weight: 600;
    font-size: 0.9rem;
    padding: 0.7rem 0.5rem;
    cursor: pointer;
  }

  .buy {
    margin-top: 1.25rem;
    background: var(--brand-color);
    color: var(--darkest-color);
  }

  .buy:disabled {
    opacity: 0.55;
    cursor: default;
  }

  .cancel {
    background: rgba(var(--lightest-color-rgb), 0.1);
    color: var(--lightest-color);
  }
</style>

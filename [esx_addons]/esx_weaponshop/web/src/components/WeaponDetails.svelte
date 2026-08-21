<!--
  @component WeaponDetails
  Displays the selected weapon preview and purchase action
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { fetchNui } from '@utils/nui';
  import { NUI_EVENTS } from '@/types/nui';
  import WeaponImage from './WeaponImage.svelte';

  let item = $derived(shopStore.selectedItem);
  let categoryLabel = $derived(
    item
      ? (shopStore.categories.find((category) => category.id === item.category)?.label ?? item.category)
      : ''
  );

  /**
   * Purchases the currently selected weapon
   */
  async function buyWeapon(): Promise<void> {
    if (!item || shopStore.buying) {
      return;
    }

    shopStore.buying = true;
    await fetchNui(NUI_EVENTS.BUY_WEAPON, {
      weaponName: item.name
    });
    shopStore.buying = false;
  }
</script>

<div class="details">
  {#if item}
    <div class="preview">
      <WeaponImage name={item.name} image={item.image} alt={item.label} />
    </div>
    <div class="meta">
      <div class="name">{item.label}</div>
      <div class="category">{categoryLabel}</div>
    </div>
    <div class="price">${item.price.toLocaleString()}</div>
    <button class="buy" disabled={shopStore.buying} onclick={buyWeapon}>
      {shopStore.locales.buy}
    </button>
  {:else}
    <div class="empty">{shopStore.locales.noWeaponSelected}</div>
  {/if}
</div>

<style>
  .details {
    width: 100%;
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    padding: 0.75rem 0.75rem 1rem 0;
  }

  .preview {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(var(--lightest-color-rgb), 0.04);
    border-radius: 0.3rem;
    min-height: 12rem;
    padding: 1.5rem;
  }

  .meta {
    margin-top: 1rem;
  }

  .name {
    font-size: 1.05rem;
    font-weight: 600;
  }

  .category {
    margin-top: 0.15rem;
    font-size: 0.75rem;
    color: var(--light-color);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .price {
    margin-top: 0.85rem;
    font-size: 1.35rem;
    font-weight: 700;
    color: var(--brand-color);
  }

  .buy {
    margin-top: 1rem;
    border: none;
    border-radius: 0.3rem;
    background: var(--brand-color);
    color: var(--darkest-color);
    font-family: 'Poppins', sans-serif;
    font-weight: 700;
    font-size: 0.95rem;
    padding: 0.7rem 0.5rem;
    cursor: pointer;
  }

  .buy:disabled {
    opacity: 0.55;
    cursor: default;
  }

  .buy:not(:disabled):hover {
    filter: brightness(1.08);
  }

  .empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: var(--light-color);
    font-size: 0.9rem;
    padding: 1rem;
  }
</style>

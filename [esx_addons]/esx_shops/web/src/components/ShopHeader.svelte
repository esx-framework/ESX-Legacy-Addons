<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { closeUI } from '@utils/nui';
  import { DEBOUNCE_DELAY_MS, SEARCH_ICON_COLOR } from '@/constants/ui';

  let searchValue = $state<string>('');
  let debounceTimeout: ReturnType<typeof setTimeout> | null = null;

  /**
   * Handles search input with debouncing
   * Delays the actual search query update to avoid excessive filtering
   */
  function handleSearchInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    searchValue = input.value;

    // Clear previous timeout
    if (debounceTimeout) {
      clearTimeout(debounceTimeout);
    }

    // Set new timeout for debounced search
    debounceTimeout = setTimeout(() => {
      shopStore.setSearchQuery(searchValue);
    }, DEBOUNCE_DELAY_MS);
  }

  /**
   * Closes the shop UI
   */
  function handleClose(): void {
    closeUI();
  }
</script>

<div class="shop-header">
  <div class="shop-name">
    <div class="shop-icon">
      <i class="fa-solid fa-shop"></i>
    </div>
    <div class="shop-title">{shopStore.shopName}</div>
  </div>

  <div class="shop-search">
    <div class="shop-search-icon">
      <i class="fas fa-search" style="color: {SEARCH_ICON_COLOR};"></i>
      <input
        type="text"
        placeholder="Search Item Name..."
        value={searchValue}
        oninput={handleSearchInput}
      />
    </div>
    <button class="shop-close" onclick={handleClose} aria-label="Close shop">
      <i class="fa-solid fa-xmark"></i>
    </button>
  </div>
</div>

<style>
  .shop-header {
    display: flex;
    width: 100%;
    justify-content: space-between;
    height: 5vh;
    margin-top: 0.5rem;
  }

  .shop-name {
    display: flex;
    align-items: center;
    font-family: 'Poppins', sans-serif;
    margin-left: 1rem;
    gap: 0.5rem;
  }

  .shop-title {
    color: var(--lightest-color);
    font-family: 'Poppins', sans-serif;
    font-weight: 600;
    font-size: 1rem;
  }

  .shop-icon {
    color: var(--lightest-color);
    font-size: 1rem;
  }

  .shop-search {
    display: flex;
    align-items: center;
    margin-right: 1rem;
    gap: 0.5rem;
  }

  .shop-search-icon {
    position: relative;
  }

  .shop-search-icon input {
    border: none;
    background: rgba(var(--lightest-color-rgb), 0.1);
    color: var(--lightest-color);
    font-family: 'Poppins', sans-serif;
    font-weight: 400;
    font-size: 0.8rem;
    border-radius: 0.2rem;
    padding: 0 0.5rem 0 2rem;
    height: 3.4vh;
    width: var(--cart-width);
  }

  .shop-search-icon i {
    position: absolute;
    left: 0.5rem;
    top: 50%;
    transform: translateY(-50%);
    pointer-events: none;
    font-size: 0.8rem;
  }

  .shop-close {
    background-color: rgba(var(--lightest-color-rgb), 0.1);
    color: var(--lightest-color);
    height: 3.4vh;
    width: 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 0.2rem;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .shop-close:hover {
    background: rgba(var(--brand-color-rgb), 0.2);
    color: var(--brand-color);
  }

  .shop-close i {
    font-size: 1rem;
  }
</style>

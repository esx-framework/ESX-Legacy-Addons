<!--
  @component ShopHeaderRight
  Displays search bar and close button in the right header section
-->
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

<div class="shop-header-right">
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

<style>
  .shop-header-right {
    display: flex;
    align-items: center;
    gap: 1rem;
    height: 5vh;
    width: 100%;
    padding-top: 0.5rem;
  }

  .shop-search-icon {
    position: relative;
    flex: 1;
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
    width: 100%;
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
    margin-left: auto;
  }

  .shop-close:hover {
    background: rgba(var(--brand-color-rgb), 0.2);
    color: var(--brand-color);
  }

  .shop-close i {
    font-size: 1rem;
  }
</style>

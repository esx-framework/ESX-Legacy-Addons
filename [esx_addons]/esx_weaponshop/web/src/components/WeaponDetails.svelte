<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<!--
  @component WeaponDetails
  Displays selected weapon preview and purchase/customization actions.
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { fetchNui } from '@utils/nui';
  import { NUI_EVENTS } from '@/types/nui';
  import type { WeaponDetailsTab } from '@/types/shop';
  import WeaponImage from './WeaponImage.svelte';

  let item = $derived(shopStore.selectedItem);
  let categoryLabel = $derived(
    item
      ? (shopStore.categories.find((category) => category.id === item.category)?.label ?? item.category)
      : ''
  );

  let tabs = $derived<{
    id: WeaponDetailsTab;
    label: string;
    count?: number;
  }[]>([
    { id: 'weapon', label: shopStore.locales.tabWeapon },
    { id: 'ammo', label: shopStore.locales.tabAmmo },
    { id: 'components', label: shopStore.locales.tabComponents, count: item?.upgrades.components.length ?? 0 },
    { id: 'tints', label: shopStore.locales.tabTints, count: item?.upgrades.tints.length ?? 0 }
  ]);

  let ammoTotal = $derived(
    item?.upgrades.ammo ? shopStore.ammoAmount * item.upgrades.ammo.pricePerRound : 0
  );
  let ammoLimit = $derived(item?.upgrades.ammo?.maxAmmo ?? null);
  let ammoDisplay = $derived(
    item?.state.owned
      ? (typeof ammoLimit === 'number' ? `${item.state.ammo}/${ammoLimit}` : item.state.ammo.toString())
      : '-'
  );
  let ammoButtonLabel = $derived(
    item?.state.owned
      ? (shopStore.ammoPurchaseLimit > 0 ? shopStore.locales.buyAmmo : shopStore.locales.ammoFull)
      : shopStore.locales.requiresWeapon
  );

  function formatMoney(value: number): string {
    return `$${value.toLocaleString()}`;
  }

  function hasComponent(componentName: string): boolean {
    return item?.state.components.includes(componentName) ?? false;
  }

  function setAmmoFromInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    shopStore.setAmmoAmount(Number(input.value));
  }

  async function buyWeapon(): Promise<void> {
    if (!item || shopStore.buying || item.state.owned) {
      return;
    }

    shopStore.buying = true;
    await fetchNui(NUI_EVENTS.BUY_WEAPON, {
      weaponName: item.name
    });
    shopStore.buying = false;
  }

  async function buyUpgrade(payload: Record<string, unknown>): Promise<void> {
    if (!item || shopStore.buying || !item.state.owned) {
      return;
    }

    shopStore.buying = true;
    await fetchNui(NUI_EVENTS.BUY_UPGRADE, {
      weaponName: item.name,
      ...payload
    });
    shopStore.buying = false;
  }
</script>

<div class="details">
  {#if item}
    <div class="preview">
      <WeaponImage name={item.name} image={item.image} alt={item.label} />
    </div>

    <div class="summary">
      <div class="meta">
        <div class="name">{item.label}</div>
        <div class="category">{categoryLabel}</div>
      </div>
      <div class="price">{formatMoney(item.price)}</div>
    </div>

    <div class="tabs" role="tablist" aria-label="Weapon details">
      {#each tabs as tab (tab.id)}
        <button
          type="button"
          class="tab"
          class:active={shopStore.activeDetailsTab === tab.id}
          data-tab={tab.id}
          role="tab"
          aria-selected={shopStore.activeDetailsTab === tab.id}
          onclick={() => shopStore.setDetailsTab(tab.id)}
        >
          <span>{tab.label}</span>
          {#if typeof tab.count === 'number' && tab.count > 0}
            <small>{tab.count}</small>
          {/if}
        </button>
      {/each}
    </div>

    <div class="tab-content">
      {#if shopStore.activeDetailsTab === 'weapon'}
        <div class="weapon-panel">
          <div class="stat-row">
            <span>{shopStore.locales.ammo}</span>
            <strong>{ammoDisplay}</strong>
          </div>
          <div class="stat-row">
            <span>{shopStore.locales.components}</span>
            <strong>{item.state.components.length}/{item.upgrades.components.length}</strong>
          </div>
          <button class="primary-action" disabled={shopStore.buying || item.state.owned} onclick={buyWeapon}>
            {item.state.owned ? shopStore.locales.owned.toUpperCase() : shopStore.locales.buy.toUpperCase()}
          </button>
        </div>
      {:else if shopStore.activeDetailsTab === 'ammo'}
        {#if item.upgrades.ammo}
          <div class="ammo-panel">
            <div class="stat-row">
              <span>{shopStore.locales.pricePerRound}</span>
              <strong>{formatMoney(item.upgrades.ammo.pricePerRound)}</strong>
            </div>
            <div class="ammo-stepper">
              <button
                type="button"
                disabled={!item.state.owned || !shopStore.canBuySelectedAmmo || shopStore.ammoAmount <= item.upgrades.ammo.minAmount}
                onclick={() => shopStore.setAmmoAmount(shopStore.ammoAmount - 1)}
              >-</button>
              <input
                type="number"
                min={item.upgrades.ammo.minAmount}
                max={shopStore.ammoPurchaseLimit}
                value={shopStore.ammoAmount}
                disabled={!item.state.owned || shopStore.ammoPurchaseLimit <= 0}
                oninput={setAmmoFromInput}
              />
              <button
                type="button"
                disabled={!item.state.owned || shopStore.ammoPurchaseLimit <= 0 || shopStore.ammoAmount >= shopStore.ammoPurchaseLimit}
                onclick={() => shopStore.setAmmoAmount(shopStore.ammoAmount + 1)}
              >+</button>
            </div>
            <div class="quick-amounts">
              {#each item.upgrades.ammo.quickAmounts as amount (amount)}
                <button
                  type="button"
                  disabled={!item.state.owned || shopStore.ammoPurchaseLimit <= 0 || amount > shopStore.ammoPurchaseLimit}
                  onclick={() => shopStore.setAmmoAmount(amount)}
                >
                  {amount}
                </button>
              {/each}
            </div>
            <div class="stat-row total">
              <span>{shopStore.locales.total}</span>
              <strong>{formatMoney(ammoTotal)}</strong>
            </div>
            <button
              class="primary-action"
              disabled={shopStore.buying || !shopStore.canBuySelectedAmmo}
              onclick={() => buyUpgrade({ action: 'ammo', amount: shopStore.ammoAmount })}
            >
              {ammoButtonLabel.toUpperCase()}
            </button>
          </div>
        {:else}
          <div class="empty-state">{shopStore.locales.noAmmoAvailable}</div>
        {/if}
      {:else if shopStore.activeDetailsTab === 'components'}
        {#if item.upgrades.components.length}
          <div class="option-list">
            {#each item.upgrades.components as component (component.name)}
              <div class="option-row" class:owned={hasComponent(component.name)}>
                <div>
                  <span>{component.label}</span>
                  <small>{hasComponent(component.name) ? shopStore.locales.owned : formatMoney(component.price)}</small>
                </div>
                <button
                  type="button"
                  disabled={shopStore.buying || !item.state.owned || hasComponent(component.name)}
                  onclick={() => buyUpgrade({ action: 'component', componentName: component.name })}
                >
                  {hasComponent(component.name) ? shopStore.locales.owned : shopStore.locales.buy}
                </button>
              </div>
            {/each}
          </div>
        {:else}
          <div class="empty-state">{shopStore.locales.noComponentsAvailable}</div>
        {/if}
      {:else if shopStore.activeDetailsTab === 'tints'}
        {#if item.upgrades.tints.length}
          <div class="tint-grid">
            {#each item.upgrades.tints as tint (tint.index)}
              <button
                type="button"
                class="tint-option"
                class:equipped={item.state.tintIndex === tint.index}
                disabled={shopStore.buying || !item.state.owned || item.state.tintIndex === tint.index}
                onclick={() => buyUpgrade({ action: 'tint', tintIndex: tint.index })}
              >
                <span class="swatch" style:background={tint.color}></span>
                <span class="tint-label">{tint.label}</span>
                <small>{item.state.tintIndex === tint.index ? shopStore.locales.equipped : tint.price > 0 ? formatMoney(tint.price) : shopStore.locales.apply}</small>
              </button>
            {/each}
          </div>
        {:else}
          <div class="empty-state">{shopStore.locales.noTintsAvailable}</div>
        {/if}
      {/if}
    </div>
  {:else}
    <div class="empty">{shopStore.locales.noWeaponSelected}</div>
  {/if}
</div>

<style>
  .details {
    width: 100%;
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    margin: 0 0.75rem var(--shop-gutter, 1rem) 0;
    padding: 0.85rem;
    gap: 0.75rem;
    background: rgba(var(--lightest-color-rgb), 0.035);
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.35rem;
  }

  .preview {
    --weapon-image-width: auto;
    --weapon-image-max-width: 12.25rem;
    --weapon-image-max-height: 58%;
    position: relative;
    flex: 0 0 12.5rem;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background:
      linear-gradient(180deg, rgba(var(--lightest-color-rgb), 0.06), rgba(var(--lightest-color-rgb), 0.025)),
      repeating-linear-gradient(90deg, transparent 0, transparent 2.8rem, rgba(var(--lightest-color-rgb), 0.025) 2.85rem),
      repeating-linear-gradient(0deg, transparent 0, transparent 2.8rem, rgba(var(--lightest-color-rgb), 0.02) 2.85rem);
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.25rem;
    padding: 1.2rem;
    overflow: hidden;
  }

  .preview::after {
    content: '';
    position: absolute;
    left: 13%;
    right: 13%;
    bottom: 16%;
    height: 0.12rem;
    background: linear-gradient(90deg, transparent, rgba(var(--brand-color-rgb), 0.72), transparent);
    box-shadow: 0 0 1rem rgba(var(--brand-color-rgb), 0.2);
  }

  .summary {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: start;
    gap: 0.7rem;
  }

  .meta {
    min-width: 0;
    border-left: 0.18rem solid var(--brand-color);
    padding-left: 0.65rem;
  }

  .name {
    font-size: 1.06rem;
    font-weight: 700;
    line-height: 1.1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .category {
    display: inline-flex;
    margin-top: 0.32rem;
    padding: 0.16rem 0.4rem;
    background: rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.2rem;
    font-size: 0.68rem;
    color: var(--light-color);
    text-transform: uppercase;
  }

  .price {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 4.4rem;
    min-height: 2.1rem;
    padding: 0.2rem 0.6rem;
    background: rgba(var(--brand-color-rgb), 0.16);
    border: 1px solid rgba(var(--brand-color-rgb), 0.25);
    border-radius: 0.25rem;
    font-size: 1.06rem;
    font-weight: 700;
    color: var(--brand-color);
  }

  .tabs {
    display: flex;
    align-items: stretch;
    gap: 0.35rem;
    min-height: 2rem;
    overflow: hidden;
  }

  .tab {
    border: 1px solid transparent;
    border-radius: 0.25rem;
    background: rgba(var(--lightest-color-rgb), 0.08);
    color: var(--light-color);
    font-family: var(--font-family);
    font-size: 0.62rem;
    font-weight: 700;
    text-transform: uppercase;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.16rem;
    flex: 0 1 auto;
    min-width: 4.55rem;
    overflow: hidden;
    padding: 0 0.58rem;
    cursor: pointer;
  }

  .tab[data-tab='components'] {
    flex: 1 1 8.25rem;
    min-width: 7.8rem;
  }

  .tab[data-tab='weapon'],
  .tab[data-tab='ammo'],
  .tab[data-tab='tints'] {
    flex: 0 1 5.35rem;
  }

  .tab span {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tab small {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: 0 0 auto;
    color: var(--darkest-color);
    background: var(--brand-color);
    border-radius: 0.2rem;
    min-width: 0.92rem;
    min-height: 0.92rem;
    padding: 0 0.14rem;
    font-size: 0.52rem;
    line-height: 1;
  }

  .tab.active {
    background: var(--brand-color);
    color: var(--darkest-color);
  }

  .tab-content {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    scrollbar-width: none;
  }

  .tab-content::-webkit-scrollbar {
    display: none;
  }

  .weapon-panel,
  .ammo-panel {
    display: flex;
    flex-direction: column;
    gap: 0.55rem;
    min-height: 100%;
  }

  .stat-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    min-height: 2.1rem;
    padding: 0.45rem 0.55rem;
    border-radius: 0.25rem;
    background: rgba(var(--lightest-color-rgb), 0.06);
    color: var(--light-color);
    font-size: 0.72rem;
  }

  .stat-row strong {
    color: var(--lightest-color);
    font-size: 0.82rem;
  }

  .stat-row.total strong {
    color: var(--brand-color);
  }

  .ammo-stepper {
    display: grid;
    grid-template-columns: 2.35rem minmax(0, 1fr) 2.35rem;
    gap: 0.45rem;
  }

  .ammo-stepper button,
  .quick-amounts button,
  .option-row button,
  .primary-action {
    border: none;
    border-radius: 0.25rem;
    font-family: var(--font-family);
    font-weight: 700;
    cursor: pointer;
    transition: filter 0.2s ease, transform 0.2s ease;
  }

  .ammo-stepper button {
    background: rgba(var(--lightest-color-rgb), 0.1);
    color: var(--lightest-color);
    font-size: 1rem;
  }

  .ammo-stepper input {
    width: 100%;
    height: 2.35rem;
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.25rem;
    background: rgba(var(--lightest-color-rgb), 0.08);
    color: var(--lightest-color);
    font-family: var(--font-family);
    font-weight: 700;
    text-align: center;
  }

  .quick-amounts {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 0.35rem;
  }

  .quick-amounts button {
    min-height: 1.85rem;
    background: rgba(var(--lightest-color-rgb), 0.08);
    color: var(--light-color);
    font-size: 0.68rem;
  }

  .option-list {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }

  .option-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 4.2rem;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    background: rgba(var(--lightest-color-rgb), 0.06);
    border: 1px solid transparent;
    border-radius: 0.25rem;
  }

  .option-row.owned {
    border-color: rgba(var(--brand-color-rgb), 0.25);
  }

  .option-row span {
    display: block;
    color: var(--lightest-color);
    font-size: 0.76rem;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .option-row small {
    display: block;
    margin-top: 0.12rem;
    color: var(--light-color);
    font-size: 0.64rem;
    text-transform: uppercase;
  }

  .option-row button {
    min-height: 2rem;
    background: var(--brand-color);
    color: var(--darkest-color);
    font-size: 0.68rem;
    text-transform: uppercase;
  }

  .tint-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.45rem;
  }

  .tint-option {
    min-height: 4.45rem;
    border: 1px solid rgba(var(--lightest-color-rgb), 0.08);
    border-radius: 0.25rem;
    background: rgba(var(--lightest-color-rgb), 0.055);
    color: var(--lightest-color);
    font-family: var(--font-family);
    display: grid;
    grid-template-columns: 1.55rem minmax(0, 1fr);
    grid-template-rows: auto auto;
    align-items: center;
    column-gap: 0.45rem;
    padding: 0.45rem;
    cursor: pointer;
    text-align: left;
  }

  .tint-option.equipped {
    border-color: rgba(var(--brand-color-rgb), 0.55);
    background: rgba(var(--brand-color-rgb), 0.1);
  }

  .swatch {
    grid-row: 1 / 3;
    width: 1.55rem;
    height: 1.55rem;
    border-radius: 50%;
    border: 1px solid rgba(var(--lightest-color-rgb), 0.35);
  }

  .tint-label {
    font-size: 0.68rem;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tint-option small {
    color: var(--light-color);
    font-size: 0.62rem;
    text-transform: uppercase;
  }

  .primary-action {
    margin-top: auto;
    min-height: 2.65rem;
    background: var(--brand-color);
    color: var(--darkest-color);
    font-size: 0.9rem;
    text-transform: uppercase;
    padding: 0.65rem 0.5rem;
  }

  button:disabled,
  input:disabled {
    opacity: 0.55;
    cursor: default;
  }

  button:not(:disabled):hover {
    filter: brightness(1.08);
    transform: translateY(-0.04rem);
  }

  .empty,
  .empty-state {
    flex: 1;
    min-height: 8rem;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: var(--light-color);
    font-size: 0.8rem;
    padding: 1rem;
  }
</style>

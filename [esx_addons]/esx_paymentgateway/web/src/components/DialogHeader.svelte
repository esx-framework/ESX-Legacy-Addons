<script lang="ts">
  /**
   * Top of the dialog: the server's logo or the ESX mark, the dialog's name and the close button.
   */
  import X from 'lucide-svelte/icons/x';
  import esxLogo from '../assets/esx-logo.png';

  interface Props {
    /** Server logo URL, null for the ESX mark */
    logo: string | null;
    /** Name of the dialog, e.g. "Payment" */
    heading: string;
    /** Text for the close button */
    closeLabel: string;
    /** Whether closing is possible right now */
    canClose: boolean;
    /** Called when the player closes the dialog */
    onclose: () => void;
  }

  let { logo, heading, closeLabel, canClose, onclose }: Props = $props();

  let broken = $state(false);
  const source = $derived(logo && !broken ? logo : esxLogo);
</script>

<header class="header">
  <img class="logo" src={source} alt="" onerror={(): boolean => (broken = true)} />
  <span class="heading">{heading}</span>
  <button
    type="button"
    class="close"
    aria-label={closeLabel}
    title={closeLabel}
    disabled={!canClose}
    onclick={onclose}
  >
    <X size={18} strokeWidth={2.25} />
  </button>
</header>

<style>
  .header {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .logo {
    height: 22px;
    max-width: 120px;
    object-fit: contain;
  }

  .heading {
    flex: 1;
    font-size: var(--font-size-caption);
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--light-color);
  }

  .close {
    display: grid;
    place-items: center;
    width: 32px;
    height: 32px;
    border: 2px solid var(--mid-color);
    border-radius: 8px;
    background: transparent;
    color: var(--light-color);
    cursor: pointer;
    transition:
      border-color 150ms ease,
      color 150ms ease;
  }

  .close:hover:not(:disabled) {
    border-color: var(--brand-color);
    color: var(--brand-color);
  }

  .close:focus-visible {
    outline: 2px solid var(--brand-color);
    outline-offset: 2px;
  }

  .close:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>

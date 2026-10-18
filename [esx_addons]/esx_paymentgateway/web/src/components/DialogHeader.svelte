<script lang="ts">
  /**
   * Top of the bill: the server's logo or the ESX mark and the dialog's name, set to the left.
   */
  import esxLogo from '../assets/esx-logo.png';

  interface Props {
    /** Server logo URL, null for the ESX mark */
    logo: string | null;
    /** Name of the dialog, e.g. "Payment" */
    heading: string;
  }

  let { logo, heading }: Props = $props();

  let broken = $state(false);
  const source = $derived(logo && !broken ? logo : esxLogo);
</script>

<header class="header">
  <img class="logo" src={source} alt="" onerror={(): boolean => (broken = true)} />
  <span class="divider" aria-hidden="true"></span>
  <span class="heading">{heading}</span>
</header>

<style>
  .header {
    display: flex;
    align-items: center;
    gap: 12px;
    min-height: 28px;
  }

  .logo {
    height: 20px;
    max-width: 120px;
    object-fit: contain;
  }

  .divider {
    width: 1px;
    height: 14px;
    background: var(--mid-color);
  }

  .heading {
    font-size: var(--font-size-caption);
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--light-color);
  }
</style>

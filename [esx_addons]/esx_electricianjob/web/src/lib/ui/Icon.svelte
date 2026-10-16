<script module lang="ts">
  /** Names of the available icons. */
  export type IconName =
    | 'grab'
    | 'move'
    | 'rotate'
    | 'join'
    | 'strip'
    | 'tape'
    | 'cap'
    | 'zap'
    | 'zap-off'
    | 'warning'
    | 'x'
    | 'check'
    | 'help'
    | 'clock'
    | 'arrow-left'
    | 'arrow-right';
</script>

<script lang="ts">
  /**
   * 24 × 24 stroke icon drawn in the current text color.
   */

  interface Props {
    /** Which icon */
    name: IconName;
    /** Rendered size in pixels */
    size?: number;
  }

  let { name, size = 18 }: Props = $props();
</script>

<svg
  class="icon"
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if name === 'grab'}
    <circle cx="9" cy="6" r="1.4" fill="currentColor" stroke="none" />
    <circle cx="15" cy="6" r="1.4" fill="currentColor" stroke="none" />
    <circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none" />
    <circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none" />
    <circle cx="9" cy="18" r="1.4" fill="currentColor" stroke="none" />
    <circle cx="15" cy="18" r="1.4" fill="currentColor" stroke="none" />
  {:else if name === 'move'}
    <path
      d="M12 3v18M3 12h18M12 3l-3 3M12 3l3 3M12 21l-3-3M12 21l3-3M3 12l3-3M3 12l3 3M21 12l-3-3M21 12l-3 3"
    />
  {:else if name === 'rotate'}
    <path d="M20 12a8 8 0 1 1-2.6-5.9" />
    <path d="M20 4v5h-5" />
  {:else if name === 'join'}
    <path d="M4 7h6a4 4 0 0 1 4 4v0" />
    <path d="M4 17h6a4 4 0 0 0 4-4v0" />
    <path d="M14 12h6" />
  {:else if name === 'strip'}
    <circle cx="6" cy="6" r="3" />
    <circle cx="6" cy="18" r="3" />
    <path d="M8.1 8.1 20 20M8.1 15.9 20 4" />
  {:else if name === 'tape'}
    <circle cx="11" cy="11" r="7" />
    <circle cx="11" cy="11" r="2.5" />
    <path d="M18 11v8h3" />
  {:else if name === 'cap'}
    <path d="M7 4h10l-2 14a3 3 0 0 1-6 0Z" />
    <path d="M8.5 9h7M9.2 13h5.6" />
  {:else if name === 'zap'}
    <path d="M13 2 4 14h7l-1 8 9-12h-7Z" />
  {:else if name === 'zap-off'}
    <path d="M13 2 9.5 6.7M15 10h4l-3.4 4.5M11 22l1-6.5M4 14h4" />
    <path d="M3 3l18 18" />
  {:else if name === 'warning'}
    <path d="M12 3 2 20h20Z" />
    <path d="M12 10v4M12 17.5v.01" />
  {:else if name === 'x'}
    <path d="M6 6l12 12M18 6 6 18" />
  {:else if name === 'check'}
    <path d="M5 12.5 10 17.5 19 7" />
  {:else if name === 'help'}
    <circle cx="12" cy="12" r="9" />
    <path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17.5v.01" />
  {:else if name === 'clock'}
    <circle cx="12" cy="13" r="8" />
    <path d="M12 9v4l2.5 2.5M10 2h4" />
  {:else if name === 'arrow-left'}
    <path d="M19 12H5M11 6l-6 6 6 6" />
  {:else if name === 'arrow-right'}
    <path d="M5 12h14M13 6l6 6-6 6" />
  {/if}
</svg>

<style>
  .icon {
    flex: none;
    display: block;
  }
</style>

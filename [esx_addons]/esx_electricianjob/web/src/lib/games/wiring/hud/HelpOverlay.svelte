<script lang="ts">
  /**
   * Tutorial pages, shown on first play and whenever the player opens Help. The round's
   * timer is paused while it is open.
   */
  import Button from '../../../ui/Button.svelte';
  import Icon from '../../../ui/Icon.svelte';
  import { spriteUrl, type SpriteName } from '../scene/assets';
  import { LABEL, RULES, TUTORIAL } from '../strings';

  interface Props {
    /** Closes the overlay */
    onclose: () => void;
    /** HUD scale factor */
    scale: number;
  }

  let { onclose, scale }: Props = $props();

  /** Sprites illustrating each page. */
  const ART: readonly (readonly SpriteName[])[] = [
    ['tester', 'breakerOff'],
    [],
    ['nutYellow'],
    ['switchOn', 'bulb'],
  ];

  let page = $state(0);
  let last: boolean = $derived(page === TUTORIAL.length - 1);
  let current = $derived(TUTORIAL[page] ?? TUTORIAL[0]);
</script>

<div class="backdrop" role="presentation">
  <div
    class="dialog"
    role="dialog"
    aria-modal="true"
    aria-labelledby="help-title"
    style="transform: translate(-50%, -50%) scale({scale})"
  >
    <span class="step">{page + 1} / {TUTORIAL.length}</span>
    <h3 id="help-title">{current?.title}</h3>

    <div class="art">
      {#if page === 1}
        <svg viewBox="0 0 240 90" class="wires" aria-hidden="true">
          <path
            d="M8 22 C 80 22, 110 40, 150 44"
            stroke="#060607"
            stroke-width="13"
            fill="none"
            stroke-linecap="round"
          />
          <path
            d="M8 22 C 80 22, 110 40, 150 44"
            stroke="#2a2b30"
            stroke-width="8"
            fill="none"
            stroke-linecap="round"
          />
          <path
            d="M8 68 C 80 68, 110 52, 150 48"
            stroke="#060607"
            stroke-width="13"
            fill="none"
            stroke-linecap="round"
          />
          <path
            d="M8 68 C 80 68, 110 52, 150 48"
            stroke="#2a2b30"
            stroke-width="8"
            fill="none"
            stroke-linecap="round"
          />
          <path d="M150 44 L 186 45" stroke="#ad6136" stroke-width="7" stroke-linecap="round" />
          <path d="M150 48 L 186 47" stroke="#ad6136" stroke-width="7" stroke-linecap="round" />
          <circle
            cx="212"
            cy="46"
            r="16"
            fill="none"
            stroke="#fb9b04"
            stroke-width="3"
            stroke-dasharray="4 5"
          />
        </svg>
      {:else}
        {#each ART[page] ?? [] as sprite (sprite)}
          <img src={spriteUrl(sprite)} alt="" class="sprite {sprite}" />
        {/each}
        {#if page === 2}
          <span class="twist"><Icon name="rotate" size={44} /></span>
        {/if}
      {/if}
    </div>

    <p class="body">{current?.body}</p>

    {#if last}
      <ul class="rules">
        {#each RULES as rule (rule.colors)}
          <li><strong>{rule.colors}</strong> {rule.meaning}</li>
        {/each}
      </ul>
    {/if}

    <div class="nav">
      <span class="dots">
        {#each TUTORIAL as _, i (i)}
          <span class="dot" class:active={i === page}></span>
        {/each}
      </span>
      <span class="buttons">
        {#if page > 0}
          <Button
            onclick={(): void => {
              page -= 1;
            }}
          >
            <Icon name="arrow-left" size={16} />
          </Button>
        {/if}
        {#if last}
          <Button variant="primary" onclick={onclose}>{LABEL.start}</Button>
        {:else}
          <Button
            variant="primary"
            onclick={(): void => {
              page += 1;
            }}
          >
            {LABEL.next}
            <Icon name="arrow-right" size={16} />
          </Button>
        {/if}
      </span>
    </div>
  </div>
</div>

<style>
  .backdrop {
    position: absolute;
    inset: 0;
    background: rgba(10, 10, 10, 0.55);
    pointer-events: auto;
  }

  .dialog {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 520px;
    padding: 26px 28px 22px;
    border: 1px solid var(--esx-line);
    border-top: 3px solid var(--esx-brand);
    border-radius: var(--esx-radius-lg);
    background: var(--esx-darkest);
    box-shadow: var(--esx-shadow);
  }

  .step {
    font-size: var(--esx-caption);
    font-weight: 600;
    letter-spacing: 0.12em;
    color: var(--esx-light);
  }

  h3 {
    margin-top: 4px;
    font-size: var(--esx-h3);
    font-weight: 600;
  }

  .art {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 22px;
    height: 120px;
    margin: 16px 0;
    border-radius: var(--esx-radius);
    background: radial-gradient(ellipse at 50% 40%, #3a3a3a 0%, #252525 70%);
  }

  .sprite {
    max-height: 96px;
    filter: drop-shadow(0 6px 8px rgba(0, 0, 0, 0.5));
  }

  .sprite.tester {
    width: 210px;
    max-height: none;
  }

  .sprite.nutYellow {
    width: 120px;
    max-height: none;
  }

  .sprite.bulb {
    width: 150px;
    max-height: none;
  }

  .twist {
    color: var(--esx-brand);
  }

  .wires {
    width: 260px;
    height: 100px;
  }

  .body {
    font-size: var(--esx-h6);
    line-height: 1.6;
    color: var(--esx-lightest);
  }

  .rules {
    margin: 12px 0 0;
    padding: 10px 12px;
    border-radius: var(--esx-radius);
    background: var(--esx-dark);
    list-style: none;
    font-size: 13px;
    color: var(--esx-light);
  }

  .rules strong {
    color: var(--esx-lightest);
  }

  .nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 20px;
  }

  .dots {
    display: flex;
    gap: 6px;
  }

  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--esx-mid);
  }

  .dot.active {
    background: var(--esx-brand);
  }

  .buttons {
    display: flex;
    gap: 10px;
  }
</style>

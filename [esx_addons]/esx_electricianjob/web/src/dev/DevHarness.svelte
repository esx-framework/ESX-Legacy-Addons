<script lang="ts">
  /**
   * Development-only stand-in for the Lua side: starts rounds in a normal browser. Opens a
   * round from the URL (`?game=wiring&seed=42&difficulty=2`) and offers a small toolbar to
   * roll new seeds. Never part of the production bundle.
   */
  import { GAME_KINDS, MAX_SEED, type Difficulty, type GameKind } from '../lib/nui/messages';
  import { isInGame } from '../lib/nui/bridge';
  import { session } from '../lib/session.svelte';

  const params = new URLSearchParams(window.location.search);
  const requestedGame = params.get('game');

  let game: GameKind = $state(
    GAME_KINDS.find((kind: GameKind): boolean => kind === requestedGame) ?? 'wiring',
  );
  let seed: number = $state(Number(params.get('seed') ?? '') || randomSeed());
  let difficulty: Difficulty = $state(toDifficulty(params.get('difficulty')));

  function randomSeed(): number {
    return Math.floor(Math.random() * MAX_SEED);
  }

  function toDifficulty(value: string | null): Difficulty {
    return value === '1' || value === '3' ? (Number(value) as Difficulty) : 2;
  }

  function start(): void {
    const url = new URL(window.location.href);
    url.searchParams.set('game', game);
    url.searchParams.set('seed', String(seed));
    url.searchParams.set('difficulty', String(difficulty));
    window.history.replaceState(null, '', url);
    window.postMessage(
      { action: 'open', session: { id: `dev-${seed}`, game, seed, difficulty } },
      '*',
    );
  }

  function reroll(): void {
    seed = randomSeed();
    start();
  }

  $effect((): void => {
    if (!isInGame() && !session.current) start();
  });
</script>

{#if !isInGame()}
  <div class="harness">
    <select bind:value={game}>
      {#each GAME_KINDS as kind (kind)}
        <option value={kind}>{kind}</option>
      {/each}
    </select>
    <input type="number" bind:value={seed} min="0" max={MAX_SEED} />
    {#each [1, 2, 3] as const as tier (tier)}
      <button
        type="button"
        class:active={difficulty === tier}
        onclick={(): void => {
          difficulty = tier;
          start();
        }}
      >
        {tier}
      </button>
    {/each}
    <button type="button" onclick={start}>restart</button>
    <button type="button" onclick={reroll}>new seed</button>
  </div>
{/if}

<style>
  .harness {
    position: fixed;
    left: 50%;
    bottom: 12px;
    z-index: 10;
    display: flex;
    gap: 6px;
    padding: 6px;
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.75);
    font-size: 12px;
    transform: translateX(-50%);
  }

  .harness select,
  .harness input,
  .harness button {
    height: 26px;
    padding: 0 8px;
    border: 1px solid #383838;
    border-radius: 4px;
    background: #252525;
    color: #f2f2f2;
    font: inherit;
  }

  .harness input {
    width: 110px;
  }

  .harness .active {
    border-color: #fb9b04;
  }
</style>

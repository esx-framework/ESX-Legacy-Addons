<script lang="ts">
  /**
   * Junction box minigame: canvas scene plus the ESX-styled HUD around it.
   *
   * The scene is driven by WiringEngine and drawn by WiringRenderer; this component wires
   * pointer input into the engine, schedules frames only when something changed and mirrors
   * the few values the HUD shows into Svelte state.
   */
  import { onDestroy, untrack } from 'svelte';
  import type { GameOutcome, GameSession } from '../../nui/messages';
  import Button from '../../ui/Button.svelte';
  import Meter from '../../ui/Meter.svelte';
  import Panel from '../../ui/Panel.svelte';
  import { WIRING_TIERS, type WiringTier } from './difficulty';
  import type { Issue, LoadState } from './electrical';
  import { WiringEngine, type EngineEvent, type WiringAction } from './engine';
  import { generateWiringPuzzle } from './generator';
  import { computeWiringLayout, STAGE } from './layout';
  import { NUT_COLORS, type WiringPuzzle } from './model';
  import { loadWiringSprites, spriteUrl } from './scene/assets';
  import { WiringRenderer, type StageTransform } from './scene/renderer';
  import { compartment, TRAY, TRAY_AREAS } from './scene/tray';
  import { BRIEFING, ISSUE_TEXT, LABEL, NUT_CARD, TOAST } from './strings';

  interface Props {
    /** Round to play */
    session: GameSession;
    /** Called once when the round ends */
    onfinish: (outcome: GameOutcome, actions: readonly WiringAction[]) => void;
  }

  let { session, onfinish }: Props = $props();

  type Phase = 'loading' | 'playing' | 'passed' | 'failed';

  /** Stripper notches, largest wire first. */
  const NOTCHES: readonly number[] = [10, 12, 14, 16, 18];
  const TOAST_MS = 2600;
  const RESULT_MS = 1900;
  /** HUD never shrinks below this, so 720p stays readable. */
  const MIN_HUD_SCALE = 0.8;

  const round: GameSession = untrack((): GameSession => session);
  const puzzle: WiringPuzzle = generateWiringPuzzle(round.seed, round.difficulty);
  const tier: WiringTier = WIRING_TIERS[round.difficulty];
  const receptacleIds: readonly string[] = puzzle.loads
    .filter((load): boolean => load.kind === 'receptacle')
    .map((load): string => load.id);

  let canvas: HTMLCanvasElement | undefined = $state();
  let phase: Phase = $state('loading');
  let breakerOn = $state(true);
  let switchOn = $state(false);
  let mistakes = $state(0);
  let fixture: LoadState = $state('off');
  let outlets: Record<string, LoadState> = $state({});
  let toast: string | null = $state(null);
  let flash: 'shock' | 'short' | null = $state(null);
  let cursor = $state('default');
  let remaining = $state(tier.timeLimit);
  let stage: StageTransform = $state({ scale: 1, offsetX: 0, offsetY: 0 });
  let stripRequest: { id: string; x: number; y: number } | null = $state(null);

  let hudScale: number = $derived(Math.max(MIN_HUD_SCALE, stage.scale));
  let timeLabel: string = $derived(
    `${Math.floor(remaining / 60)}:${String(Math.max(0, remaining) % 60).padStart(2, '0')}`,
  );

  let engine: WiringEngine | null = null;
  let renderer: WiringRenderer | null = null;
  let frameRequested = false;
  let toastTimer = 0;
  let flashTimer = 0;
  let clock = 0;
  let resizeObserver: ResizeObserver | null = null;
  let removeProbe: (() => void) | null = null;
  let finished = false;
  const startedAt = performance.now();

  function invalidate(): void {
    if (frameRequested || !renderer) return;
    frameRequested = true;
    requestAnimationFrame((): void => {
      frameRequested = false;
      renderer?.render();
      if (renderer?.animating) invalidate();
    });
  }

  function showToast(text: string): void {
    toast = text;
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout((): void => {
      toast = null;
    }, TOAST_MS);
  }

  function showFlash(kind: 'shock' | 'short'): void {
    flash = kind;
    window.clearTimeout(flashTimer);
    flashTimer = window.setTimeout((): void => {
      flash = null;
    }, 420);
  }

  function syncHud(): void {
    if (!engine) return;
    breakerOn = engine.breakerOn;
    switchOn = engine.switchOn;
    mistakes = engine.mistakes;
    fixture = engine.live.loads.get('fixture') ?? 'off';
    const next: Record<string, LoadState> = {};
    for (const id of receptacleIds) next[id] = engine.live.loads.get(id) ?? 'off';
    outlets = next;
  }

  function end(outcome: GameOutcome): void {
    if (finished) return;
    finished = true;
    phase = outcome === 'success' ? 'passed' : 'failed';
    window.clearInterval(clock);
    engine?.cancel();
    const actions: readonly WiringAction[] = engine?.actions ?? [];
    window.setTimeout((): void => onfinish(outcome, actions), RESULT_MS);
  }

  function abort(): void {
    if (finished) return;
    finished = true;
    window.clearInterval(clock);
    onfinish('aborted', engine?.actions ?? []);
  }

  function handleEvent(event: EngineEvent): void {
    switch (event.type) {
      case 'shock':
        renderer?.spark(event.at, 18);
        showFlash('shock');
        showToast(TOAST.shock);
        break;
      case 'short':
        renderer?.spark(event.at, 40);
        showFlash('short');
        showToast(TOAST.short);
        break;
      case 'nut-rejected':
        showToast(
          event.reason === 'occupied'
            ? TOAST.nutOccupied
            : event.reason === 'single'
              ? TOAST.nutSingle
              : TOAST.nutTooSmall,
        );
        break;
      case 'nut-seated':
        showToast(TOAST.twist);
        break;
      case 'strip-request': {
        stripRequest = { id: event.conductorId, x: event.at.x, y: event.at.y };
        break;
      }
      case 'stripped':
        showToast(TOAST.stripped);
        break;
      case 'strip-nicked':
        renderer?.spark(event.at, 6);
        showToast(TOAST.nicked);
        break;
      case 'strip-slipped':
        showToast(TOAST.slipped);
        break;
      case 'not-damaged':
        showToast(TOAST.notDamaged);
        break;
      case 'taped':
        showToast(TOAST.taped);
        break;
      case 'mistake':
        mistakes = event.count;
        if (event.count >= tier.maxMistakes) end('failure');
        break;
      default:
        break;
    }
    syncHud();
    invalidate();
  }

  function stagePoint(event: PointerEvent): { x: number; y: number } {
    const rect = (canvas as HTMLCanvasElement).getBoundingClientRect();
    return (renderer as WiringRenderer).toStage(
      event.clientX - rect.left,
      event.clientY - rect.top,
    );
  }

  function updateCursor(): void {
    if (!engine) return;
    if (engine.held || engine.dragged || engine.twisting) cursor = 'grabbing';
    else if (engine.hover) cursor = 'grab';
    else cursor = 'default';
  }

  function onPointerDown(event: PointerEvent): void {
    if (!engine || phase !== 'playing') return;
    stripRequest = null;
    canvas?.setPointerCapture(event.pointerId);
    engine.pointerDown(stagePoint(event), event.button);
    updateCursor();
    invalidate();
  }

  function onPointerMove(event: PointerEvent): void {
    if (!engine || phase !== 'playing') return;
    const hoverBefore = engine.hover;
    engine.pointerMove(stagePoint(event));
    updateCursor();
    if (engine.held || engine.dragged || engine.twisting || engine.hover !== hoverBefore)
      invalidate();
  }

  function onPointerUp(event: PointerEvent): void {
    if (!engine || phase !== 'playing') return;
    engine.pointerUp(stagePoint(event));
    updateCursor();
    syncHud();
    invalidate();
  }

  function toggleBreaker(): void {
    if (!engine || phase !== 'playing') return;
    engine.toggleBreaker();
    syncHud();
    invalidate();
  }

  function toggleSwitch(): void {
    if (!engine || phase !== 'playing') return;
    engine.toggleSwitch();
    syncHud();
    invalidate();
  }

  function chooseNotch(notch: number): void {
    if (!engine || !stripRequest) return;
    engine.strip(stripRequest.id, notch);
    stripRequest = null;
    invalidate();
  }

  function inspect(): void {
    if (!engine || phase !== 'playing') return;
    const issues: Issue[] = engine.inspect();
    const first: Issue | undefined = issues[0];
    if (!first) {
      showToast(TOAST.passed);
      end('success');
      invalidate();
      return;
    }
    if (!tier.highlightIssues) engine.highlighted = new Set();
    showToast(`${TOAST.failed} ${ISSUE_TEXT[first.code]}`);
    engine.addMistake();
    invalidate();
  }

  function resize(): void {
    if (!canvas || !renderer) return;
    const rect = canvas.getBoundingClientRect();
    renderer.resize(rect.width, rect.height, Math.min(2, window.devicePixelRatio || 1));
    stage = renderer.stage;
    invalidate();
  }

  $effect((): (() => void) => {
    const target = canvas;
    let cancelled = false;
    if (!target) return (): void => undefined;

    void (async (): Promise<void> => {
      const [sprites] = await Promise.all([
        loadWiringSprites(),
        document.fonts.load('19px "Permanent Marker"'),
      ]);
      if (cancelled) return;
      engine = new WiringEngine(puzzle, computeWiringLayout(puzzle), TRAY_AREAS, handleEvent);
      renderer = new WiringRenderer(target, sprites, engine);
      resizeObserver = new ResizeObserver(resize);
      resizeObserver.observe(target);
      resize();
      syncHud();
      if (import.meta.env.MODE === 'e2e') {
        const { installWiringProbe } = await import('./probe');
        const activeRenderer = renderer;
        removeProbe = installWiringProbe(
          engine,
          target,
          (): StageTransform => activeRenderer.stage,
        );
      }
      phase = 'playing';
      clock = window.setInterval((): void => {
        remaining = Math.max(
          0,
          tier.timeLimit - Math.floor((performance.now() - startedAt) / 1000),
        );
        if (remaining === 0 && phase === 'playing') {
          showToast(TOAST.timeout);
          end('failure');
        }
      }, 250);
    })();

    return (): void => {
      cancelled = true;
    };
  });

  onDestroy((): void => {
    removeProbe?.();
    resizeObserver?.disconnect();
    window.clearInterval(clock);
    window.clearTimeout(toastTimer);
    window.clearTimeout(flashTimer);
  });
</script>

<div class="game" data-phase={phase} style="cursor: {cursor}">
  <canvas
    bind:this={canvas}
    class="scene"
    onpointerdown={onPointerDown}
    onpointermove={onPointerMove}
    onpointerup={onPointerUp}
    onpointercancel={onPointerUp}
    oncontextmenu={(event: MouseEvent): void => event.preventDefault()}
  ></canvas>

  <div
    class="stage-overlay"
    style="width: {STAGE.width}px; height: {STAGE.height}px; transform: translate({stage.offsetX}px, {stage.offsetY}px) scale({stage.scale})"
  >
    {#each NUT_COLORS as color (color)}
      {@const area = compartment(color)}
      <div
        class="nut-card"
        style="left: {area.x}px; top: {TRAY.y + TRAY.height + 6}px; width: {area.width}px"
      >
        <span class="nut-name {color}">{NUT_CARD[color][0]}</span>
        <span class="nut-rating">{NUT_CARD[color][1]}</span>
      </div>
    {/each}

    {#if stripRequest}
      <div class="notches" style="left: {stripRequest.x}px; top: {stripRequest.y - 96}px">
        <span class="notches-title">{LABEL.stripperNotch}</span>
        <div class="notches-row">
          {#each NOTCHES as notch (notch)}
            <button type="button" class="notch" onclick={(): void => chooseNotch(notch)}>
              {notch}
            </button>
          {/each}
          <span class="notches-unit">{LABEL.awg}</span>
        </div>
      </div>
    {/if}
  </div>

  <div class="hud" style="--hud-scale: {hudScale}">
    <div class="hud-left">
      <Panel caption="{LABEL.workOrder} #{round.seed.toString(16).toUpperCase().padStart(8, '0')}">
        <h4 class="title">{LABEL.title}</h4>
        <p class="briefing">{BRIEFING[puzzle.template]}</p>
        <div class="timer">
          <Meter value={remaining / tier.timeLimit} critical={remaining <= 30} />
          <span class="time" class:critical={remaining <= 30}>{timeLabel}</span>
        </div>
        <div class="mistakes">
          <span>{LABEL.mistakes}</span>
          <span class="pips">
            {#each Array.from({ length: tier.maxMistakes }, (_: unknown, i: number): number => i) as i (i)}
              <span class="pip" class:used={i < mistakes}></span>
            {/each}
          </span>
        </div>
      </Panel>

      <Panel caption={LABEL.panel}>
        <div class="controls">
          <button type="button" class="control" onclick={toggleBreaker}>
            <img src={spriteUrl(breakerOn ? 'breakerOn' : 'breakerOff')} alt="" class="breaker" />
            <span class="control-text">
              <span class="control-label">{LABEL.breaker} {puzzle.breakerAmps} A</span>
              <span class="state" class:on={breakerOn}>{breakerOn ? LABEL.on : LABEL.off}</span>
            </span>
          </button>
          {#if puzzle.wallSwitch}
            <button type="button" class="control" onclick={toggleSwitch}>
              <img src={spriteUrl(switchOn ? 'switchOn' : 'switchOff')} alt="" class="switch" />
              <span class="control-text">
                <span class="control-label">{LABEL.wallSwitch}</span>
                <span class="state" class:on={switchOn}>{switchOn ? LABEL.on : LABEL.off}</span>
              </span>
            </button>
          {/if}
        </div>
      </Panel>

      <Panel caption={LABEL.loads}>
        {#if puzzle.wallSwitch}
          <div class="load">
            <span class="bulb" class:lit={fixture === 'on' || fixture === 'reversed'}>
              <img src={spriteUrl('bulb')} alt="" />
            </span>
            <span>{LABEL.fixture}</span>
          </div>
        {/if}
        {#each receptacleIds as id, i (id)}
          <div class="load">
            <span class="led" class:on={outlets[id] === 'on'}></span>
            <span>{LABEL.outlet} {i + 1}</span>
            <span class="load-state">{outlets[id] === 'on' ? LABEL.live : LABEL.dead}</span>
          </div>
        {/each}
      </Panel>
    </div>

    <div class="hud-actions">
      <Button onclick={abort}>{LABEL.abort}</Button>
      <Button variant="primary" onclick={inspect} disabled={phase !== 'playing'}
        >{LABEL.inspect}</Button
      >
    </div>

    {#if toast}
      <div class="toast" role="status">{toast}</div>
    {/if}

    {#if phase === 'passed' || phase === 'failed'}
      <div class="result" class:passed={phase === 'passed'}>
        <h2>{phase === 'passed' ? TOAST.passed : TOAST.failed}</h2>
      </div>
    {/if}
  </div>

  <div class="flash {flash ?? ''}"></div>
</div>

<style>
  .game {
    position: fixed;
    inset: 0;
    overflow: hidden;
    background: var(--esx-darkest);
  }

  .scene {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    touch-action: none;
  }

  .stage-overlay {
    position: absolute;
    left: 0;
    top: 0;
    transform-origin: 0 0;
    pointer-events: none;
  }

  .nut-card {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1px;
    line-height: 1.25;
    text-align: center;
  }

  .nut-name {
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.1em;
  }

  .nut-name.orange {
    color: #f08a3c;
  }

  .nut-name.yellow {
    color: #f2cf3d;
  }

  .nut-name.red {
    color: #f0554a;
  }

  .nut-rating {
    font-size: 12px;
    color: var(--esx-lightest);
    opacity: 0.85;
  }

  .notches {
    position: absolute;
    transform: translateX(-50%);
    padding: 10px 12px;
    border: 1px solid var(--esx-line);
    border-radius: var(--esx-radius);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
    pointer-events: auto;
  }

  .notches-title {
    display: block;
    margin-bottom: 6px;
    font-size: var(--esx-caption);
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--esx-light);
  }

  .notches-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .notch {
    width: 38px;
    height: 34px;
    border: 2px solid transparent;
    border-radius: var(--esx-radius-sm);
    background: var(--esx-mid);
    font-weight: 600;
    cursor: pointer;
  }

  .notch:hover {
    border-color: var(--esx-brand);
    background: transparent;
  }

  .notches-unit {
    margin-left: 2px;
    font-size: var(--esx-caption);
    color: var(--esx-light);
  }

  .hud {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }

  .hud-left {
    position: absolute;
    left: 24px;
    top: 24px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    width: 340px;
    transform: scale(var(--hud-scale));
    transform-origin: 0 0;
    pointer-events: auto;
  }

  .title {
    font-size: var(--esx-h4);
    font-weight: 600;
  }

  .briefing {
    margin-top: 4px;
    font-size: 13px;
    color: var(--esx-light);
  }

  .timer {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 14px;
  }

  .timer :global(.meter) {
    flex: 1;
  }

  .time {
    min-width: 40px;
    font-size: var(--esx-h6);
    font-weight: 600;
    text-align: right;
  }

  .time.critical {
    color: var(--esx-danger);
  }

  .mistakes {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 10px;
    font-size: 13px;
    color: var(--esx-light);
  }

  .pips {
    display: flex;
    gap: 6px;
  }

  .pip {
    width: 10px;
    height: 10px;
    border: 2px solid var(--esx-mid);
    border-radius: 50%;
  }

  .pip.used {
    border-color: var(--esx-danger);
    background: var(--esx-danger);
  }

  .controls {
    display: flex;
    gap: 10px;
  }

  .control {
    display: flex;
    flex: 1;
    align-items: center;
    gap: 10px;
    padding: 8px 10px;
    border: 2px solid transparent;
    border-radius: var(--esx-radius);
    background: var(--esx-dark);
    text-align: left;
    cursor: pointer;
    transition: border-color 140ms var(--esx-ease);
  }

  .control:hover {
    border-color: var(--esx-brand);
  }

  .breaker {
    height: 72px;
  }

  .switch {
    height: 64px;
  }

  .control-text {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .control-label {
    font-size: 12px;
    color: var(--esx-light);
  }

  .state {
    font-size: var(--esx-h6);
    font-weight: 700;
    color: var(--esx-light);
  }

  .state.on {
    color: var(--esx-brand);
  }

  .load {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 34px;
    font-size: 13px;
  }

  .load + .load {
    margin-top: 6px;
  }

  .bulb {
    position: relative;
    display: inline-flex;
    width: 64px;
  }

  .bulb img {
    width: 100%;
    filter: grayscale(0.25) brightness(0.8);
    transition: filter 200ms var(--esx-ease);
  }

  .bulb::after {
    content: '';
    position: absolute;
    right: -6px;
    top: 50%;
    width: 40px;
    height: 40px;
    margin-top: -20px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 214, 140, 0.95) 0%, rgba(255, 190, 90, 0) 70%);
    opacity: 0;
    transition: opacity 200ms var(--esx-ease);
  }

  .bulb.lit img {
    filter: none;
  }

  .bulb.lit::after {
    opacity: 1;
  }

  .led {
    width: 10px;
    height: 10px;
    margin: 0 27px 0 27px;
    border-radius: 50%;
    background: var(--esx-mid);
  }

  .led.on {
    background: var(--esx-success);
    box-shadow: 0 0 10px rgba(70, 167, 88, 0.8);
  }

  .load-state {
    margin-left: auto;
    color: var(--esx-light);
  }

  .hud-actions {
    position: absolute;
    right: 24px;
    bottom: 24px;
    display: flex;
    gap: 12px;
    transform: scale(var(--hud-scale));
    transform-origin: 100% 100%;
    pointer-events: auto;
  }

  .toast {
    position: absolute;
    left: 50%;
    top: 28px;
    max-width: 640px;
    padding: 12px 20px;
    border: 1px solid var(--esx-line);
    border-left: 3px solid var(--esx-brand);
    border-radius: var(--esx-radius);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
    font-size: var(--esx-h6);
    font-weight: 500;
    transform: translateX(-50%) scale(var(--hud-scale));
    transform-origin: 50% 0;
  }

  .result {
    position: absolute;
    left: 50%;
    top: 50%;
    padding: 28px 48px;
    border: 1px solid var(--esx-line);
    border-top: 3px solid var(--esx-danger);
    border-radius: var(--esx-radius-lg);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
    transform: translate(-50%, -50%) scale(var(--hud-scale));
  }

  .result.passed {
    border-top-color: var(--esx-brand);
  }

  .flash {
    position: absolute;
    inset: 0;
    opacity: 0;
    pointer-events: none;
    transition: opacity 380ms ease-out;
  }

  .flash.shock {
    background: radial-gradient(
      circle at 50% 50%,
      rgba(170, 210, 255, 0.35),
      rgba(120, 170, 255, 0.05)
    );
    opacity: 1;
    transition: none;
  }

  .flash.short {
    background: rgba(255, 245, 230, 0.55);
    opacity: 1;
    transition: none;
  }
</style>

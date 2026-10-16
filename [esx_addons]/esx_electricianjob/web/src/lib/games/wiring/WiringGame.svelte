<script lang="ts">
  /**
   * Junction box minigame: canvas scene plus the ESX-styled HUD around it.
   *
   * The scene is driven by WiringEngine and drawn by WiringRenderer; this component wires
   * pointer input into the engine, schedules frames only when something changed and mirrors
   * the values the HUD shows (checklist, controls, cursor badge) into Svelte state.
   */
  import { onDestroy, untrack } from 'svelte';
  import type { GameOutcome, GameSession } from '../../nui/messages';
  import Button from '../../ui/Button.svelte';
  import Icon, { type IconName } from '../../ui/Icon.svelte';
  import type { Vec2 } from '../../core/vec';
  import { bundleNumbers, coachInputFrom, meetingPoints, nextMove, type Move } from './coach';
  import { WIRING_TIERS, type WiringTier } from './difficulty';
  import type { Issue, LoadState } from './electrical';
  import {
    WiringEngine,
    type Aim,
    type EngineEvent,
    type SpliceRuntime,
    type ToolKind,
    type WiringAction,
  } from './engine';
  import { generateWiringPuzzle } from './generator';
  import {
    cableLabel,
    checklist,
    connectionPlan,
    type BundleRole,
    type ChecklistStep,
    type PlanBundle,
    type StepId,
  } from './guide';
  import ControlsCard from './hud/ControlsCard.svelte';
  import CursorBadge, { type Badge } from './hud/CursorBadge.svelte';
  import GuideCard, { type CableRow, type PlanChip, type PlanRow } from './hud/GuideCard.svelte';
  import HelpOverlay from './hud/HelpOverlay.svelte';
  import JobCard from './hud/JobCard.svelte';
  import { computeWiringLayout, STAGE, type WiringLayout } from './layout';
  import {
    NUT_COLORS,
    type Cable,
    type CableRole,
    type Conductor,
    type NutColor,
    type WiringPuzzle,
  } from './model';
  import { loadWiringSprites } from './scene/assets';
  import { WiringRenderer, type StageTransform } from './scene/renderer';
  import { compartment, TRAY, TRAY_AREAS } from './scene/tray';
  import {
    AIM_REASON,
    AIM_TEXT,
    BRIEFING,
    ISSUE_TEXT,
    ITEM_TEXT,
    LABEL,
    MOVE_POWER_ON,
    MOVE_TEXT,
    NUMBERED_MOVE_TEXT,
    NUT_CARD,
    TOAST,
  } from './strings';

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
  /** Remembers that the tutorial was seen; a convenience only, the game works without it. */
  const TUTORIAL_KEY = 'esx_electricianjob:wiring-tutorial';
  const ITEM_ICON: Readonly<Record<ToolKind | NutColor, IconName>> = {
    tester: 'zap',
    stripper: 'strip',
    tape: 'tape',
    orange: 'cap',
    yellow: 'cap',
    red: 'cap',
  };

  const round: GameSession = untrack((): GameSession => session);
  const puzzle: WiringPuzzle = generateWiringPuzzle(round.seed, round.difficulty);
  const tier: WiringTier = WIRING_TIERS[round.difficulty];
  const receptacleIds: readonly string[] = puzzle.loads
    .filter((load): boolean => load.kind === 'receptacle')
    .map((load): string => load.id);
  const cableById = new Map(
    puzzle.cables.map((cable: Cable): [string, Cable] => [cable.id, cable]),
  );
  const conductorById = new Map(
    puzzle.conductors.map((conductor: Conductor): [string, Conductor] => [conductor.id, conductor]),
  );

  const planRows: readonly PlanRow[] = connectionPlan(puzzle).map(
    (bundle: PlanBundle, index: number): PlanRow => ({
      number: index + 1,
      role: bundle.role,
      chips: bundle.conductorIds.map((id: string): PlanChip => {
        const conductor = conductorById.get(id) as Conductor;
        const cable = cableById.get(conductor.cableId) as Cable;
        return { id, label: cableLabel(cable), insulation: conductor.insulation };
      }),
    }),
  );
  const cableRows: readonly CableRow[] = puzzle.cables
    .filter((cable: Cable): cable is Cable & { role: CableRole } => cable.role !== 'pigtail')
    .map((cable: Cable & { role: CableRole }): CableRow => ({
      id: cable.id,
      label: cableLabel(cable),
      role: cable.role,
    }));

  let canvas: HTMLCanvasElement | undefined = $state();
  let phase: Phase = $state('loading');
  let breakerOn = $state(true);
  let switchOn = $state(false);
  let mistakes = $state(0);
  let fixture: LoadState = $state('off');
  let outlets: { id: string; state: LoadState }[] = $state([]);
  let steps: ChecklistStep[] = $state([]);
  let toast: string | null = $state(null);
  let flash: 'shock' | 'short' | null = $state(null);
  let cursor = $state('default');
  let remaining = $state(tier.timeLimit);
  let stage: StageTransform = $state({ scale: 1, offsetX: 0, offsetY: 0 });
  let stripRequest: { id: string; x: number; y: number } | null = $state(null);
  let badge: Badge | null = $state(null);
  let pointer = $state({ x: 0, y: 0 });
  let helpOpen = $state(false);

  let move = $state<Move | null>(null);
  let hintActive = $state(false);
  let hintsLeft = $state(tier.hints);

  let hudScale: number = $derived(Math.max(MIN_HUD_SCALE, stage.scale));
  /** Stage-anchored labels grow on small screens so they never drop below HUD size. */
  let labelBoost: number = $derived(Math.max(1, MIN_HUD_SCALE / stage.scale));
  let currentStep: StepId | undefined = $derived(
    steps.find((step: ChecklistStep): boolean => !step.done)?.id,
  );
  /** Hint currently on screen: always on the first tier, on request on the second. */
  let shownMove: Move | null = $derived(tier.guidance === 'full' || hintActive ? move : null);
  let moveText: string | null = $derived(shownMove === null ? null : describeMove(shownMove));
  let attention: 'breaker' | 'switch' | null = $derived(
    shownMove?.kind === 'breaker' || currentStep === 'power-off' || currentStep === 'power-on'
      ? 'breaker'
      : shownMove?.kind === 'switch' || currentStep === 'switch'
        ? 'switch'
        : null,
  );

  let engine: WiringEngine | null = null;
  let renderer: WiringRenderer | null = null;
  let meeting: ReadonlyMap<BundleRole, Vec2> | null = null;
  const numbers: ReadonlyMap<string, number> = bundleNumbers(puzzle);
  let frameRequested = false;
  let toastTimer = 0;
  let flashTimer = 0;
  let clock = 0;
  let resizeObserver: ResizeObserver | null = null;
  let removeProbe: (() => void) | null = null;
  let finished = false;
  const startedAt = performance.now();
  let pausedTotal = 0;
  let pausedAt = 0;

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
    outlets = receptacleIds.map((id: string): { id: string; state: LoadState } => ({
      id,
      state: engine?.live.loads.get(id) ?? 'off',
    }));
    steps = checklist({
      puzzle,
      testedLive: engine.testedLive,
      everOff: engine.everOff,
      breakerOn: engine.breakerOn,
      lightSeen: engine.lightSeen,
      stripped: engine.stripped,
      taped: engine.taped,
      splices: [...engine.splices.values()].map(
        (splice: SpliceRuntime): { members: readonly string[]; tight: boolean } => ({
          members: splice.members,
          tight: splice.nut !== null && splice.twist >= 1,
        }),
      ),
      passed: phase === 'passed',
    });
    updateCoach();
  }

  function updateCoach(): void {
    if (!engine || !meeting) return;
    const next = nextMove(coachInputFrom(engine, meeting));
    // A requested hint stays up until the player has done what it showed.
    if (hintActive && move && JSON.stringify(move) !== JSON.stringify(next)) hintActive = false;
    move = next;
    renderer?.setGuide({
      numbers: tier.guidance === 'full' ? numbers : null,
      move: tier.guidance === 'full' || hintActive ? move : null,
    });
  }

  /** Hint text; on the first tier it names the numbers on the wire markers. */
  function describeMove(next: Move): string {
    if (next.kind === 'breaker' && next.on) return MOVE_POWER_ON;
    if (tier.guidance !== 'full') return MOVE_TEXT[next.kind];
    switch (next.kind) {
      case 'place':
        return NUMBERED_MOVE_TEXT.place(numbers.get(next.conductorId) ?? 0);
      case 'join':
        return NUMBERED_MOVE_TEXT.join(numbers.get(next.conductorId) ?? 0);
      case 'nut': {
        const first = engine?.splices.get(next.spliceId)?.members[0];
        return NUMBERED_MOVE_TEXT.nut(first ? (numbers.get(first) ?? 0) : 0, next.color);
      }
      default:
        return MOVE_TEXT[next.kind];
    }
  }

  function useHint(): void {
    if (hintsLeft <= 0 || hintActive || !interactive()) return;
    hintsLeft -= 1;
    hintActive = true;
    updateCoach();
    invalidate();
  }

  function badgeFor(aim: Aim | null): Badge | null {
    if (!aim) return null;
    const blocked = (text: string): Badge => ({ icon: 'x', text, hint: null, tone: 'blocked' });
    switch (aim.action) {
      case 'pick': {
        if (!aim.item) return null;
        const [name, hint] = ITEM_TEXT[aim.item];
        return { icon: ITEM_ICON[aim.item], text: name, hint, tone: 'info' };
      }
      case 'grab':
        return aim.reason === 'breaker-on'
          ? {
              icon: 'warning',
              text: AIM_TEXT.grab,
              hint: AIM_REASON['breaker-on'],
              tone: 'warning',
            }
          : { icon: 'grab', text: AIM_TEXT.grab, hint: null, tone: 'info' };
      case 'move':
        return { icon: 'move', text: AIM_TEXT.move, hint: null, tone: 'info' };
      case 'twist':
        return { icon: 'rotate', text: AIM_TEXT.twist, hint: null, tone: 'action' };
      case 'join':
        return { icon: 'join', text: AIM_TEXT.join, hint: null, tone: 'action' };
      case 'strip':
        return aim.valid
          ? { icon: 'strip', text: AIM_TEXT.strip, hint: null, tone: 'action' }
          : blocked(AIM_REASON[aim.reason ?? 'not-damaged']);
      case 'tape':
        return aim.valid
          ? { icon: 'tape', text: AIM_TEXT.tape, hint: null, tone: 'action' }
          : blocked(AIM_REASON[aim.reason ?? 'already-marked']);
      case 'cap':
        return aim.valid
          ? { icon: 'cap', text: AIM_TEXT.cap, hint: null, tone: 'action' }
          : blocked(AIM_REASON[aim.reason ?? 'too-small']);
      case 'test':
        return aim.valid
          ? { icon: 'zap', text: AIM_TEXT.live, hint: null, tone: 'danger' }
          : { icon: 'zap-off', text: AIM_REASON['no-voltage'], hint: null, tone: 'info' };
      default:
        return null;
    }
  }

  function updatePointerUi(): void {
    if (!engine) return;
    const p = engine.pointer;
    pointer = { x: stage.offsetX + p.x * stage.scale, y: stage.offsetY + p.y * stage.scale };
    badge = badgeFor(engine.aim);
    const aim = engine.aim;
    if (engine.held) cursor = 'none';
    else if (engine.dragged || engine.twisting) cursor = 'grabbing';
    else if (aim && (aim.action === 'grab' || aim.action === 'move' || aim.action === 'pick'))
      cursor = 'grab';
    else if (aim?.action === 'twist') cursor = 'grab';
    else cursor = 'default';
  }

  function elapsedSeconds(): number {
    const paused = pausedTotal + (helpOpen ? performance.now() - pausedAt : 0);
    return Math.floor((performance.now() - startedAt - paused) / 1000);
  }

  function openHelp(): void {
    if (helpOpen || finished) return;
    engine?.cancel();
    stripRequest = null;
    badge = null;
    pausedAt = performance.now();
    helpOpen = true;
    invalidate();
  }

  function closeHelp(): void {
    if (!helpOpen) return;
    pausedTotal += performance.now() - pausedAt;
    helpOpen = false;
    try {
      window.localStorage.setItem(TUTORIAL_KEY, '1');
    } catch {
      // Storage can be unavailable; the tutorial will simply show again next time.
    }
  }

  function tutorialSeen(): boolean {
    try {
      return window.localStorage.getItem(TUTORIAL_KEY) === '1';
    } catch {
      return false;
    }
  }

  function end(outcome: GameOutcome): void {
    if (finished) return;
    finished = true;
    phase = outcome === 'success' ? 'passed' : 'failed';
    window.clearInterval(clock);
    engine?.cancel();
    badge = null;
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
        showToast(event.reason === 'occupied' ? TOAST.nutOccupied : TOAST.nutTooSmall);
        break;
      case 'nut-seated':
        showToast(TOAST.twist);
        break;
      case 'strip-request':
        stripRequest = { id: event.conductorId, x: event.at.x, y: event.at.y };
        break;
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

  function interactive(): boolean {
    return engine !== null && phase === 'playing' && !helpOpen;
  }

  function onPointerDown(event: PointerEvent): void {
    if (!engine || !interactive()) return;
    stripRequest = null;
    canvas?.setPointerCapture(event.pointerId);
    engine.pointerDown(stagePoint(event), event.button);
    updatePointerUi();
    syncHud();
    invalidate();
  }

  function onPointerMove(event: PointerEvent): void {
    if (!engine || !interactive()) return;
    const aimBefore = engine.aim;
    engine.pointerMove(stagePoint(event));
    updatePointerUi();
    if (engine.held || engine.dragged || engine.twisting || engine.aim !== aimBefore) invalidate();
  }

  function onPointerUp(event: PointerEvent): void {
    if (!engine || !interactive()) return;
    engine.pointerUp(stagePoint(event));
    updatePointerUi();
    syncHud();
    invalidate();
  }

  function onPointerLeave(): void {
    if (engine?.dragged || engine?.held || engine?.twisting) return;
    badge = null;
  }

  function toggleBreaker(): void {
    if (!engine || !interactive()) return;
    engine.toggleBreaker();
    syncHud();
    invalidate();
  }

  function toggleSwitch(): void {
    if (!engine || !interactive()) return;
    engine.toggleSwitch();
    syncHud();
    invalidate();
  }

  function chooseNotch(notch: number): void {
    if (!engine || !stripRequest) return;
    engine.strip(stripRequest.id, notch);
    stripRequest = null;
    syncHud();
    invalidate();
  }

  function highlightPlan(ids: readonly string[] | null): void {
    renderer?.setFocus(ids);
    invalidate();
  }

  function inspect(): void {
    if (!engine || !interactive()) return;
    const issues: Issue[] = engine.inspect();
    const first: Issue | undefined = issues[0];
    if (!first) {
      end('success');
      syncHud();
      invalidate();
      return;
    }
    if (!tier.highlightIssues) engine.highlighted = new Set();
    showToast(`${TOAST.failed} ${ISSUE_TEXT[first.code]}`);
    engine.addMistake();
    invalidate();
  }

  function onKeydown(event: KeyboardEvent): void {
    // Escape closes Help instead of aborting the round underneath.
    if (event.key === 'Escape' && helpOpen) {
      event.stopPropagation();
      event.preventDefault();
      closeHelp();
    }
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
      const layout: WiringLayout = computeWiringLayout(puzzle);
      meeting = meetingPoints(puzzle, layout);
      engine = new WiringEngine(puzzle, layout, TRAY_AREAS, handleEvent);
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
      if (!tutorialSeen()) openHelp();
      clock = window.setInterval((): void => {
        remaining = Math.max(0, tier.timeLimit - elapsedSeconds());
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

<svelte:window onkeydowncapture={onKeydown} />

<div class="game" data-phase={phase} data-help={helpOpen} style="cursor: {cursor}">
  <canvas
    bind:this={canvas}
    class="scene"
    onpointerdown={onPointerDown}
    onpointermove={onPointerMove}
    onpointerup={onPointerUp}
    onpointercancel={onPointerUp}
    onpointerleave={onPointerLeave}
    oncontextmenu={(event: MouseEvent): void => event.preventDefault()}
  ></canvas>

  <div
    class="stage-overlay"
    style="width: {STAGE.width}px; height: {STAGE.height}px; transform: translate({stage.offsetX}px, {stage.offsetY}px) scale({stage.scale}); --label-boost: {labelBoost}"
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
      <JobCard
        seed={round.seed}
        briefing={BRIEFING[puzzle.template]}
        {remaining}
        timeLimit={tier.timeLimit}
        {mistakes}
        maxMistakes={tier.maxMistakes}
        {steps}
        grade={tier.name}
        level={round.difficulty}
      />
      <ControlsCard
        {breakerOn}
        amps={puzzle.breakerAmps}
        hasSwitch={puzzle.wallSwitch !== null}
        {switchOn}
        fixture={puzzle.wallSwitch ? fixture : null}
        {outlets}
        {attention}
        ontogglebreaker={toggleBreaker}
        ontoggleswitch={toggleSwitch}
      />
      <GuideCard
        tier={round.difficulty}
        plan={planRows}
        cables={cableRows}
        onhighlight={highlightPlan}
      />
    </div>

    <div class="hud-actions">
      {#if tier.guidance === 'hints'}
        <Button onclick={useHint} disabled={hintsLeft === 0 || hintActive}>
          <Icon name="zap" size={16} />{LABEL.hint} ({hintsLeft})
        </Button>
      {/if}
      <Button onclick={openHelp}><Icon name="help" size={16} />{LABEL.help}</Button>
      <Button onclick={abort}>{LABEL.abort}</Button>
      <span
        class="inspect"
        class:attention={currentStep === 'inspect' || shownMove?.kind === 'inspect'}
      >
        <Button variant="primary" onclick={inspect} disabled={phase !== 'playing'}>
          {LABEL.inspect}
        </Button>
      </span>
    </div>

    {#if badge && !helpOpen}
      <CursorBadge {badge} x={pointer.x} y={pointer.y} scale={hudScale} />
    {/if}

    {#if moveText && phase === 'playing' && !helpOpen}
      <div class="coach" role="status">
        <span class="coach-label">{LABEL.next}</span>
        {moveText}
      </div>
    {/if}

    {#if toast}
      <div class="toast" role="status">{toast}</div>
    {/if}

    {#if phase === 'passed' || phase === 'failed'}
      <div class="result" class:passed={phase === 'passed'}>
        <h2>{phase === 'passed' ? TOAST.passed : TOAST.failed}</h2>
      </div>
    {/if}

    {#if helpOpen}
      <HelpOverlay onclose={closeHelp} scale={hudScale} />
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
    font-size: calc(14px * var(--label-boost));
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
    font-size: calc(13px * var(--label-boost));
    color: var(--esx-lightest);
    opacity: 0.85;
  }

  .notches {
    position: absolute;
    padding: 10px 12px;
    border: 1px solid var(--esx-line);
    border-radius: var(--esx-radius);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
    transform: translateX(-50%) scale(var(--label-boost));
    transform-origin: 50% 100%;
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
    gap: 12px;
    width: 350px;
    transform: scale(var(--hud-scale));
    transform-origin: 0 0;
    pointer-events: auto;
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

  .inspect {
    display: inline-flex;
    border-radius: var(--esx-radius);
  }

  .inspect.attention {
    box-shadow: 0 0 0 4px var(--esx-brand-soft);
  }

  .coach {
    position: absolute;
    left: 50%;
    bottom: 24px;
    display: flex;
    align-items: center;
    gap: 12px;
    max-width: 720px;
    padding: 12px 18px;
    border: 1px solid var(--esx-brand);
    border-radius: var(--esx-radius);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
    font-weight: 500;
    transform: translateX(-50%) scale(var(--hud-scale));
    transform-origin: 50% 100%;
  }

  .coach-label {
    padding: 2px 8px;
    border-radius: var(--esx-radius-sm);
    background: var(--esx-brand);
    color: var(--esx-darkest);
    font-size: var(--esx-caption);
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
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

/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * Plays a junction box round with real mouse input, the way a player would: breaker off,
 * strip damaged ends, re-mark whites used as hot, bundle each group, pick a wire nut from the
 * tray and twist it on clockwise, breaker and switch back on, inspect. Reads positions from
 * the e2e probe (src/lib/games/wiring/probe.ts).
 */

/** @typedef {import('puppeteer-core').Page} Page */
/**
 * Conductor end reported by the probe (mirrors ProbeEnd in probe.ts).
 * @typedef {object} ProbeEnd
 * @property {string} id Conductor id
 * @property {string} terminal Where the far end lands
 * @property {string} insulation Insulation color
 * @property {number} awg Wire size
 * @property {boolean} needsStrip Damaged end
 * @property {boolean} exposed Shows bare copper
 * @property {boolean} marked Re-identified as hot
 * @property {string | null} spliceId Splice the end belongs to
 * @property {number} x End position
 * @property {number} y End position
 * @property {number} anchorX Anchor position
 * @property {number} anchorY Anchor position
 * @property {number} reach Farthest the end may be from its anchor
 */

/**
 * Splice reported by the probe (mirrors ProbeSplice in probe.ts).
 * @typedef {object} ProbeSplice
 * @property {string} id Splice id
 * @property {string[]} members Joined conductor ids
 * @property {number} x Splice point
 * @property {number} y Splice point
 * @property {string | null} nut Connector color
 * @property {number} twist Twist progress
 */

/**
 * Evaluates an expression against the probe in the page.
 * @template T
 * @param {Page} page Browser page
 * @param {string} expression Expression using `probe`
 * @returns {Promise<T>} Result
 */
function probe(page, expression) {
  return /** @type {Promise<T>} */ (
    page.evaluate(`((probe) => ${expression})(window.__wiringProbe)`)
  );
}
/** @typedef {{ x: number, y: number }} Point */

const NUT_ORDER = ['orange', 'yellow', 'red'];

/**
 * Electrical group a conductor belongs to, read from where its far end lands.
 * @param {ProbeEnd} end Conductor end
 * @returns {'ground' | 'switched' | 'hot' | 'neutral'} Group
 */
function groupOf(end) {
  if (end.insulation === 'bare' || end.insulation === 'green') return 'ground';
  if (end.terminal === 'switch.b' || end.terminal === 'fixture.hot') return 'switched';
  if (
    end.terminal === 'panel.hot' ||
    end.terminal === 'switch.a' ||
    end.terminal.endsWith('.hot')
  ) {
    return 'hot';
  }
  return 'neutral';
}

/** Direction each group's splice is placed in, seen from the middle of the box. */
const GROUP_ANGLE = {
  hot: Math.PI * 1.15,
  neutral: Math.PI * 0.68,
  switched: Math.PI * 0.32,
  ground: Math.PI * 1.7,
};

/**
 * @param {Page} page Browser page
 * @returns {Promise<ProbeEnd[]>} Current conductor ends
 */
function ends(page) {
  return /** @type {Promise<ProbeEnd[]>} */ (probe(page, 'probe.ends()'));
}

/**
 * @param {Page} page Browser page
 * @returns {Promise<ProbeSplice[]>} Current splices
 */
function splices(page) {
  return /** @type {Promise<ProbeSplice[]>} */ (probe(page, 'probe.splices()'));
}

/**
 * Presses, moves in small steps and releases the left button.
 * @param {Page} page Browser page
 * @param {Point} from Start
 * @param {Point} to End
 * @param {() => Promise<void>} [beforeRelease] Runs while the button is still held
 * @returns {Promise<void>}
 */
async function drag(page, from, to, beforeRelease) {
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(to.x, to.y, { steps: 14 });
  if (beforeRelease) await beforeRelease();
  await page.mouse.up();
}

/** Screenshot helper handed in by the scenario, null to skip mid-action shots. */
/** @type {((label: string) => Promise<void>) | null} */
let capture = null;

/**
 * Takes a mid-action screenshot once per label.
 * @param {string} label Screenshot label
 * @returns {() => Promise<void>} Callback for {@link drag}
 */
function shotOnce(label) {
  return async () => {
    if (!capture) return;
    const take = capture;
    capture = label === 'aim-cap' ? null : capture;
    await take(label);
  };
}

/**
 * Picks a spot every conductor of a group can reach, as far as possible from foreign ends and
 * existing splices so the drop does not join the wrong wire.
 * @param {ProbeEnd[]} members Conductors of the group
 * @param {Point[]} obstacles Ends and splice points to stay clear of
 * @param {Point} center Middle of the box
 * @param {number} angle Preferred direction from the center
 * @param {number} scale Scene units to CSS pixels
 * @returns {Point} Splice target
 */
function clearTarget(members, obstacles, center, angle, scale) {
  let best = center;
  let bestClearance = -Infinity;
  for (const radius of [70, 110, 150, 190]) {
    for (let k = 0; k < 18; k++) {
      const a = angle + (k % 2 === 0 ? 1 : -1) * Math.ceil(k / 2) * 0.35;
      let point = {
        x: center.x + Math.cos(a) * radius * scale,
        y: center.y + Math.sin(a) * radius * scale,
      };
      for (let pass = 0; pass < 8; pass++) {
        for (const member of members) {
          const dx = point.x - member.anchorX;
          const dy = point.y - member.anchorY;
          const span = Math.hypot(dx, dy);
          const max = (member.reach / 0.92) * 0.8;
          if (span > max)
            point = {
              x: member.anchorX + (dx * max) / span,
              y: member.anchorY + (dy * max) / span,
            };
        }
      }
      const reachable = members.every(
        (member) =>
          Math.hypot(point.x - member.anchorX, point.y - member.anchorY) <=
          (member.reach / 0.92) * 0.85,
      );
      if (!reachable) continue;
      const clearance = Math.min(...obstacles.map((o) => Math.hypot(o.x - point.x, o.y - point.y)));
      if (clearance > bestClearance) {
        best = point;
        bestClearance = clearance;
      }
    }
  }
  return best;
}

/**
 * Strips a damaged end with the matching stripper notch.
 * @param {Page} page Browser page
 * @param {ProbeEnd} end Conductor end
 * @returns {Promise<void>}
 */
async function strip(page, end) {
  const stripper = /** @type {Point} */ (await probe(page, "probe.tool('stripper')"));
  await drag(page, stripper, end, shotOnce('aim-strip'));
  await page.waitForSelector('.notch');
  const notches = await page.$$('.notch');
  for (const notch of notches) {
    const label = await notch.evaluate((el) => el.textContent?.trim());
    if (label === String(end.awg)) {
      await notch.click();
      return;
    }
  }
  throw new Error(`no stripper notch for ${end.awg} AWG`);
}

/**
 * Wraps black tape around a conductor near its end.
 * @param {Page} page Browser page
 * @param {ProbeEnd} end Conductor end
 * @returns {Promise<void>}
 */
async function tape(page, end) {
  const roll = /** @type {Point} */ (await probe(page, "probe.tool('tape')"));
  await drag(page, roll, end);
}

/**
 * Bundles a group of conductors at a target point.
 * @param {Page} page Browser page
 * @param {string[]} ids Conductor ids
 * @param {Point} target Where the bundle should be made
 * @returns {Promise<ProbeSplice>} The resulting splice
 */
async function bundle(page, ids, target) {
  for (const [index, id] of ids.entries()) {
    const current = (await ends(page)).find((end) => end.id === id);
    if (!current) throw new Error(`conductor ${id} disappeared`);
    const splice = (await splices(page)).find((s) => s.members.includes(ids[0] ?? ''));
    const drop =
      index === 0
        ? target
        : splice
          ? { x: splice.x + 2, y: splice.y + 2 }
          : { x: target.x + 6, y: target.y + 4 };
    await drag(page, current, drop);
  }
  const made = (await splices(page)).find((s) => ids.every((id) => s.members.includes(id)));
  if (!made) {
    const state = (await ends(page))
      .filter((end) => ids.includes(end.id))
      .map((end) => `${end.id}@${Math.round(end.x)},${Math.round(end.y)}:${end.spliceId}`);
    throw new Error(
      `could not bundle ${ids.join(', ')} at ${Math.round(target.x)},${Math.round(target.y)}: ` +
        `${state.join(' ')} splices=${JSON.stringify(await splices(page))}`,
    );
  }
  return made;
}

/**
 * Picks the smallest wire nut that seats on a splice and twists it tight.
 * @param {Page} page Browser page
 * @param {ProbeSplice} splice Splice to cap
 * @returns {Promise<string>} Nut color used
 */
async function capSplice(page, splice) {
  for (const color of NUT_ORDER) {
    const source = /** @type {Point} */ (await probe(page, `probe.nuts('${color}')`));
    await drag(page, source, splice, color === 'orange' ? shotOnce('aim-cap') : undefined);
    const seated = (await splices(page)).find((s) => s.id === splice.id);
    if (seated?.nut) break;
  }
  const seated = (await splices(page)).find((s) => s.id === splice.id);
  if (!seated?.nut) throw new Error(`no wire nut fits splice ${splice.id}`);

  // Clockwise circles around the nut, a little over two turns.
  await page.mouse.move(seated.x, seated.y);
  await page.mouse.down();
  const radius = 54;
  for (let step = 0; step <= 64; step++) {
    const angle = (step / 28) * Math.PI * 2;
    await page.mouse.move(seated.x + Math.cos(angle) * radius, seated.y + Math.sin(angle) * radius);
  }
  await page.mouse.up();
  const tight = (await splices(page)).find((s) => s.id === splice.id);
  if (!tight || tight.twist < 1)
    throw new Error(`wire nut on ${splice.id} is not tight (${tight?.twist})`);
  return seated.nut;
}

/**
 * Clicks a HUD control button by its index (0 = breaker, 1 = wall switch).
 * @param {Page} page Browser page
 * @param {number} index Control index
 * @returns {Promise<void>}
 */
async function clickControl(page, index) {
  const controls = await page.$$('.control');
  const control = controls[index];
  if (!control) throw new Error(`HUD control ${index} missing`);
  await control.click();
}

/**
 * Solves the running round.
 * @param {Page} page Browser page
 * @param {(label: string) => Promise<void>} screenshot Screenshot helper
 * @returns {Promise<void>}
 */
export async function playWiring(page, screenshot) {
  capture = screenshot;
  await clickControl(page, 0); // Breaker off before touching anything.

  let all = await ends(page);
  for (const end of all) if (end.needsStrip && !end.exposed) await strip(page, end);

  all = await ends(page);
  const anchorsX = all.reduce((sum, end) => sum + end.anchorX, 0) / all.length;
  const pigtail = all.find((end) => end.id === 'pg.bare');
  const center = pigtail
    ? { x: pigtail.anchorX, y: pigtail.anchorY }
    : { x: anchorsX, y: all[0]?.anchorY ?? 0 };
  const scale = /** @type {number} */ (await probe(page, 'probe.scale()'));

  /** @type {Map<string, ProbeEnd[]>} */
  const groups = new Map();
  for (const end of all) groups.set(groupOf(end), [...(groups.get(groupOf(end)) ?? []), end]);

  for (const [group, members] of groups) {
    if (group === 'hot' || group === 'switched') {
      for (const member of members)
        if (member.insulation === 'white' && !member.marked) await tape(page, member);
    }
  }

  for (const [group, members] of groups) {
    const angle = GROUP_ANGLE[/** @type {keyof typeof GROUP_ANGLE} */ (group)];
    const ids = members.map((member) => member.id);
    const obstacles = [
      ...(await ends(page)).filter((end) => !ids.includes(end.id)),
      ...(await splices(page)),
    ];
    const target = clearTarget(members, obstacles, center, angle, scale);
    const splice = await bundle(
      page,
      members.map((member) => member.id),
      target,
    );
    await capSplice(page, splice);
  }
  await screenshot('wired');

  await clickControl(page, 0); // Breaker back on.
  if ((await page.$$('.control')).length > 1) await clickControl(page, 1);
  await page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
  );
  await screenshot('powered');
}

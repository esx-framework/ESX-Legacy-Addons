import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
const baseUrl = process.env.HUD_TEST_URL || "http://127.0.0.1:3000";
const output = process.env.HUD_TEST_OUTPUT || "/tmp/esx-hud-qa/screenshots";
mkdirSync(output, { recursive: true });
import assert from "node:assert/strict";
(async () => {
    const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_EXECUTABLE || undefined, headless: true });
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    const send = (type, value) => page.evaluate(({ type, value }) => window.postMessage({ type, value }, "*"), { type, value });
    await page.goto(`${baseUrl}/?preview`);
    assert.equal(await page.locator(".status-cell").count(), 4);
    await page.getByRole("button", { name: "Alerts", exact: true }).click();
    assert.match(await page.locator(".vehicle-alert").innerText(), /Low fuel/);
    assert.equal(await page.locator(".status-cell.critical").count(), 1);
    await page.getByRole("button", { name: "Diving", exact: true }).click();
    assert.equal(await page.locator(".telemetry").count(), 0);
    assert.equal(await page.locator(".status-cell").count(), 5);
    await page.getByRole("button", { name: "On foot", exact: true }).click();
    assert.equal(await page.locator(".weapon-panel").count(), 1);
    assert.equal(await page.locator(".voice-chip.speaking").count(), 1);
    await page.getByRole("button", { name: "Customize HUD" }).click();
    await page.getByRole("switch", { name: "Hide balances", exact: true }).check();
    assert.match(await page.locator(".wallet-panel").innerText(), /••••••/);
    await page.getByRole("button", { name: "Save changes" }).click();
    assert.match(await page.locator("footer").innerText(), /Preferences saved/);
    await page.keyboard.press("Escape");
    assert.equal(await page.getByRole("dialog").count(), 0);
    await page.reload();
    assert.match(await page.locator(".wallet-panel").innerText(), /••••••/);
    await page.getByRole("button", { name: "Customize HUD" }).click();
    await page.getByRole("button", { name: "Reset", exact: true }).click();
    assert.doesNotMatch(await page.locator(".wallet-panel").innerText(), /••••••/);
    await page.getByRole("button", { name: /Modules/ }).click();
    await page.getByRole("switch", { name: "Wallet", exact: true }).uncheck();
    assert.equal(await page.locator(".wallet-panel").count(), 0);
    await page.getByRole("switch", { name: "Wallet", exact: true }).check();
    await page.getByRole("button", { name: /Appearance/ }).click();
    await page.getByRole("switch", { name: "Cinematic mode", exact: true }).check();
    assert.equal(await page.locator(".identity").count(), 0);
    assert.equal(await page.getByRole("dialog").count(), 1);
    await page.getByRole("switch", { name: "Cinematic mode", exact: true }).uncheck();
    await page.getByRole("button", { name: "Reset", exact: true }).click();
    await page.keyboard.press("Escape");
    for (const [width, height] of [
        [1280, 720],
        [1920, 1080],
        [2560, 1080],
        [3840, 2160],
    ]) {
        await page.setViewportSize({ width, height });
        for (const selector of [".identity", ".location", ".status-cluster", ".voice-chip", ".telemetry"]) {
            const box = await page.locator(selector).boundingBox();
            assert(box && box.x >= 0 && box.y >= 0 && box.x + box.width <= width + 1 && box.y + box.height <= height + 1, `${selector} in ${width}x${height}`);
        }
        await page.getByRole("button", { name: "Customize HUD" }).click();
        const box = await page.getByRole("dialog").boundingBox();
        assert(box.y >= 0 && box.y + box.height <= height, `dialog ${height}`);
        await page.keyboard.press("Escape");
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.screenshot({ path: `${output}/hud-final.png` });
    await page.getByRole("button", { name: "Customize HUD" }).click();
    await page.screenshot({ path: `${output}/settings-final.png` });
    await page.keyboard.press("Escape");
    await send("VEH_HUD", { show: false });
    await page.waitForFunction(() => !document.querySelector(".telemetry"));
    assert.equal(await page.locator(".telemetry").count(), 0);
    await send("VEH_HUD", { show: true, speed: 201, fuel: { level: 0, maxLevel: 100 } });
    await page.waitForFunction(() => document.querySelector(".speed-number")?.textContent.includes("201"));
    await send("SHOW", false);
    await page.waitForFunction(() => !document.querySelector(".identity"));
    await send("OPEN_SETTINGS");
    await page.waitForFunction(() => document.querySelector("[role=dialog]"));
    await page.keyboard.press("Escape");
    await send("SET_CONFIG_DATA", { Locale: "en", Default: { Kmh: false }, Disable: { Money: true }, Colors: { Status: { healthBar: "#ffffff" } } });
    await send("SHOW", true);
    await page.waitForFunction(() => document.querySelector(".identity"));
    assert.equal(await page.locator(".wallet-panel").count(), 0);
    // Production mode: no preview content or game data before SHOW. Emulated NUI callbacks.
    const game = await browser.newPage();
    const callbacks = [];
    await game.addInitScript(() => {
        window.GetParentResourceName = () => "esx_hud";
        localStorage.setItem("esx-hud:preferences:v2", "{broken");
    });
    await game.route("https://esx_hud/**", async (route) => {
        callbacks.push({ url: route.request().url(), body: route.request().postDataJSON() });
        await route.fulfill({ status: 200, contentType: "application/json", body: '"ok"' });
    });
    await game.goto(`${baseUrl}/`);
    assert.equal(await game.locator(".preview-scene").count(), 0);
    assert.equal(await game.locator(".identity").count(), 0);
    await game.evaluate(() => window.postMessage({ type: "SET_CONFIG_DATA", value: { Locale: "en", Default: { Kmh: true }, Disable: {}, Colors: {} } }, "*"));
    await game.evaluate(() => window.postMessage({ type: "OPEN_SETTINGS" }, "*"));
    await game.waitForFunction(() => document.querySelector("[role=dialog]"));
    await game.getByRole("button", { name: "Save changes" }).click();
    await game.keyboard.press("Escape");
    await game.waitForFunction(() => !document.querySelector("[role=dialog]"));
    for (const callback of ["ready", "unitChanged", "minimapSettingChanged", "cinematicChanged", "closePanel"])
        assert(
            callbacks.some((c) => c.url.endsWith("/" + callback)),
            callback,
        );
    assert.equal(errors.length, 0, errors.join("\n"));
    console.log("PASS: scenarios, alerts, settings, persistence, reset, privacy, cinematic, module toggles, 4 resolutions, partial NUI updates, hidden settings, server disables, callbacks and startup.");
    await browser.close();
})().catch((e) => {
    console.error(e);
    process.exit(1);
});

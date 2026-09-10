import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
// Load the pure ES module without changing the legacy Vite package's module mode.
const source = await readFile(new URL("../src/hud/model.js", import.meta.url), "utf8");
const { sanitizePreferences, loadPreferences, fuelPercent, clamp } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);
test("corrupt or inaccessible saved settings cannot break startup", () => {
    assert.deepEqual(loadPreferences({ getItem: () => "{broken" }), {});
    assert.deepEqual(
        loadPreferences({
            getItem: () => {
                throw Error("denied");
            },
        }),
        {},
    );
    assert.deepEqual(loadPreferences({ getItem: () => "null" }), {});
});
test("stored preferences are restricted to supported types and usable sizes", () => {
    assert.deepEqual(sanitizePreferences({ scale: 100, opacity: -2, privacy: true, Status: "true", unknown: true }), { privacy: true, scale: 1.25, opacity: 0.65 });
    assert.deepEqual(sanitizePreferences({ scale: NaN, opacity: Infinity }), {});
});
test("fuel uses the tank capacity and safely handles empty or invalid tanks", () => {
    assert.equal(fuelPercent({ level: 25, maxLevel: 50 }), 50);
    assert.equal(fuelPercent({ level: 0, maxLevel: 100 }), 0);
    assert.equal(fuelPercent({ level: 20, maxLevel: 0 }), 0);
    assert.equal(fuelPercent({ level: 150, maxLevel: 100 }), 100);
    assert.equal(fuelPercent(), 0);
});
test("game status and speed cannot overflow their display bounds", () => {
    assert.equal(clamp(-40), 0);
    assert.equal(clamp(200), 100);
    assert.equal(clamp("72"), 72);
    assert.equal(clamp(1300, 0, 999), 999);
});

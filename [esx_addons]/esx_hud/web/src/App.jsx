import { createSignal, createEffect, onMount, onCleanup, For, Show } from "solid-js";
import { createStore } from "solid-js/store";
import Icon from "./hud/Icon";
import { defaults, STORAGE_KEY, loadPreferences, clamp, fuelPercent, initialHud, initialVehicle, statusItems, statusColors } from "./hud/model";
import { translate } from "./hud/locale";
import { Nui } from "./Utils/Nui";
import indicatorSound from "./assets/IndicatorSound.mp3";
import beltSound from "./assets/SeatbeltAlertSound.mp3";
import beltOn from "./assets/SeatbeltOnSound.mp3";
import beltOff from "./assets/SeatbeltOffSound.mp3";
import defaultLogo from "./assets/esx-logo.png";
import "./hud/hud.css";

const weaponImages = import.meta.glob("./assets/weapons/*.png", { eager: true, import: "default" });
const inGame = typeof window.GetParentResourceName === "function";
const preview = !inGame && new URLSearchParams(location.search).has("preview");
const moduleKeys = ["Status", "Vehicle", "Weapon", "Position", "Voice", "Money", "Info"];
const emptyStatus = { healthBar: 0, armorBar: 0, foodBar: 0, drinkBar: 0, staminaBar: 0, oxygenBar: 0, underwater: false };
const channels = (value) => {
    const match = /^#([0-9a-f]{3}|[0-9a-f]{6})([0-9a-f]{2})?$/i.exec(String(value ?? "").trim());
    if (!match) return undefined;
    const hex = match[1].length === 3 ? [...match[1]].map((c) => c + c).join("") : match[1];
    return [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(", ");
};

export default function App() {
    const [visible, setVisible] = createSignal(preview);
    const [panel, setPanel] = createSignal(false);
    const [tab, setTab] = createSignal("appearance");
    const [locale, setLocale] = createSignal("en");
    const [notice, setNotice] = createSignal("");
    const [busy, setBusy] = createSignal(false);
    const [hudReady, setHudReady] = createSignal(false);
    const [statusReady, setStatusReady] = createSignal(false);
    const [vehicleReady, setVehicleReady] = createSignal(false);
    const [hud, setHud] = createStore(initialHud);
    const [vehicle, setVehicle] = createStore(initialVehicle);
    const [status, setStatus] = createStore(emptyStatus);
    const [config, setConfig] = createStore({ Default: { ServerName: "", ServerTagline: "", Kmh: true }, Disable: {}, Colors: { Status: statusColors, Info: {}, Speedo: {} } });
    let saved = loadPreferences(localStorage);
    const [prefs, setPrefs] = createStore({ ...defaults, ...saved });
    const [viewportScale, setViewportScale] = createSignal(1);
    let dialog, previousFocus;
    const t = (key) => translate(locale(), key);
    const locked = (key) => moduleKeys.includes(key) && Boolean(config.Disable[key]);
    const hidden = (key) => locked(key) || Boolean(prefs[key]);
    const indicators = () => vehicle.defaultIndicators;
    const fuel = () => fuelPercent(vehicle.fuel);
    const money = (value) => (prefs.privacy ? "••••••" : new Intl.NumberFormat(locale() === "es" ? "es-ES" : "en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(Number(value) || 0));
    const range = () => clamp(hud.voice.range || 2, 1, 3);
    const direction = () => ["N", "NW", "W", "SW", "S", "SE", "E", "NE"][Math.round(clamp(hud.heading, 0, 360) / 45) % 8];
    const moduleVisible = () => visible() && !prefs.cinematic;
    const theme = () => config.Theme || {};
    const brand = () => theme().primaryColor || config.Default.AccentColor || "#fb9b04";
    const serverLogo = () => theme().logoUrl || hud.serverLogo || defaultLogo;
    const showStatus = (key) => !prefs.smartStatus || (key === "oxygenBar" ? status.underwater : key === "staminaBar" ? status.staminaBar < 99 : key === "armorBar" ? status.armorBar > 0 : true);
    const critical = (key) => key !== "armorBar" && clamp(status[key]) <= 20;
    const alert = () => (fuel() <= 15 ? "lowFuel" : vehicle.damage <= 30 ? "engineWarning" : vehicle.vehType === "LAND" && !indicators().seatbelt && vehicle.speed > 10 ? "belt" : "");
    const callback = async (event, value) => {
        if (inGame) return Nui.send(event, value);
        return "ok";
    };
    const synchronize = () => Promise.all([callback("unitChanged", { unit: prefs.Kmh }), callback("cinematicChanged", { enabled: prefs.cinematic }), callback("minimapSettingChanged", { changed: prefs.MinimapOnFoot })]);
    const serverDefaults = () => ({ ...defaults, ...config.Disable, Kmh: config.Default.Kmh ?? true });
    const closePanel = async () => {
        try {
            await callback("closePanel");
            setPanel(false);
            previousFocus?.focus();
        } catch {
            setNotice(t("failed"));
        }
    };
    const save = async () => {
        setBusy(true);
        try {
            await synchronize();
            localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
            saved = { ...prefs };
            setNotice(t("saved"));
        } catch {
            setNotice(t("failed"));
        } finally {
            setBusy(false);
        }
    };
    const reset = async () => {
        setPrefs(serverDefaults());
        await save();
    };
    function receive(event) {
        const { type, value } = event.data || {};
        if (type === "SHOW") setVisible(Boolean(value));
        if (type === "OPEN_SETTINGS") {
            previousFocus = document.activeElement;
            setPanel(true);
        }
        if (!value || typeof value !== "object") {
            if (type === "VOICE_RANGE") setHud("voice", "range", clamp(value, 1, 3));
            return;
        }
        if (type === "SET_CONFIG_DATA") {
            setConfig(value);
            setLocale(value.Locale || "en");
            setPrefs({ ...serverDefaults(), ...saved });
            synchronize().catch(() => setNotice(t("failed")));
        }
        if (type === "HUD_DATA") {
            setHud(value);
            setHudReady(true);
        }
        if (type === "VEH_HUD") {
            setVehicle(value);
            setVehicleReady(true);
        }
        if (type === "STATUS_HUD") {
            for (const [key] of statusItems) if (value[key] !== undefined) setStatus(key, clamp(value[key]));
            if (value.underwater !== undefined) setStatus("underwater", Boolean(value.underwater));
            setStatusReady(true);
        }
    }
    createEffect(() => {
        if (panel()) queueMicrotask(() => dialog?.querySelector("button")?.focus());
    });
    createEffect(() => {
        document.documentElement.lang = locale();
    });
    createEffect(() => {
        if (preview) setVehicle("kmh", prefs.Kmh);
    });
    createEffect(() => {
        const enabled = prefs.cinematic;
        if (inGame) callback("cinematicChanged", { enabled }).catch(() => setNotice(t("failed")));
    });
    onMount(() => {
        const resize = () => setViewportScale(Math.min(1.35, window.innerHeight / 1080, window.innerWidth / 1440));
        const keydown = (event) => {
            if (event.key === "Escape" && panel()) {
                event.preventDefault();
                closePanel();
            }
            if (event.key === "Tab" && panel()) {
                const focusable = [...dialog.querySelectorAll("button:not(:disabled), input:not(:disabled)")];
                const first = focusable[0],
                    last = focusable[focusable.length - 1];
                if (event.shiftKey && document.activeElement === first) {
                    event.preventDefault();
                    last.focus();
                } else if (!event.shiftKey && document.activeElement === last) {
                    event.preventDefault();
                    first.focus();
                }
            }
        };
        window.addEventListener("message", receive);
        window.addEventListener("resize", resize);
        window.addEventListener("keydown", keydown);
        resize();
        // Handshake resends config after CEF has mounted, including a resource restart.
        if (inGame) callback("ready").catch(() => {});
        const sounds = [indicatorSound, beltSound, beltOn, beltOff].map((src) => {
            const audio = new Audio(src);
            audio.volume = 0.25;
            return audio;
        });
        const play = (index) => {
            sounds[index].currentTime = 0;
            sounds[index].play().catch(() => {});
        };
        let lastAlert = 0,
            lastBelt = null;
        const soundTimer = setInterval(() => {
            if (!inGame || !moduleVisible() || hidden("Vehicle") || !vehicle.show) {
                lastBelt = null;
                return;
            }
            if (!hidden("IndicatorSound") && (indicators().leftIndex || indicators().rightIndex)) play(0);
            if (!hidden("IndicatorSeatbeltSound") && vehicle.vehType === "LAND") {
                if (lastBelt !== null && lastBelt !== indicators().seatbelt) play(indicators().seatbelt ? 2 : 3);
                if (!indicators().seatbelt && vehicle.speed > 10 && Date.now() - lastAlert > 6500) {
                    play(1);
                    lastAlert = Date.now();
                }
            }
            lastBelt = indicators().seatbelt;
        }, 650);
        onCleanup(() => {
            window.removeEventListener("message", receive);
            window.removeEventListener("resize", resize);
            window.removeEventListener("keydown", keydown);
            clearInterval(soundTimer);
            sounds.forEach((audio) => audio.pause());
        });
    });
    const Toggle = (props) => (
        <label class="setting-row">
            <span>
                <strong>{t(props.name)}</strong>
                <Show when={props.hint}>
                    <small>{t(props.hint)}</small>
                </Show>
            </span>
            <input type="checkbox" role="switch" disabled={locked(props.name)} checked={props.inverted ? !prefs[props.name] : prefs[props.name]} onChange={(e) => setPrefs(props.name, props.inverted ? !e.currentTarget.checked : e.currentTarget.checked)} />
        </label>
    );
    const Indicator = (props) => (
        <span classList={{ "vehicle-indicator": true, active: props.active, danger: props.danger }} title={t(props.label)} aria-label={`${t(props.label)}: ${props.active ? "on" : "off"}`}>
            <Icon name={props.icon} />
        </span>
    );
    return (
        <main classList={{ "hud-root": true, preview: preview, compact: prefs.compact, contrast: prefs.contrast, "reduced-motion": prefs.reducedMotion }} style={{ "--hud-scale": viewportScale() * prefs.scale, "--panel-opacity": prefs.opacity, "--brand": brand(), "--surface-rgb": channels(theme().backgroundColor) || "22, 22, 22", "--secondary": theme().secondaryColor || "#191919", "--mid": theme().accentColor || "#383838" }}>
            <Show when={preview}>
                <div class="preview-scene" aria-hidden="true">
                    <div class="scene-grid" />
                    <div class="scene-orbit" />
                </div>
                <div class="preview-toolbar">
                    <span class="preview-label">
                        <i />
                        {t("preview")}
                    </span>
                    <button
                        class="customize"
                        onClick={() => {
                            previousFocus = document.activeElement;
                            setPanel(true);
                        }}
                    >
                        <Icon name="settings" />
                        {t("customize")}
                    </button>
                </div>
            </Show>
            <Show when={moduleVisible()}>
                <Show when={hudReady()}>
                    <aside class="identity anchor" aria-label="Server and player">
                    <Show when={!hidden("Info")}>
                        <Show when={serverLogo()}>
                            <header class="brand-header">
                                <img
                                    class="server-logo"
                                    src={serverLogo()}
                                    alt={config.Default.ServerName || ""}
                                    onError={(event) => {
                                        if (event.currentTarget.getAttribute("src") !== defaultLogo) event.currentTarget.src = defaultLogo;
                                        else event.currentTarget.removeAttribute("src");
                                    }}
                                />
                            </header>
                        </Show>
                        <div class="session-line">
                            <span>
                                <i class="live-dot" />
                                {hud.onlinePlayers} {t("online")}
                            </span>
                            <span class="player-id">
                                ID <b>{hud.playerId}</b>
                            </span>
                            <Show when={hud.gameTime}>
                                <span>{hud.gameTime}</span>
                            </Show>
                        </div>
                    </Show>
                    <Show when={!hidden("Money")}>
                        <div class="wallet-panel">
                            <div role="group" aria-label={t("cash")}>
                                <Icon name="wallet" />
                                <strong>{money(hud.moneys.money)}</strong>
                            </div>
                            <div role="group" aria-label={t("bank")}>
                                <Icon name="bank" />
                                <strong class="bank-value">{money(hud.moneys.bank)}</strong>
                            </div>
                        </div>
                    </Show>
                    <Show when={!hidden("Info") && hud.job}>
                        <div class="job-line">
                            <Icon name="work" />
                            <span>{hud.job}</span>
                        </div>
                    </Show>
                    <Show when={!hidden("Weapon") && hud.weaponData.use}>
                        <div class="weapon-panel">
                            <Show when={weaponImages[`./assets/weapons/${hud.weaponData.image}.png`]}>
                                <img alt="" src={weaponImages[`./assets/weapons/${hud.weaponData.image}.png`]} />
                            </Show>
                            <div>
                                <span>{hud.weaponData.name}</span>
                                <Show when={!hud.weaponData.isWeaponMelee}>
                                    <strong>
                                        {hud.weaponData.currentAmmo}
                                        <small> / {hud.weaponData.maxAmmo}</small>
                                    </strong>
                                </Show>
                            </div>
                        </div>
                    </Show>
                    </aside>
                </Show>
                <div class="player-cluster anchor">
                    <Show when={statusReady() && !hidden("Status")}>
                        <section classList={{ "status-cluster": true, "above-map": prefs.CenterStatuses }} aria-label="Character status">
                            <For each={statusItems.filter(([key]) => showStatus(key))}>
                                {([key, icon, label]) => (
                                    <div classList={{ "status-cell": true, critical: critical(key) }} style={{ "--status-color": critical(key) ? "#ff6b6b" : config.Colors.Status?.[key] || statusColors[key] }} title={`${t(label)} ${Math.round(status[key])}%`}>
                                        <div class="status-glyph">
                                            <svg class="status-ring" viewBox="0 0 48 48">
                                                <rect x="3" y="3" width="42" height="42" rx="14" />
                                                <rect class="ring-value" x="3" y="3" width="42" height="42" rx="14" pathLength="100" stroke-dasharray={`${clamp(status[key])} 100`} />
                                            </svg>
                                            <Icon name={icon} />
                                        </div>
                                        <Show when={!prefs.StatusPercent}>
                                            <span>
                                                {Math.round(status[key])}
                                                <small>%</small>
                                            </span>
                                        </Show>
                                        <span class="sr-only">{t(label)}</span>
                                    </div>
                                )}
                            </For>
                        </section>
                    </Show>
                    <Show when={hudReady() && !hidden("Position")}>
                        <div class="location glass">
                            <span class="compass">{direction()}</span>
                            <div>
                                <strong>{hud.streetName}</strong>
                                <Show when={hud.zoneName}>
                                    <small>{hud.zoneName}</small>
                                </Show>
                            </div>
                            <Icon name="pin" />
                        </div>
                    </Show>
                </div>
                <Show when={hudReady() && !hidden("Voice")}>
                    <div classList={{ "voice-chip": true, anchor: true, glass: true, speaking: hud.voice.mic || hud.voice.radio }}>
                        <Icon name={hud.voice.radio ? "radio" : "mic"} />
                        <span>{hud.voice.radio ? t("radio") : t(["whisper", "normal", "shout"][range() - 1])}</span>
                        <div class="voice-bars">
                            <For each={[1, 2, 3]}>{(level) => <i classList={{ filled: level <= range() }} />}</For>
                        </div>
                        <Show when={hud.voice.mic}>
                            <i class="live-dot" />
                        </Show>
                    </div>
                </Show>
                <Show when={vehicleReady() && !hidden("Vehicle") && vehicle.show}>
                    <section class="telemetry anchor" aria-label="Vehicle telemetry">
                        <Show when={alert()}>
                            <div class="vehicle-alert" role="status">
                                <Icon name="warning" />
                                {t(alert())}
                            </div>
                        </Show>
                        <div class="speed-panel glass">
                            <div class="speed-top">
                                <span classList={{ turn: true, blinking: indicators().leftIndex }} role="img" aria-label="Left turn signal" aria-hidden={!indicators().leftIndex}>
                                    <Icon name="arrow" />
                                </span>
                                <span class="eyebrow">{indicators().leftIndex && indicators().rightIndex ? "HAZARDS" : indicators().leftIndex ? "LEFT TURN" : indicators().rightIndex ? "RIGHT TURN" : vehicle.vehType === "AIR" ? "FLIGHT" : vehicle.vehType === "BOAT" ? "MARINE" : "DRIVE"}</span>
                                <span classList={{ turn: true, right: true, blinking: indicators().rightIndex }} role="img" aria-label="Right turn signal" aria-hidden={!indicators().rightIndex}>
                                    <Icon name="arrow" />
                                </span>
                            </div>
                            <div class="speed-main">
                                <div class="speed-number">
                                    <span class="leading-zero">{Math.round(clamp(vehicle.speed, 0, 999)) < 100 ? "0" : ""}</span>
                                    {String(Math.round(clamp(vehicle.speed, 0, 999))).padStart(2, "0")}
                                    <small>{vehicle.kmh ? "KM/H" : "MPH"}</small>
                                </div>
                                <div class="gear">
                                    <strong>{vehicle.vehType === "AIR" ? Math.round(vehicle.rpm) : vehicle.gear === 0 ? (vehicle.speed > 1 ? t("reverse") : t("neutral")) : vehicle.gear}</strong>
                                    <span>{vehicle.vehType === "AIR" ? t("altitude") + " M" : t("gear")}</span>
                                </div>
                            </div>
                            <Show when={vehicle.vehType === "LAND" || vehicle.vehType === "MOTO"}>
                                <div class="rpm-track" aria-label="RPM">
                                    <For each={Array.from({ length: 30 }, (_, i) => i)}>{(i) => <i classList={{ lit: i < clamp((vehicle.rpm / 450) * 30, 0, 30), redline: i >= 25 }} />}</For>
                                </div>
                                <div class="rpm-label">
                                    <span>0</span>
                                    <span>RPM</span>
                                    <span>MAX</span>
                                </div>
                            </Show>
                            <div class="vehicle-stats">
                                <div classList={{ "fuel-stat": true, danger: fuel() <= 15 }}>
                                    <Icon name="fuel" />
                                    <strong>
                                        {Math.round(fuel())}
                                        <small>%</small>
                                    </strong>
                                    <div class="fuel-track">
                                        <i style={{ width: fuel() + "%" }} />
                                    </div>
                                </div>
                                <span class="odometer">
                                    {Number(vehicle.mileage || 0).toLocaleString("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}
                                    <small>{vehicle.kmh ? "km" : "mi"}</small>
                                </span>
                            </div>
                            <div class="vehicle-bottom">
                                <div class="indicator-group">
                                    <Show when={vehicle.vehType === "LAND"}>
                                        <Indicator icon="belt" label="beltLabel" active={indicators().seatbelt} danger={!indicators().seatbelt} />
                                    </Show>
                                    <Indicator icon="light" label="lights" active={indicators().light} />
                                    <Indicator icon="lock" label="locked" active={indicators().door} />
                                    <Indicator icon="cruise" label="cruise" active={indicators().tempomat} />
                                </div>
                                <div classList={{ "engine-health": true, danger: vehicle.damage <= 30 }}>
                                    <Icon name="engine" />
                                    {Math.round(clamp(vehicle.damage))}%
                                </div>
                            </div>
                        </div>
                    </section>
                </Show>
            </Show>
            <Show when={panel()}>
                <div class="settings-scrim">
                    <section ref={dialog} class="settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settings-title">
                        <header>
                            <div>
                                <span class="eyebrow">
                                    ESX <i /> PERSONAL HUD
                                </span>
                                <h2 id="settings-title">{t("settings")}</h2>
                                <p>{t("description")}</p>
                            </div>
                            <button class="close-button" aria-label={t("close")} onClick={closePanel}>
                                <Icon name="close" />
                                <kbd>ESC</kbd>
                            </button>
                        </header>
                        <div class="settings-layout">
                            <nav aria-label={t("customize")}>
                                <For each={["appearance", "modules", "driving"]}>
                                    {(name) => (
                                        <button classList={{ active: tab() === name }} onClick={() => setTab(name)}>
                                            <Icon name={name === "appearance" ? "settings" : name === "modules" ? "screen" : "cruise"} />
                                            {t(name)}
                                            <span>0{["appearance", "modules", "driving"].indexOf(name) + 1}</span>
                                        </button>
                                    )}
                                </For>
                                <div class="sidebar-note">
                                    <div class="palette">
                                        <i />
                                        <i />
                                        <i />
                                    </div>
                                    <strong>LEGACY ORIGINAL</strong>
                                    <p>{t("controls")}</p>
                                    <small>{brand().toUpperCase()}</small>
                                </div>
                            </nav>
                            <div class="settings-content">
                                <div class="section-title">
                                    <span>{t(tab())}</span>
                                    <small>
                                        <i class="live-dot" />
                                        {t("live")}
                                    </small>
                                </div>
                                <Show when={tab() === "appearance"}>
                                    <label class="range-row">
                                        <span>
                                            {t("scale")}
                                            <strong>{Math.round(prefs.scale * 100)}%</strong>
                                        </span>
                                        <input aria-label={t("scale")} type="range" min=".75" max="1.25" step=".05" value={prefs.scale} onInput={(e) => setPrefs("scale", Number(e.currentTarget.value))} />
                                    </label>
                                    <label class="range-row">
                                        <span>
                                            {t("opacity")}
                                            <strong>{Math.round(prefs.opacity * 100)}%</strong>
                                        </span>
                                        <input aria-label={t("opacity")} type="range" min=".65" max="1" step=".01" value={prefs.opacity} onInput={(e) => setPrefs("opacity", Number(e.currentTarget.value))} />
                                    </label>
                                    <For each={["compact", "contrast", "reducedMotion", "privacy", "cinematic"]}>{(name) => <Toggle name={name} />}</For>
                                </Show>
                                <Show when={tab() === "modules"}>
                                    <For each={["Status", "Vehicle", "Weapon", "Position", "Voice", "Money", "Info", "StatusPercent"]}>{(name) => <Toggle name={name} inverted />}</For>
                                    <Toggle name="smartStatus" hint="smartHint" />
                                    <Toggle name="CenterStatuses" />
                                </Show>
                                <Show when={tab() === "driving"}>
                                    <Toggle name="Kmh" />
                                    <For each={["MinimapOnFoot", "IndicatorSound", "IndicatorSeatbeltSound"]}>{(name) => <Toggle name={name} inverted />}</For>
                                    <div class="driving-note">
                                        <Icon name="cruise" />
                                        <p>{t("controls")}</p>
                                    </div>
                                </Show>
                            </div>
                        </div>
                        <footer>
                            <button class="reset-button" disabled={busy()} onClick={reset}>
                                {t("reset")}
                            </button>
                            <span role="status">{notice() || t("persisted")}</span>
                            <button class="save-button" disabled={busy()} onClick={save}>
                                <Icon name="check" />
                                {t("save")}
                            </button>
                        </footer>
                    </section>
                </div>
            </Show>
        </main>
    );
}

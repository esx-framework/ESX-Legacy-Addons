// Turns a raw log row into a sentence a head admin can skim.
// Every logged action has its own phrasing, built from the exact payload keys
// the server handlers actually read, instead of dumping JSON on screen.

import type { AdminLog } from "./types/log";

export type LogCategory = "moderation" | "economy" | "player" | "server" | "other";

export const CATEGORY_LABELS: Record<LogCategory, string> = {
	moderation: "Moderation",
	economy: "Economy",
	player: "Player",
	server: "Server",
	other: "Other",
};

type Payload = Record<string, unknown>;
type Builder = (payload: Payload, target: string) => string;

const nf = new Intl.NumberFormat("de-DE");

const money = (value: unknown) => `$${nf.format(Number(value) || 0)}`;
const num = (value: unknown) => String(Math.round(Number(value) || 0));

const text = (value: unknown, fallback = "") => {
	const str = typeof value === "string" ? value.trim() : "";
	return str === "" ? fallback : str;
};

/** Payloads arrive from the NUI, so a boolean may be a real bool, "true" or 1. */
const bool = (value: unknown) => value === true || value === "true" || value === 1 || value === "1";

const account = (value: unknown) => {
	const name = text(value, "money");
	if (name === "bank") return "bank";
	if (name === "black_money") return "dirty money";
	return "cash";
};

function duration(minutes: unknown) {
	const value = Number(minutes) || 0;
	if (value <= 0) return "permanently";
	if (value < 60) return `for ${value} min`;
	if (value < 1440) return `for ${Math.round(value / 60)} h`;
	return `for ${Math.round(value / 1440)} days`;
}

/** Appended only when a reason was actually given. */
const because = (p: Payload) => {
	const reason = text(p.reason);
	return reason === "" ? "" : ` — ${reason}`;
};

const ACTIONS: Record<string, { category: LogCategory; build: Builder }> = {
	// ------------------------------------------------------------ moderation
	ban: {
		category: "moderation",
		build: (p, t) => `banned ${t} ${duration(p.duration_minutes)}${because(p)}`,
	},
	banOffline: {
		category: "moderation",
		build: (p, t) => `banned ${t} while they were offline, ${duration(p.duration_minutes)}${because(p)}`,
	},
	unban: { category: "moderation", build: (_p, t) => `lifted the ban on ${t}` },
	banChangeExpiry: { category: "moderation", build: (_p, t) => `changed how long ${t} stays banned` },
	kick: { category: "moderation", build: (p, t) => `kicked ${t}${because(p)}` },

	killPlayer: { category: "moderation", build: (_p, t) => `killed ${t}` },
	revivePlayer: { category: "moderation", build: (_p, t) => `revived ${t}` },
	// One toggle action for both directions, so the verb comes from the payload.
	freezePlayer: {
		category: "moderation",
		build: (p, t) => (bool(p.enabled) ? `froze ${t}` : `unfroze ${t}`),
	},
	cleanInventory: { category: "moderation", build: (_p, t) => `wiped the inventory of ${t}` },
	deleteCharacter: {
		category: "moderation",
		build: (p, t) => `deleted the character of ${t === "a player" ? text(p.identifier, t) : t}`,
	},
	// The server reads payload.group and falls back to payload.permission.
	aceAdd: {
		category: "moderation",
		build: (p, t) => `granted the "${text(p.group, text(p.permission, "unknown"))}" ACE group to ${t}`,
	},
	aceRemove: {
		category: "moderation",
		build: (p, t) => `revoked the "${text(p.group, text(p.permission, "unknown"))}" ACE group from ${t}`,
	},

	// --------------------------------------------------------------- economy
	giveMoney: { category: "economy", build: (p, t) => `gave ${money(p.amount)} to ${t} (${account(p.account)})` },
	takeMoney: { category: "economy", build: (p, t) => `took ${money(p.amount)} from ${t} (${account(p.account)})` },
	giveMoneyAll: { category: "economy", build: (p) => `gave ${money(p.amount)} to every player (${account(p.account)})` },

	// ---------------------------------------------------------------- player
	setHealth: { category: "player", build: (p, t) => `set the health of ${t} to ${num(p.amount)}%` },
	setArmor: { category: "player", build: (p, t) => `set the armor of ${t} to ${num(p.amount)}%` },
	setThirst: { category: "player", build: (p, t) => `set the thirst of ${t} to ${num(p.amount)}%` },
	setHunger: { category: "player", build: (p, t) => `set the hunger of ${t} to ${num(p.amount)}%` },
	setModel: { category: "player", build: (p, t) => `changed ${t} into "${text(p.model, "another model")}"` },
	setJob: { category: "player", build: (p, t) => `made ${t} ${text(p.job, "unemployed")} (grade ${num(p.grade)})` },
	setName: {
		category: "player",
		build: (p, t) => {
			const full = `${text(p.firstName)} ${text(p.lastName)}`.trim();
			return full === "" ? `renamed ${t}` : `renamed ${t} to ${full}`;
		},
	},
	setRadio: {
		category: "player",
		build: (p, t) => {
			const channel = Number(p.channel) || 0;
			return channel <= 0 ? `took ${t} off the radio` : `put ${t} on radio channel ${channel}`;
		},
	},
	setRoutingBucket: { category: "player", build: (p, t) => `moved ${t} to routing bucket ${num(p.bucket)}` },
	openClothing: { category: "player", build: (_p, t) => `opened the clothing menu of ${t}` },
	giveAllWeapons: { category: "player", build: (_p, t) => `gave every weapon to ${t}` },
	troll: { category: "player", build: (p, t) => `used the "${text(p.trollAction, "unknown")}" troll on ${t}` },

	// ---------------------------------------------------------------- server
	weather: { category: "server", build: (p) => `set the weather to ${text(p.weather, "default")}` },
	time: {
		category: "server",
		build: (p) => `set the time to ${num(p.hour).padStart(2, "0")}:${num(p.minute).padStart(2, "0")}`,
	},
	blackout: { category: "server", build: (p) => (bool(p.enabled) ? "turned the blackout on" : "turned the blackout off") },
	pvp: { category: "server", build: (p) => (bool(p.enabled) ? "enabled PvP" : "disabled PvP") },
	freezeAll: { category: "server", build: () => "froze every player" },
	unfreezeAll: { category: "server", build: () => "unfroze every player" },
	bringAll: { category: "server", build: () => "teleported every player to them" },
	reviveAll: { category: "server", build: () => "revived every player" },
	killAll: { category: "server", build: () => "killed every player" },
	kickAll: { category: "server", build: (p) => `kicked every player${because(p)}` },
	deleteVehicles: { category: "server", build: () => "deleted every vehicle on the map" },
	deletePeds: { category: "server", build: () => "deleted every ped on the map" },
	deleteObjects: { category: "server", build: () => "deleted every object on the map" },
	notifyAll: {
		category: "server",
		build: (p) => `broadcast a notification: "${text(p.message, text(p.title, "no content"))}"`,
	},
};

/** "giveMoney" -> "give money", so an action added later still reads acceptably. */
function humanize(key: string) {
	const spaced = key.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ");
	return spaced.charAt(0).toLowerCase() + spaced.slice(1);
}

function fallbackCategory(namespace: string): LogCategory {
	if (namespace === "moderation") return "moderation";
	if (namespace === "serverManagement") return "server";
	if (namespace === "playerActions") return "player";
	return "other";
}

function parsePayload(raw?: string | null): Payload {
	if (!raw) return {};

	try {
		const parsed = JSON.parse(raw) as unknown;
		return parsed && typeof parsed === "object" ? (parsed as Payload) : {};
	} catch {
		return {};
	}
}

export function describeLog(log: AdminLog): { message: string; category: LogCategory } {
	const payload = parsePayload(log.payload);
	const target = log.target_name || log.target_identifier || "a player";
	const known = ACTIONS[log.action];

	if (!known) {
		const hasTarget = Boolean(log.target_identifier || log.target_name);
		return {
			message: hasTarget ? `${humanize(log.action)} on ${target}` : humanize(log.action),
			category: fallbackCategory(log.namespace),
		};
	}

	let message: string;
	try {
		message = known.build(payload, target);
	} catch {
		message = humanize(log.action);
	}

	// The server swaps oversized payloads for a marker, so say so plainly rather
	// than letting the sentence silently lose its details.
	if (payload._truncated) {
		message += " (details were too large to store)";
	}

	return { message, category: known.category };
}

export type LogDetail = { label: string; value: string; mono?: boolean };

const DETAIL_LABELS: Record<string, string> = {
	amount: "Amount",
	account: "Account",
	reason: "Reason",
	duration_minutes: "Duration",
	identifiers: "Identifiers captured",
	enabled: "Enabled",
	model: "Model",
	job: "Job",
	grade: "Grade",
	firstName: "First name",
	lastName: "Last name",
	channel: "Radio channel",
	bucket: "Routing bucket",
	group: "ACE group",
	permission: "Permission",
	trollAction: "Troll action",
	weather: "Weather",
	hour: "Hour",
	minute: "Minute",
	message: "Message",
	title: "Title",
	notificationType: "Type",
	duration: "Duration (ms)",
	identifier: "Identifier",
	expires_at: "Expires at",
};

/** Everything the row hides, shown on demand behind the details button. */
export function buildDetails(log: AdminLog): LogDetail[] {
	const details: LogDetail[] = [];

	details.push({ label: "Action", value: `${log.namespace} / ${log.action}`, mono: true });
	details.push({ label: "Admin", value: log.actor_identifier || "unknown", mono: true });

	if (log.target_identifier) {
		details.push({ label: "Target", value: log.target_identifier, mono: true });
	}

	// The error is deliberately not repeated here: it already appears in full on
	// the row itself, in the red chip next to the timestamp.

	const payload = parsePayload(log.payload);

	for (const [key, value] of Object.entries(payload)) {
		if (key === "_truncated" || value === null || value === undefined || value === "") continue;

		let shown: string;

		if (key === "duration_minutes") {
			shown = duration(value).replace(/^for /, "");
		} else if (typeof value === "boolean") {
			shown = value ? "yes" : "no";
		} else if (typeof value === "object") {
			shown = JSON.stringify(value);
		} else {
			shown = String(value);
		}

		details.push({ label: DETAIL_LABELS[key] ?? humanize(key), value: shown });
	}

	if (payload._truncated) {
		details.push({ label: "Payload", value: "Too large to store, it was dropped" });
	}

	return details;
}

/** "3 min ago" reads better than a timestamp for recent activity. */
export function relativeTime(ms: number | null): string {
	if (ms === null) return "";

	const diff = Date.now() - ms;
	if (diff < 60_000) return "just now";

	const minutes = Math.floor(diff / 60_000);
	if (minutes < 60) return `${minutes} min ago`;

	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours} h ago`;

	const days = Math.floor(hours / 24);
	if (days < 7) return `${days} d ago`;

	return new Date(ms).toLocaleDateString(undefined, { day: "2-digit", month: "short" });
}

/** Full timestamp, shown in the details panel where precision matters. */
export function absoluteTime(ms: number | null): string {
	if (ms === null) return "unknown";

	return new Date(ms).toLocaleString(undefined, {
		year: "numeric",
		month: "short",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
	});
}

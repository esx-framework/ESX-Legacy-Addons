import { t } from "$lib/shared/util/util";
import type { Vector3 } from "../../tabs/players/types/player";
import type { PlayTime } from "../../tabs/players/types/player";

const nf = new Intl.NumberFormat("de-DE");
export const formatMoney = (n: number = 0) => nf.format(n);

export function formatLastVisited(timestamp?: number | null, neverText?: string | null) {
	if (!timestamp) return neverText ?? "Never";

	const date = new Date(timestamp);

	return date.toLocaleString(undefined, {
		year: "numeric",
		month: "short",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
	});
}

export function formatPlayTime(pt: PlayTime) {
	return `${pt.days}d ${pt.hours}h ${pt.minutes}m`;
}

export function formatDuration(totalSeconds: number) {
	const seconds = Math.max(0, Math.floor(totalSeconds));
	const days = Math.floor(seconds / 86400);
	const hours = Math.floor((seconds % 86400) / 3600);
	const minutes = Math.floor((seconds % 3600) / 60);

	if (days > 0) return `${days}d ${hours}h ${minutes}m`;
	if (hours > 0) return `${hours}h ${minutes}m`;
	if (minutes > 0) return `${minutes}m`;

	return "<1m";
}

export function formatPosition(position?: Vector3) {
	if (!position) return "Unknown";

	return `X: ${position.x.toFixed(2)}  Y: ${position.y.toFixed(2)}  Z: ${position.z.toFixed(2)}`;
}

export function formatName(name: string, max = 24) {
	if (name.length <= max) return name;
	return name.slice(0, max - 3) + "...";
}

export function getTimestampMs(timestamp?: number | string | null) {
	if (timestamp === null || timestamp === undefined || timestamp === "") return null;

	if (typeof timestamp === "number") {
		if (timestamp <= 0) return null;
		return timestamp < 1_000_000_000_000 ? timestamp * 1000 : timestamp;
	}

	const trimmed = timestamp.trim();
	if (trimmed === "" || trimmed.startsWith("0000-00-00")) return null;

	const numeric = Number(trimmed);
	if (Number.isFinite(numeric)) return getTimestampMs(numeric);

	const parsed = Date.parse(trimmed.includes("T") ? trimmed : trimmed.replace(" ", "T"));
	return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export function formatDate(timestamp?: number | string | null, emptyText = t("permanent")) {
	const timestampMs = getTimestampMs(timestamp);
	if (timestampMs === null) return emptyText;

	const d = new Date(timestampMs);

	const day = String(d.getDate()).padStart(2, "0");
	const month = String(d.getMonth() + 1).padStart(2, "0");
	const year = d.getFullYear();

	return `${day}/${month}/${year}`;
}

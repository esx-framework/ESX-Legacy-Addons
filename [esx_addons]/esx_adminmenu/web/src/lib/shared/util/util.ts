import { translations } from "$lib/shared/stores/translations.svelte";

type NuiWindow = Window & {
	invokeNative?: unknown;
};

export const isChromium = (): boolean => typeof (window as NuiWindow).invokeNative === "function";

export const t = (key: string | null | undefined, fallback?: string): string => {
	if (!key) return fallback ?? "";

	return translations.values[key] ?? fallback ?? key;
};

export const copyToClipboardChromium = (text: string, timeout = 50): void => {
	if (!document.body) return;

	const textarea = document.createElement("textarea");
	textarea.value = text;

	textarea.style.position = "fixed";
	textarea.style.top = "-9999px";
	textarea.style.left = "-9999px";
	textarea.setAttribute("readonly", "");

	document.body.appendChild(textarea);

	textarea.focus();
	textarea.select();
	textarea.setSelectionRange(0, textarea.value.length);

	try {
		document.execCommand("copy");
	} catch (err) {
		console.error("Clipboard fallback failed:", err);
	}

	setTimeout(() => {
		if (textarea.parentNode) {
			textarea.parentNode.removeChild(textarea);
		}
	}, timeout);
};

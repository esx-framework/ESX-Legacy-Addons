import { isChromium } from "../util/util";
import { notifications } from "../stores/notifications.svelte";

type NuiErrorResponse = {
	success?: boolean;
	err?: string;
	error?: string;
	message?: string;
};

function getErrorMessage(payload: NuiErrorResponse) {
	return payload.err ?? payload.error ?? payload.message ?? "Action failed.";
}

export async function fetchNui<T = unknown>(event: string, data: unknown = {}): Promise<T | null> {
	try {
		if (!isChromium()) return null;

		const res = await fetch(`https://${GetParentResourceName()}/${event}`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json; charset=UTF-8",
			},
			body: JSON.stringify(data),
		});

		if (!res.ok) {
			throw new Error(`[esx-adminmenu:NUI:${event}] Fetch failed: ${res.status}`);
		}

		const payload = (await res.json()) as T;

		if (payload && typeof payload === "object" && "success" in payload && (payload as NuiErrorResponse).success === false) {
			notifications.error(getErrorMessage(payload as NuiErrorResponse));
		}

		return payload;
	} catch (err) {
		console.error(`[esx-adminmenu:NUI:${event}]`, err);
		notifications.error("The admin UI could not reach the client callback.");
		return null;
	}
}

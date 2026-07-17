import { listenNui } from "./receiveNUI";
import type { ServerState } from "../types/server";
import { server } from "../stores/server.svelte";
import type { Translations } from "../stores/translations.svelte";
import { translations } from "../stores/translations.svelte";
import { uiState } from "../stores/user.svelte";
import type { VehicleSpawnerConfig } from "../stores/user.svelte";
import { currentPage } from "../stores/navigation.svelte";
import { stopSpectate } from "./admin";
import { copyToClipboardChromium } from "../util/util";
import type { Player } from "../../tabs/players/types/player";
import type { Impound } from "../types/impounds";

type NuiMessage =
	| { action: "initResource"; data: { translations: Translations; serverData: ServerState; impounds: Record<string, Impound>; vehicleConfig?: VehicleSpawnerConfig } }
	| { action: "openAdmin"; data: Player[] }
	| { action: "openAdminDashboard"; data: { players: Player[]; serverData?: ServerState; selectedPlayerId?: number } }
	| { action: "openAdminMenu"; data?: { serverData?: ServerState } }
	| { action: "updateServerData"; data: ServerState }
	| { action: "adminMenuState"; data: { action: string; active: boolean; value?: string } }
	| { action: "updatePlayers"; data: Player[] }
	| { action: "stopSpectate"; data: boolean }
	| { action: "closeAdmin" }
	| { action: "copyToClipboard"; data: string };

listenNui<NuiMessage>((msg) => {
	switch (msg.action) {
		case "initResource":
			if (!msg.data) return;

			server.set(msg.data.serverData);

			if (msg.data.translations && Object.keys(msg.data.translations).length > 0) {
				translations.set(msg.data.translations);
			}

			uiState.setImpounds(msg.data.impounds ?? {});
			uiState.setVehicleConfig(msg.data.vehicleConfig);
			break;

		case "openAdmin":
			if (!msg.data) return null;
			uiState.openDashboard(msg.data);
			break;

		case "openAdminDashboard":
			if (!msg.data) return null;
			if (msg.data.serverData) {
				server.set(msg.data.serverData);
			}
			uiState.openDashboard(msg.data.players ?? [], msg.data.selectedPlayerId ?? null);
			if (msg.data.selectedPlayerId !== undefined) {
				currentPage.set("ply_management");
			}
			break;

		case "openAdminMenu":
			if (msg.data?.serverData) {
				server.set(msg.data.serverData);
			}
			uiState.openMenu();
			break;

		case "updateServerData":
			if (!msg.data) return null;
			server.set(msg.data);
			break;

		case "adminMenuState":
			if (!msg.data) return null;
			uiState.setAdminMenuState(msg.data.action, msg.data.active);
			uiState.setAdminMenuBadge(msg.data.action, msg.data.value);
			break;

		case "updatePlayers":
			if (!msg.data) return null;
			uiState.setPlayers(msg.data);
			break;
		case "stopSpectate":
			if (!msg.data) return null;
			stopSpectate(msg.data);
			break;

		case "closeAdmin":
			uiState.close();
			break;

		case "copyToClipboard":
			if (!msg.data) return null;
			copyToClipboardChromium(msg.data);
			break;
	}
});

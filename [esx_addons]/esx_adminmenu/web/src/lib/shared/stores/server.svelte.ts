import type { ServerEnvironmentState, ServerState } from "../types/server";

const initialState: ServerState = {
	currentPlayers: 0,
	maxPlayers: 0,
	uptimeSeconds: 0,
	uptimeFormatted: "00:00:00",
	environment: {
		weather: "CLEAR",
		hour: 12,
		minute: 0,
		blackout: false,
		pvp: true,
	},
};

export class ServerStore {
	currentPlayers = $state(initialState.currentPlayers);
	maxPlayers = $state(initialState.maxPlayers);
	uptimeSeconds = $state(initialState.uptimeSeconds);
	uptimeFormatted = $state(initialState.uptimeFormatted);
	weather = $state(initialState.environment?.weather ?? "CLEAR");
	hour = $state(initialState.environment?.hour ?? 12);
	minute = $state(initialState.environment?.minute ?? 0);
	blackout = $state(initialState.environment?.blackout ?? false);
	pvp = $state(initialState.environment?.pvp ?? true);

	set(state: ServerState) {
		this.currentPlayers = state.currentPlayers;
		this.maxPlayers = state.maxPlayers;
		this.uptimeSeconds = state.uptimeSeconds ?? 0;
		this.uptimeFormatted = state.uptimeFormatted ?? initialState.uptimeFormatted;
		this.setEnvironment(state.environment);
	}

	setEnvironment(environment?: Partial<ServerEnvironmentState> | null) {
		if (!environment) return;

		this.weather = environment.weather ?? this.weather;
		this.hour = environment.hour ?? this.hour;
		this.minute = environment.minute ?? this.minute;
		this.blackout = environment.blackout ?? this.blackout;
		this.pvp = environment.pvp ?? this.pvp;
	}
}

export const server = new ServerStore();

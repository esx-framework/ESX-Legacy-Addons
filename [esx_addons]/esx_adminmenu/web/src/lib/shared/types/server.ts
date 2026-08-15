export interface ServerEnvironmentState {
  weather: string;
  hour: number;
  minute: number;
  blackout: boolean;
  pvp: boolean;
}

export interface ServerState {
  currentPlayers: number;
  maxPlayers: number;
  uptimeSeconds: number;
  uptimeFormatted: string;
  environment?: Partial<ServerEnvironmentState>;
}

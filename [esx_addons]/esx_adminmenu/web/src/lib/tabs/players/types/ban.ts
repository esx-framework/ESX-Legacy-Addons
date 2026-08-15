export interface Ban {
	id?: number;
	identifier: string;
	reason: string;
	banned_by?: string;

	banned_at?: number | string | null;
	expires_at?: number | string | null;
	remaining_seconds?: number | null;
	remaining_formatted?: string | null;
}

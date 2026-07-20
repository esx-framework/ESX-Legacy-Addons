export interface AdminLog {
	id: number;
	created_at: string | number | null;

	actor_identifier: string;
	actor_name?: string | null;

	namespace: string;
	action: string;

	target_identifier?: string | null;
	target_name?: string | null;

	// Stored as TINYINT server-side, so it arrives as 0 or 1.
	success: number | boolean;
	error?: string | null;

	// JSON string, already redacted and size-capped by the server.
	payload?: string | null;
}

export interface AdminLogFilters {
	/** Free text, matched server-side against admin, target and action. */
	search?: string;
	actor?: string;
	target?: string;
	action?: string;
	namespace?: string;
	days?: number;
	limit?: number;
	offset?: number;
}

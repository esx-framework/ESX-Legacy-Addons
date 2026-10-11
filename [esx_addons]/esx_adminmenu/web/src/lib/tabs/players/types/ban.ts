/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

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

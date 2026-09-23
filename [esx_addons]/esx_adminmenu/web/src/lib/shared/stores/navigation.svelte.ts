/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

export class CurrentPageStore {
	value = $state("dashboard_home");

	set(value: string) {
		this.value = value;
	}
}

export const currentPage = new CurrentPageStore();

/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

export interface Vector3 {
	x: number;
	y: number;
	z: number;
}

export interface SpawnPoint extends Vector3 {
	heading?: number;
	w?: number;
}

export interface Impound {
	id?: string;
	label?: string;
	getOutPoint?: Vector3;
	spawnPoint?: SpawnPoint;
	spawns?: SpawnPoint[];
	sprite?: number;
	scale?: number;
	colour?: number;
	cost?: number;
}

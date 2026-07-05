export interface Vector3 {
	x: number;
	y: number;
	z: number;
}

export interface SpawnPoint extends Vector3 {
	heading: number;
}

export interface Impound {
	getOutPoint: Vector3;
	spawnPoint: SpawnPoint;
	sprite?: number;
	scale?: number;
	colour?: number;
	cost?: number;
}

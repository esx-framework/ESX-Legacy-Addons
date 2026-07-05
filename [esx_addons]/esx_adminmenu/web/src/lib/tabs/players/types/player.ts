export interface Vector3 {
	x: number;
	y: number;
	z: number;
}

export interface PlayTime {
	days: number;
	hours: number;
	minutes: number;
}

type Status = "online" | "offline";
export interface Player {
	status: Status; // 'online' | 'offline'
	id?: number | string; // server ID, or "OFF" for offline search results
	_key?: string;
	name: string;
	is_staff?: boolean;
	group?: string;

	cash: number;
	bank: number;
	alt_money: number; // Black Money / Illegal Money

	health?: number;
	armor?: number;

	last_join?: number | null; // timestamp

	char_identifier?: string | null;
	identifier?: string | null;
	ip?: string;
	identifiers?: Record<string, string>;
	routing_bucket?: number;
	radio_channel?: number;
	job?: string;
	job_grade?: string;
	gender: "m" | "f" | string;

	play_time?: PlayTime;
	position?: Vector3;
}

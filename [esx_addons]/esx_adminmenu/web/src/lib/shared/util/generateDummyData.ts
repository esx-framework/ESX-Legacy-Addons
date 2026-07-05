import type { Ban } from "../../tabs/players/types/ban";
import type { Player } from "../../tabs/players/types/player";
import type { Vehicle } from "../../tabs/players/types/vehicle";

const names = ["John Doe", "Jane Doe", "Ryan Reynolds", "John Wick", "Michael Scott", "Walter White", "Tony Stark", "Bruce Wayne", "Arthur Morgan", "Geralt of Rivia", "Tom Shelby", "Joel Miller"];

const banReasons = ["Cheating", "Exploiting", "RDM", "VDM", "Toxic behavior", "Mass rule violation", "Ban evasion", "Unauthorized modifications", "Abuse of bugs"];

const adminNames = ["Orbit", "System", "Console", "AntiCheat", "Moderator01", "SeniorAdmin"];

const vehicleNames = [
	{ name: "Sultan RS", type: "sports" },
	{ name: "Elegy Retro", type: "sports" },
	{ name: "Baller", type: "suv" },
	{ name: "Granger", type: "suv" },
	{ name: "Buffalo STX", type: "muscle" },
	{ name: "Dominator", type: "muscle" },
	{ name: "Futo GTX", type: "compact" },
	{ name: "T20", type: "super" },
	{ name: "Kuruma", type: "sedan" },
	{ name: "Sandking XL", type: "offroad" },
];

function generatePlate(): string {
	const letters = () => String.fromCharCode(65 + Math.floor(Math.random() * 26));
	const numbers = () => Math.floor(Math.random() * 10);

	return `${letters()}${letters()}${letters()}-${numbers()}${numbers()}${numbers()}`;
}

export function generateDummyPlayers(count: number): Player[] {
	return Array.from({ length: count }, (_, i) => {
		const name = names[i % names.length];
		const status: Player["status"] = Math.random() > 0.5 ? "online" : "offline";

		const basePlayer = {
			name,
			status,

			cash: Math.floor(Math.random() * 10_000),
			bank: Math.floor(Math.random() * 1_000_000),
			alt_money: Math.floor(Math.random() * 500_000),

			last_join: Date.now() - Math.floor(Math.random() * 1000 * 60 * 60 * 24 * 30),

			char_identifier: `char1:${Math.random().toString(16).slice(2)}`,
			identifier: `license:${Math.random().toString(16).slice(2)}`,

			job: "Unemployed",
			job_grade: "Unknown",
			gender: Math.random() > 0.5 ? "m" : "f",

			play_time: {
				days: Math.floor(Math.random() * 30),
				hours: Math.floor(Math.random() * 24),
				minutes: Math.floor(Math.random() * 60),
			},

			position: {
				x: Math.random() * 4000 - 2000,
				y: Math.random() * 4000 - 2000,
				z: Math.random() * 100,
			},
		};

		if (status === "offline") {
			return basePlayer as Player;
		}

		// online-only fields
		return {
			...basePlayer,
			id: i + 1,
			health: Math.floor(Math.random() * 100),
			armor: Math.floor(Math.random() * 100),
		} as Player;
	});
}

export function generateDummyBans(count: number): Ban[] {
	return Array.from({ length: count }, (_, i) => {
		const now = Date.now();

		const permanent = Math.random() > 0.7;
		const durationDays = Math.floor(Math.random() * 30) + 1;

		const bannedAt = Math.max(1, now - Math.floor(Math.random() * 1000 * 60 * 60 * 24 * 60));

		return {
			id: i + 1,

			identifier: `license:${Math.random().toString(16).slice(2)}`,

			reason: banReasons[Math.floor(Math.random() * banReasons.length)],

			banned_by: adminNames[Math.floor(Math.random() * adminNames.length)],

			banned_at: bannedAt,

			expires_at: permanent ? null : bannedAt + durationDays * 24 * 60 * 60 * 1000,

			permanent,
		};
	});
}

export function generateDummyVehicles(count: number): Vehicle[] {
	return Array.from({ length: count }, () => {
		const vehicle = vehicleNames[Math.floor(Math.random() * vehicleNames.length)];

		const hasOwner = Math.random() > 0.2;
		const impounded = Math.random() > 0.8;

		return {
			owner: hasOwner ? `license:${Math.random().toString(16).slice(2)}` : undefined,

			plate: generatePlate(),

			type: vehicle.type,
			name: vehicle.name,

			mileage: Math.random() > 0.1 ? Math.floor(Math.random() * 200_000) : null,
			impounded,
		};
	});
}

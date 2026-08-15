<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./PlayerManagement.css";
	import { uiState } from "../../shared/stores/user.svelte";
	import type { Vehicle } from "./types/vehicle";
	import { fetchVehiclePage } from "../../shared/nui/admin";
	import VehiclesList from "./components/VehiclesList.svelte";

	let search = $state("");

	type SortKey = "plate" | "owner" | "type" | "name" | "mileage" | "impounded";

	let sortKey = $state<SortKey>("plate");
	let sortAsc = $state(true);

	function setSort(key: SortKey) {
		if (sortKey === key) {
			sortAsc = !sortAsc;
		} else {
			sortKey = key;
			sortAsc = true;
		}
	}

	const filteredVehicles = $derived.by<Vehicle[]>(() => {
		const q = search.trim().toLowerCase();
		const list = uiState.vehicles;
		if (!list) return [];

		return list
			.filter((v) => {
				if (q === "") return true;

				return v.plate.toLowerCase().includes(q) || v.name.toLowerCase().includes(q) || v.type.toLowerCase().includes(q) || (v.owner?.toLowerCase().includes(q) ?? false);
			})
			.slice()
			.sort((a, b) => {
				const v1 = a[sortKey];
				const v2 = b[sortKey];

				if (typeof v1 === "string" && typeof v2 === "string") {
					return sortAsc ? v1.localeCompare(v2) : v2.localeCompare(v1);
				}

				if (typeof v1 === "boolean" && typeof v2 === "boolean") {
					return sortAsc ? Number(v1) - Number(v2) : Number(v2) - Number(v1);
				}

				const n1 = Number(v1 ?? 0);
				const n2 = Number(v2 ?? 0);

				return sortAsc ? n1 - n2 : n2 - n1;
			});
	});

	async function loadMoreVehicles() {
		await fetchVehiclePage({ search: search.trim() });
	}

	$effect(() => {
		const query = search.trim();
		const timer = window.setTimeout(() => {
			void fetchVehiclePage({ reset: true, search: query });
		}, 250);

		return () => {
			window.clearTimeout(timer);
		};
	});
</script>

<div class="top-bar">
	<span class="players-title" tabindex="-1">
		{t("vehicles_list")}
	</span>

	<div class="player-search-bar-container" tabindex="-1">
		<svg class="player-search-icon" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
			<path
				d="M10.8746 10.852L14 14M12.5556 6.77778C12.5556 9.96877 9.96877 12.5556 6.77778 12.5556C3.5868 12.5556 1 9.96877 1 6.77778C1 3.5868 3.5868 1 6.77778 1C9.96877 1 12.5556 3.5868 12.5556 6.77778Z"
				stroke="#F2F2F2"
				stroke-width="2"
				stroke-linecap="round"
				stroke-linejoin="round"
			/>
		</svg>

		<input placeholder={t("search_vehicle")} type="text" bind:value={search} tabindex="-1" class="player-search-bar" />
	</div>
</div>

<div class="table-header">
	<button type="button" tabindex="-1" onclick={() => setSort("plate")}>
		{t("plate")}
	</button>

	<button type="button" tabindex="-1" onclick={() => setSort("owner")}>
		{t("owner")}
	</button>

	<button type="button" tabindex="-1" onclick={() => setSort("name")}>
		{t("vehicle_name")}
	</button>

	<button type="button" tabindex="-1" onclick={() => setSort("type")}>
		{t("vehicle_type")}
	</button>

	<button type="button" tabindex="-1" onclick={() => setSort("mileage")}>
		{t("mileage")}
	</button>

	<button type="button" tabindex="-1" onclick={() => setSort("impounded")}>
		{t("impounded")}
	</button>
</div>

<div class="list-wrapper">
	<VehiclesList {filteredVehicles} loading={uiState.vehicleLoading} hasMore={uiState.vehicleHasMore} onNeedMore={loadMoreVehicles} />
</div>

<style>
	.table-header {
		display: grid;
		grid-template-columns: 1fr 1.2fr 1.5fr 1fr 1fr 0.7fr;
		padding: 0.8vh 1.3vh;
		font-family: "Poppins";
		font-size: 1.3vh;
		font-weight: 500;
	}

	.table-header button {
		all: unset;
		display: flex;
		align-items: center;
		justify-content: start;
		font-family: "Poppins";
		font-size: 1.3vh;
		font-weight: 500;
		color: #f2f2f2;
		cursor: pointer;
		user-select: none;
		min-width: 0;
		max-width: 90%;
		word-break: break-word;
		white-space: normal;
	}

	.table-header button:hover {
		color: #fb9b04;
	}
</style>

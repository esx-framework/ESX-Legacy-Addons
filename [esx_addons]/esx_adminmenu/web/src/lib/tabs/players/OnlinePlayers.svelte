<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./PlayerManagement.css";
	import { uiState } from "../../shared/stores/user.svelte";
	import type { Player } from "./types/player";
	import PlayersList from "./components/PlayersList.svelte";

	let search = $state("");

	type SortKey = "id" | "name" | "cash" | "bank" | "alt_money" | "last_join";

	let sortKey = $state<SortKey>("id");
	let sortAsc = $state(true);

	function setSort(key: SortKey) {
		if (sortKey === key) {
			sortAsc = !sortAsc;
		} else {
			sortKey = key;
			sortAsc = true;
		}
	}

	// Filters players depending on the sortKey variable.
	const filteredPlayers = $derived.by<Player[]>(() => {
		const q = search.trim().toLowerCase();
		if (!uiState.players) return [];

		return uiState.players
			.filter((p) => p.status === "online")
			.filter((p) => (q === "" ? true : p.name.toLowerCase().includes(q) || String(p.id).includes(q)))
			.slice()
			.sort((a, b) => {
				const v1 = a[sortKey];
				const v2 = b[sortKey];

				if (typeof v1 === "string" && typeof v2 === "string") {
					return sortAsc ? v1.localeCompare(v2) : v2.localeCompare(v1);
				}

				return sortAsc ? (Number(v1) || 0) - (Number(v2) || 0) : (Number(v2) || 0) - (Number(v1) || 0);
			});
	});
</script>

<div class="top-bar">
	<span class="players-title" tabindex="-1">{t("players_list")}</span>
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
		<input placeholder={t("search_player")} type="text" bind:value={search} tabindex="-1" class="player-search-bar" />
	</div>
</div>
<div class="ply-table-header">
	<button type="button" tabindex="-1" onclick={() => setSort("id")}>
		{t("id")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("name")}>
		{t("name")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("cash")}>
		{t("money")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("bank")}>
		{t("bank_money")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("alt_money")}>
		{t("black_money")}
	</button>
	<span>{t("health")}</span>
	<span>{t("armor")}</span>
	<button type="button" tabindex="-1" onclick={() => setSort("last_join")}>
		{t("last_visited")}
	</button>
</div>
<div class="list-wrapper">
	<PlayersList {filteredPlayers} />
</div>

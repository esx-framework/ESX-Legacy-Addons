<script lang="ts">
	import "./PlayerManagement.css";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import { t } from "$lib/shared/util/util";
	import PlayersList from "./components/PlayersList.svelte";
	import { fetchNui } from "$lib/shared/nui/fetchNUI";
	import type { NuiSuccess } from "$lib/shared/nui/admin";
	import type { Player } from "./types/player";

	type OfflineSearchResponse = NuiSuccess & {
		players?: Player[];
	};

	let search = $state("");
	let results = $state<Player[]>([]);
	let loading = $state(false);
	let hasSearched = $state(false);

	type SortKey = "id" | "name" | "cash" | "bank" | "alt_money" | "last_join";

	let sortKey = $state<SortKey>("id");
	let sortAsc = $state(true);

	function setSort(key: SortKey) {
		if (sortKey === key) sortAsc = !sortAsc;
		else {
			sortKey = key;
			sortAsc = true;
		}
	}

	async function searchPlayer() {
		const identifier = search.trim().toLowerCase();
		if (!identifier) return;

		hasSearched = true;
		loading = true;

		const isChar = /^char\d+:/i.test(identifier);
		const isLicense = /^license:/i.test(identifier);

		let merged: Player[] = [];

		const onlineMatches = (uiState.players ?? []).filter((p) => {
			if (isChar) return p.char_identifier?.toLowerCase().includes(identifier);
			if (isLicense) return p.identifier?.toLowerCase().includes(identifier);

			return p.name?.toLowerCase().includes(identifier) || String(p.id ?? "").includes(identifier);
		});

		if (onlineMatches.length > 0) {
			merged = [...onlineMatches];
		}

		const res = await fetchNui<OfflineSearchResponse>("player:searchOffline", { identifier });

		if (res?.success) {
			for (const p of res.players ?? []) {
				const exists = merged.some((x) => x.char_identifier && p.char_identifier && x.char_identifier === p.char_identifier);

				if (!exists) {
					merged.push({
						...p,
						status: "offline",
						id: "OFF",
						_key: p.char_identifier ?? p.identifier ?? p.name,
					});
				}
			}
		}

		results = merged;
		loading = false;
	}

	const filteredResults = $derived.by<Player[]>(() => {
		return results.slice().sort((a, b) => {
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
	<span class="players-title">
		{t("search_player")}
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

		<input placeholder={t("search_player")} bind:value={search} onkeydown={(e) => e.key === "Enter" && searchPlayer()} tabindex="-1" class="player-search-bar" />
	</div>
</div>

{#if loading}
	<div class="spinner-wrapper">
		<div class="spinner"></div>
	</div>
{:else if filteredResults.length > 0}
	<div class="ply-table-header">
		<button type="button" tabindex="-1" onclick={() => setSort("id")}>{t("id")}</button>
		<button type="button" tabindex="-1" onclick={() => setSort("name")}>{t("name")}</button>
		<button type="button" tabindex="-1" onclick={() => setSort("cash")}>{t("money")}</button>
		<button type="button" tabindex="-1" onclick={() => setSort("bank")}>{t("bank_money")}</button>
		<button type="button" tabindex="-1" onclick={() => setSort("alt_money")}>{t("black_money")}</button>
		<span>{t("health")}</span>
		<span>{t("armor")}</span>
		<button type="button" tabindex="-1" onclick={() => setSort("last_join")}>{t("last_visited")}</button>
	</div>
	<div class="list-wrapper">
		<PlayersList filteredPlayers={filteredResults} />
	</div>
{:else if hasSearched}
	<div class="no-results">{t("no_players_found")}</div>
{/if}

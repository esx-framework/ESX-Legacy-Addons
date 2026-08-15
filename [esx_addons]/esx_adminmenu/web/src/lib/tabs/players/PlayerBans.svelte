<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./PlayerManagement.css";
	import { uiState } from "../../shared/stores/user.svelte";
	import type { Ban } from "./types/ban";
	import { fetchBanPage } from "../../shared/nui/admin";
	import BansList from "./components/BansList.svelte";
	import { getTimestampMs } from "$lib/shared/util/formatter";

	let search = $state("");

	type SortKey = "id" | "identifier" | "reason" | "banned_by" | "banned_at" | "expires_at";

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

	function getSortValue(ban: Ban, key: SortKey) {
		if (key === "banned_at" || key === "expires_at") {
			return getTimestampMs(ban[key]) ?? 0;
		}

		return ban[key];
	}

	// Filters bans depending on the sortKey variable.
	const filteredBans = $derived.by<Ban[]>(() => {
		const q = search.trim().toLowerCase();
		if (!uiState.bans) return [];

		return uiState.bans
			.filter((b) => (q === "" ? true : b.identifier.toLowerCase().includes(q) || b.reason.toLowerCase().includes(q) || String(b.id).includes(q)))
			.slice()
			.sort((a, b) => {
				const v1 = getSortValue(a, sortKey);
				const v2 = getSortValue(b, sortKey);

				if (typeof v1 === "string" && typeof v2 === "string") {
					return sortAsc ? v1.localeCompare(v2) : v2.localeCompare(v1);
				}

				return sortAsc ? (Number(v1) || 0) - (Number(v2) || 0) : (Number(v2) || 0) - (Number(v1) || 0);
			});
	});

	async function loadMoreBans() {
		if (search.trim() !== "") return;
		await fetchBanPage();
	}
</script>

<div class="top-bar">
	<span class="players-title" tabindex="-1">{t("bans_list")}</span>
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
		<input placeholder={t("search_banned_identifier")} type="text" bind:value={search} tabindex="-1" class="player-search-bar" />
	</div>
</div>

<div class="table-header">
	<button type="button" tabindex="-1" onclick={() => setSort("id")}>
		{`${t("ban")} ${t("id")}`}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("identifier")}>
		{t("identifier")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("reason")}>
		{t("reason")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("banned_by")}>
		{t("banned_by")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("banned_at")}>
		{t("banned_at")}
	</button>
	<button type="button" tabindex="-1" onclick={() => setSort("expires_at")}>
		{t("expires_at")}
	</button>
</div>

<div class="list-wrapper">
	<BansList {filteredBans} loading={uiState.banLoading} hasMore={uiState.banHasMore && search.trim() === ""} onNeedMore={loadMoreBans} />
</div>

<style>
	.table-header {
		display: grid;
		grid-template-columns: 7vh 1.5fr 1.5fr 1fr 1fr 1fr;
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
		background: none;
		border: none;
		outline: none;
		padding: 0;
		margin: 0;
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

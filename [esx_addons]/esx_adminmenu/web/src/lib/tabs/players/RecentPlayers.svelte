<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./PlayerManagement.css";
	import { uiState } from "../../shared/stores/user.svelte";
	import type { Player } from "./types/player";
	import PlayersList from "./components/PlayersList.svelte";

	let search = $state("");

	const filteredPlayers = $derived.by<Player[]>(() => {
		const q = search.trim().toLowerCase();
		const list = uiState.recentPlayers ?? [];

		return list.filter((p) =>
			q === ""
				? true
				: p.name.toLowerCase().includes(q) || (p.identifier ?? "").toLowerCase().includes(q) || (p.char_identifier ?? "").toLowerCase().includes(q)
		);
	});
</script>

<div class="top-bar">
	<span class="players-title" tabindex="-1">{t("recent_players")}</span>
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
	<span>{t("id")}</span>
	<span>{t("name")}</span>
	<span>{t("money")}</span>
	<span>{t("bank_money")}</span>
	<span>{t("black_money")}</span>
	<span>{t("health")}</span>
	<span>{t("armor")}</span>
	<span>{t("last_visited")}</span>
</div>

<div class="list-wrapper">
	<PlayersList filteredPlayers={filteredPlayers} />
</div>

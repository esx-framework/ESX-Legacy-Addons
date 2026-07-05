<script lang="ts">
	import { VirtualList } from "svelte-virtuallists";
	import type { Player } from "../types/player";
	import ContextMenu from "./ContextMenu.svelte";
	import PlayerInformation from "./PlayerInformation.svelte";
	import { formatName, formatMoney } from "../../../shared/util/formatter"; // Number Formatting (ex. 1.000.000)
	import { uiState } from "$lib/shared/stores/user.svelte";

	const { filteredPlayers = [] } = $props<{ filteredPlayers?: Player[] }>();

	// For displaying the player information tab.
	let infoOpen = $state(false);
	let selectedPlayer = $state<Player | null>(null);
	let mouseData = $state({ x: 0, y: 0 });

	const lastVisited = (ts?: number | null) => {
		if (!ts) return "-";

		const num = Number(ts);
		const ms = num < 1e12 ? num * 1000 : num;

		const d = new Date(ms);

		const day = String(d.getDate()).padStart(2, "0");
		const month = String(d.getMonth() + 1).padStart(2, "0");
		const year = d.getFullYear();

		return `${day}/${month}/${year}`;
	};

	// Context Menu States & Management
	let menuOpen = $state(false);
	let menuPlayer = $state<Player | null>(null);
	let menuX = $state(0);
	let menuY = $state(0);

	// Open Context Menu
	function openMenu(e: MouseEvent, player: Player) {
		e.preventDefault();
		menuOpen = false;
		queueMicrotask(() => {
			menuX = e.clientX;
			menuY = e.clientY;
			menuPlayer = player;
			menuOpen = true;
		});
	}

	// Open Context Menu
	function closeMenu() {
		menuOpen = false;
		menuPlayer = null;
	}

	function openInformation(mouseX: number, mouseY: number, player: Player, keepPosition = false) {
		selectedPlayer = player;

		if (!infoOpen || !keepPosition) {
			mouseData = { x: mouseX, y: mouseY };
		}

		infoOpen = true;
	}

	function handlePlayerKeydown(event: KeyboardEvent, player: Player) {
		if (event.key !== "Enter" && event.key !== " ") return;

		event.preventDefault();
		const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
		openInformation(rect.left, rect.top, player, infoOpen);
	}

	$effect(() => {
		const focusId = uiState.focusPlayerId;
		if (focusId === null) return;

		const player = filteredPlayers.find((p: Player) => Number(p.id) === focusId);
		if (!player) return;

		selectedPlayer = player;
		infoOpen = true;
		mouseData = { x: window.innerWidth / 2, y: window.innerHeight / 2 };
		uiState.clearFocusPlayer();
	});
</script>

<svelte:window
	onclick={() => {
		infoOpen = false;
	}}
/>

{#if filteredPlayers.length > 0}
	<VirtualList items={filteredPlayers} style="height:100%;width:100%;overflow:auto;">
		{#snippet vl_slot({ item })}
			{@const player = item as Player}
			<div
				role="button"
				tabindex="-1"
				class="player-row"
				onclick={(e) => {
					e.stopPropagation();
					openInformation(e.clientX, e.clientY, player, infoOpen);
				}}
				onkeydown={(e) => handlePlayerKeydown(e, player)}
				oncontextmenu={(e) => openMenu(e, player)}
			>
				<span><span class="id-badge">#{player.id}</span></span>
				<span>{formatName(player.name)}</span>
				<span>{formatMoney(player.cash)}</span>
				<span>{formatMoney(player.bank)}</span>
				<span>{formatMoney(player.alt_money)}</span>
				<span>{player.health}</span>
				<span>{player.armor}</span>
				<span>{lastVisited(player.last_join)}</span>
			</div>
		{/snippet}
	</VirtualList>
{/if}

<ContextMenu
	open={menuOpen}
	type={"player"}
	value={menuPlayer}
	x={menuX}
	y={menuY}
	onClose={closeMenu}
	toggleInformation={(mouseX: number, mouseY: number, player: Player, bool: boolean) => {
		if (bool) {
			openInformation(mouseX, mouseY, player, infoOpen);
		} else {
			infoOpen = false;
		}
	}}
/>

<PlayerInformation player={selectedPlayer ?? null} open={infoOpen} mouseX={mouseData.x} mouseY={mouseData.y} onClose={() => (infoOpen = false)} />

<style>
	.player-row {
		display: grid;
		grid-template-columns: 7vh 1.4fr repeat(6, 1fr);
		align-items: center;
		padding: 1.4vh;
		box-sizing: border-box;
		min-height: 4.9vh;
		background: #161616;
		border: 0.1vh solid rgba(242, 242, 242, 0.16);
		border-radius: 0.5vh;
		font-size: 1.3vh;
		margin-bottom: 0.8vh;
		overflow: hidden;
		transition:
			border 0.1s ease-in-out,
			background 0.1s ease-in-out;
	}

	.player-row:hover {
		border-color: rgba(251, 155, 4, 0.72);
		background: rgba(251, 155, 4, 0.06);
	}

	.player-row span {
		min-width: 0;
		max-width: 90%;
		word-break: break-word;
		white-space: normal;
	}

	.id-badge {
		padding: 0.2vh 0.5vh;
		background-color: #fb9b04;
		color: #161616;
		border-radius: 0.5vh;
		font-weight: 600;
	}
</style>

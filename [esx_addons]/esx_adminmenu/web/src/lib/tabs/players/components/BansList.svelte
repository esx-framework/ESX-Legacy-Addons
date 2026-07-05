<script lang="ts">
	import { VirtualList, type VLRangeEvent } from "svelte-virtuallists";
	import type { Ban } from "../types/ban";
	import { formatDate } from "$lib/shared/util/formatter";
	import ContextMenu from "./ContextMenu.svelte";

	const {
		filteredBans = [],
		hasMore = false,
		loading = false,
		onNeedMore,
	} = $props<{
		filteredBans?: Ban[];
		hasMore?: boolean;
		loading?: boolean;
		onNeedMore?: () => void | Promise<void>;
	}>();

	// Context Menu States & Management
	let menuOpen = $state(false);
	let menuBan = $state<Ban | null>(null);
	let menuX = $state(0);
	let menuY = $state(0);
	let lastRequestedLength = $state(0);

	// Open Context Menu
	function openMenu(e: MouseEvent, ban: Ban) {
		e.preventDefault();
		menuOpen = false;
		queueMicrotask(() => {
			menuX = e.clientX;
			menuY = e.clientY;
			menuBan = ban;
			menuOpen = true;
		});
	}

	// Open Context Menu
	function closeMenu() {
		menuOpen = false;
		menuBan = null;
	}

	function handleVisibleRange(range: VLRangeEvent) {
		if (!hasMore || loading || !onNeedMore) return;
		if (filteredBans.length === 0 || lastRequestedLength === filteredBans.length) return;
		if (Number(range.end) < filteredBans.length - 15) return;

		lastRequestedLength = filteredBans.length;
		void onNeedMore();
	}
</script>

{#if filteredBans.length > 0}
	<VirtualList items={filteredBans} style="height:100%;width:100%;overflow:auto;" onVisibleRangeUpdate={handleVisibleRange}>
		{#snippet vl_slot({ item })}
			{@const ban = item as Ban}
			<div role="button" tabindex="-1" class="ban-row" oncontextmenu={(e) => openMenu(e, ban)}>
				<span><span class="id-badge">#{ban.id}</span></span>
				<span>{ban.identifier}</span>
				<span>{ban.reason}</span>
				<span>{ban.banned_by ?? "-"}</span>
				<span>{formatDate(ban.banned_at, "-")}</span>
				<span>{formatDate(ban.expires_at)}</span>
			</div>
		{/snippet}
	</VirtualList>
	{#if loading}
		<div class="ban-loading">Loading bans...</div>
	{/if}
{/if}

<ContextMenu open={menuOpen} type={"ban"} value={menuBan} x={menuX} y={menuY} onClose={closeMenu} />

<style>
	.ban-row {
		display: grid;
		grid-template-columns: 7vh 1.5fr 1.5fr 1fr 1fr 1fr;
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
		transition: border 0.1s ease-in-out, background 0.1s ease-in-out;
	}

	.ban-row:hover {
		border-color: rgba(251, 155, 4, 0.72);
		background: rgba(251, 155, 4, 0.06);
	}

	.ban-row span {
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

	.ban-loading {
		display: flex;
		justify-content: center;
		padding: 0.8vh 0;
		color: rgba(242, 242, 242, 0.65);
		font-size: 1.2vh;
	}
</style>

<script lang="ts">
	import { VirtualList, type VLRangeEvent } from "svelte-virtuallists";
	import type { Vehicle } from "../types/vehicle";
	import ContextMenu from "./ContextMenu.svelte";

	const {
		filteredVehicles = [],
		hasMore = false,
		loading = false,
		onNeedMore,
	} = $props<{
		filteredVehicles?: Vehicle[];
		hasMore?: boolean;
		loading?: boolean;
		onNeedMore?: () => void | Promise<void>;
	}>();

	// Context Menu State
	let menuOpen = $state(false);
	let menuVehicle = $state<Vehicle | null>(null);
	let menuX = $state(0);
	let menuY = $state(0);
	let lastRequestedLength = $state(0);

	function openMenu(e: MouseEvent, vehicle: Vehicle) {
		e.preventDefault();
		menuOpen = false;

		queueMicrotask(() => {
			menuX = e.clientX;
			menuY = e.clientY;
			menuVehicle = vehicle;
			menuOpen = true;
		});
	}

	function closeMenu() {
		menuOpen = false;
		menuVehicle = null;
	}

	function handleVisibleRange(range: VLRangeEvent) {
		if (!hasMore || loading || !onNeedMore) return;
		if (filteredVehicles.length === 0 || lastRequestedLength === filteredVehicles.length) return;
		if (Number(range.end) < filteredVehicles.length - 15) return;

		lastRequestedLength = filteredVehicles.length;
		void onNeedMore();
	}
</script>

{#if filteredVehicles.length > 0}
	<VirtualList items={filteredVehicles} style="height:100%;width:100%;overflow:auto;" onVisibleRangeUpdate={handleVisibleRange}>
		{#snippet vl_slot({ item })}
			{@const vehicle = item as Vehicle}
			<div role="button" tabindex="-1" class="vehicle-row" oncontextmenu={(e) => openMenu(e, vehicle)}>
				<span><span class="plate-badge">{vehicle.plate}</span></span>
				<span>{vehicle.owner ?? "-"}</span>
				<span>{vehicle.name}</span>
				<span>{vehicle.type}</span>
				<span>{vehicle.mileage ?? "-"}</span>
				<span class:item-impounded={vehicle.impounded}>
					{vehicle.impounded ? "Yes" : "No"}
				</span>
			</div>
		{/snippet}
	</VirtualList>
	{#if loading}
		<div class="vehicle-loading">Loading vehicles...</div>
	{/if}
{/if}

<ContextMenu open={menuOpen} type={"vehicle"} value={menuVehicle} x={menuX} y={menuY} onClose={closeMenu} />

<style>
	.vehicle-row {
		display: grid;
		grid-template-columns: 1fr 1.2fr 1.5fr 1fr 1fr 0.7fr;
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

	.vehicle-row:hover {
		border-color: rgba(251, 155, 4, 0.72);
		background: rgba(251, 155, 4, 0.06);
	}

	.vehicle-row span {
		min-width: 0;
		max-width: 90%;
		word-break: break-word;
		white-space: normal;
	}

	.item-impounded {
		color: #fb9b04;
		font-weight: 600;
	}

	.plate-badge {
		padding: 0.2vh 0.5vh;
		background-color: #fb9b04;
		color: #161616;
		border-radius: 0.5vh;
		font-weight: 600;
	}

	.vehicle-loading {
		display: flex;
		justify-content: center;
		padding: 0.8vh 0;
		color: rgba(242, 242, 242, 0.65);
		font-size: 1.2vh;
	}
</style>

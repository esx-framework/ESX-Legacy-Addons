<script lang="ts">
	import "./Sidebar.css";
	import { currentPage } from "../stores/navigation.svelte";
	import { sidebarOptions } from "../config/sidebar";
	import type { SidebarOption } from "../types/sidebar";
	import { slide } from "svelte/transition";

	import { fetchNui } from "../nui/fetchNUI";
	import { uiState } from "../stores/user.svelte";
	import { fetchBanPage, fetchVehiclePage, type NuiSuccess } from "../nui/admin";
	import type { Player } from "../../tabs/players/types/player";

	type PlayersResponse = NuiSuccess & {
		players?: Player[];
	};

	function isSectionOpen(option: SidebarOption, page: string | null) {
		if (!option.subOptions) return false;
		if (page === option.value) return true;
		return option.subOptions.some((sub) => sub.value === page);
	}

	function selectOption(option: SidebarOption) {
		currentPage.set(option.value);
	}

	async function selectSub(option: SidebarOption) {
		currentPage.set(option.value);

		switch (option.value) {
			case "ply_bans":
				if (!uiState.bans) {
					await fetchBanPage({ reset: true });
				}
				break;

			case "ply_vehicles":
				if (!uiState.vehicles) {
					await fetchVehiclePage({ reset: true });
				}
				break;

			case "ply_recent":
				if (!uiState.recentPlayers) {
					const res = await fetchNui<PlayersResponse>("getRecentPlayers");
					if (res?.success) {
						uiState.setRecentPlayers(res.players ?? []);
					}
				}
				break;
		}
	}
</script>

<nav class="sidebar">
	{#each sidebarOptions as option, i}
		{@const Icon = option.icon}
		{@const open = isSectionOpen(option, currentPage.value)}

		<div class="accordion">
			<button class="header" class:active={currentPage.value === option.value} onclick={() => selectOption(option)} aria-expanded={open}>
				{#if Icon}
					<Icon class="accordion-icon" />
				{/if}
				<span class="label">{option.label}</span>
			</button>
			{#if option.subOptions && open}
				<div class="details" transition:slide>
					{#each option.subOptions as sub}
						{@const SubIcon = sub.icon}

						<button class="sub-button" class:active={currentPage.value === sub.value} onclick={() => selectSub(sub)}>
							{#if SubIcon}
								<SubIcon class="sub-icon" />
							{/if}
							<span>{sub.label}</span>
						</button>
					{/each}
				</div>
			{/if}
			{#if i < sidebarOptions.length - 1}
				<div class="sidebar-divider"></div>
			{/if}
		</div>
	{/each}
</nav>

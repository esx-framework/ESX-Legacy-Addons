<script lang="ts">
	import { currentPage } from "../stores/navigation.svelte";

	import OnlinePlayers from "../../tabs/players/OnlinePlayers.svelte";
	import PlayerBans from "../../tabs/players/PlayerBans.svelte";
	import PlayerVehicles from "../../tabs/players/PlayerVehicles.svelte";
	import PlayerSearch from "../../tabs/players/PlayerSearch.svelte";
	import RecentPlayers from "../../tabs/players/RecentPlayers.svelte";
	import DashboardHome from "../../tabs/dashboard/DashboardHome.svelte";
	import ServerManagement from "../../tabs/server/ServerManagement.svelte";
	import AdminLogs from "../../tabs/admin-logs/AdminLogs.svelte";
</script>

<svelte:window
	onkeydown={(e) => {
		if (e.key === "Tab") e.preventDefault();
	}}
/>

<div class="tab-container">
	<div class="tab-wrapper">
		{#if currentPage.value === "dashboard_home"}
			<DashboardHome />
		{:else if currentPage.value === "ply_management"}
			<OnlinePlayers />
		{:else if currentPage.value === "ply_online"}
			<OnlinePlayers />
		{:else if currentPage.value === "ply_bans"}
			<PlayerBans />
		{:else if currentPage.value === "ply_vehicles"}
			<PlayerVehicles />
		{:else if currentPage.value === "ply_data"}
			<PlayerSearch />
		{:else if currentPage.value === "ply_recent"}
			<RecentPlayers />
		{:else if currentPage.value === "srv_management"}
			<ServerManagement />
		{:else if currentPage.value === "admin_logs"}
			<AdminLogs />
		{:else}
			<p>Page not found</p>
		{/if}
	</div>
</div>

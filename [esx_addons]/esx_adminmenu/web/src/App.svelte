<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import { uiState } from "./lib/shared/stores/user.svelte";
	import UpperDisplay from "./lib/shared/components/UpperDisplay.svelte";
	import Sidebar from "./lib/shared/components/Sidebar.svelte";
	import TabContent from "./lib/shared/components/TabContent.svelte";
	import Notifications from "./lib/shared/components/Notifications.svelte";
	import AdminMenu from "./lib/tabs/admin-menu/AdminMenu.svelte";
	import { fetchNui } from "./lib/shared/nui/fetchNUI";
	import { currentPage } from "./lib/shared/stores/navigation.svelte";
	import type { NuiSuccess } from "./lib/shared/nui/admin";

	async function handleEscape() {
		const res = await fetchNui("releaseFocus", { release: true });

		if (res !== null) {
			currentPage.set("dashboard_home");
			uiState.close();
		}
	}

	async function handleOpenAdminMenu() {
		const res = await fetchNui<NuiSuccess>("openAdminMenu");

		if (res === null || res.success) {
			uiState.openMenu();
		}
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === "Escape") {
			if (uiState.visible) {
				handleEscape();
			}
		}
	}

	$effect(() => {
		window.addEventListener("keydown", handleKeyDown);

		return () => {
			window.removeEventListener("keydown", handleKeyDown);
		};
	});
</script>

{#if uiState.visible && uiState.mode === "dashboard"}
	<div class="esx-adminmenu-container">
		<UpperDisplay onEscape={handleEscape} onOpenAdminMenu={handleOpenAdminMenu} />
		<div class="menu-content">
			<Sidebar />
			<TabContent />
		</div>
	</div>
{:else if uiState.visible && uiState.mode === "menu"}
	<AdminMenu />
{/if}
<Notifications />
{#if uiState.spectating}
	<div class="spectate-tooltip-container">
		<div class="spectate-tooltip">
			{t("escape_spectate")}
		</div>
	</div>
{/if}

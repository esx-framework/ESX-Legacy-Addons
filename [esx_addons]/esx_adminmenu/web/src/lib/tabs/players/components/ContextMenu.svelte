<script lang="ts">
	import "./Actions.css";
	import { computePosition, offset, flip, shift, autoUpdate, type VirtualElement } from "@floating-ui/dom";
	import { copyToClipboardChromium, t } from "$lib/shared/util/util";
	import type { Player } from "../types/player";
	import type { Ban } from "../types/ban";
	import type { Vehicle } from "../types/vehicle";
	import { bringPlayer, gotoPlayer, spectatePlayer, kickPlayer, banPlayer, revokeBan, changeBanExpiry, banOfflinePlayer, impoundVehicle, unimpoundVehicle, deleteVehicle, notifyPlayer, runPlayerAction } from "$lib/shared/nui/admin";
	import ConfirmAction from "./ConfirmAction.svelte";

	type ContextType = "player" | "ban" | "vehicle";

	function copyToClipboard(text: string) {
		if (!text) return;
		copyToClipboardChromium(text);
	}

	async function handleImpoundClick(vehicle: Vehicle) {
		if (vehicle.impounded) {
			await unimpoundVehicle(vehicle.plate);
			return;
		}

		openConfirm("impound_vehicle");
	}

	const { open, type, value, x, y, onClose, toggleInformation } = $props<{
		open: boolean;
		type: ContextType;
		value?: Player | Vehicle | Ban | null;
		x: number;
		y: number;
		toggleInformation?: (mouseX: number, mouseY: number, player: Player, open: boolean) => void;
		onClose: () => void;
	}>();

	let menuEl: HTMLDivElement | null = $state(null);
	let tempValue = $state<Player | Vehicle | Ban | null>(null);
	let submenuOpen = $state<"tools" | "troll" | null>(null);

	const anchor: VirtualElement = {
		getBoundingClientRect() {
			return new DOMRect(x, y, 0, 0);
		},
	};

	async function position() {
		if (!menuEl || !open) return;

		const { x: px, y: py } = await computePosition(anchor, menuEl, {
			placement: "right-start",
			middleware: [offset(0), flip(), shift({ padding: 8 })],
		});

		Object.assign(menuEl.style, {
			left: `${px}px`,
			top: `${py}px`,
		});
	}

	let cleanup: (() => void) | null = null;

	$effect(() => {
		if (!open || !menuEl) {
			cleanup?.();
			cleanup = null;
			submenuOpen = null;
			return;
		}

		position();

		cleanup = autoUpdate(anchor, menuEl, position);

		return () => {
			cleanup?.();
			cleanup = null;
		};
	});

	type ActionType =
		| "kick"
		| "ban"
		| "notify"
		| "give_money"
		| "take_money"
		| "set_health"
		| "set_armor"
		| "clean_inventory"
		| "kill_player"
		| "revive_player"
		| "freeze_player"
		| "unfreeze_player"
		| "set_model"
		| "open_clothing"
		| "give_all_weapons"
		| "set_bucket"
		| "set_radio"
		| "set_job"
		| "set_name"
		| "set_thirst"
		| "set_hunger"
		| "ace_add"
		| "ace_remove"
		| "delete_character"
		| "troll_burn"
		| "troll_explode"
		| "troll_sky"
		| "troll_random"
		| "troll_nausea"
		| "change_expiry"
		| "revoke"
		| "delete_vehicle"
		| "impound_vehicle"
		| null;

	let confirmOpen = $state(false);
	let confirmType = $state<ActionType>(null);

	function openConfirm(type: ActionType) {
		confirmType = type;
		confirmOpen = true;
		tempValue = value ?? null;
	}

	function openTrollConfirm(type: ActionType) {
		submenuOpen = null;
		openConfirm(type);
		onClose();
	}

	function toggleSubmenu(name: "tools" | "troll") {
		submenuOpen = submenuOpen === name ? null : name;
	}

	function closeConfirm() {
		confirmOpen = false;
		confirmType = null;
		tempValue = null;
	}

	function getConfirmTitle() {
		if (!tempValue || !confirmType) return "";

		if (confirmType === "change_expiry") {
			return `${t("change_expiry")} | ${(tempValue as Ban).identifier}`;
		}

		if (confirmType === "revoke") {
			return `${t("revoke")} ${t("ban")} | ${(tempValue as Ban).identifier}`;
		}

		if (confirmType === "delete_vehicle") {
			return `${t("delete_vehicle")} | ${(tempValue as Vehicle).plate}`;
		}

		if (confirmType === "impound_vehicle") {
			return `${t("impound")} | ${(tempValue as Vehicle).plate}`;
		}

		const player = tempValue as Player;
		const labelByType: Partial<Record<Exclude<ActionType, null>, string>> = {
			kick: t("kick"),
			ban: t("ban"),
			notify: t("notify_player"),
			give_money: t("give_money"),
			take_money: t("take_money"),
			set_health: t("set_health"),
			set_armor: t("set_armor"),
			clean_inventory: t("clean_inventory"),
			kill_player: t("kill_player"),
			revive_player: t("revive_player"),
			freeze_player: t("freeze_player"),
			unfreeze_player: t("unfreeze_player"),
			set_model: t("set_model"),
			open_clothing: t("open_clothing"),
			give_all_weapons: t("give_all_weapons"),
			set_bucket: t("set_bucket"),
			set_radio: t("set_radio"),
			set_job: t("set_job"),
			set_name: t("set_name"),
			set_thirst: t("set_thirst"),
			set_hunger: t("set_hunger"),
			ace_add: t("ace_add"),
			ace_remove: t("ace_remove"),
			delete_character: t("delete_character"),
			troll_burn: t("troll_burn"),
			troll_explode: t("troll_explode"),
			troll_sky: t("troll_sky"),
			troll_random: t("troll_random"),
			troll_nausea: t("troll_nausea"),
		};
		const label = labelByType[confirmType] ?? "";
		const offlineIdentifier = player.identifier ?? player.char_identifier ?? t("identifier");
		const target = player.status === "online" ? `(#${player.id}) ${player.name}` : `${player.name} (${offlineIdentifier})`;

		return `${label} | ${target}`;
	}
</script>

<svelte:window onclick={onClose} />

{#if open && value}
	<div class="context-menu" bind:this={menuEl} role="menu" tabindex="-1" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
		{#if type === "player"}
			<div class="context-title">
				{value.status === "online" ? `#${value.id} - ${value.name}` : `OFFLINE - ${value.name}`}
			</div>

			<button
				class="menu-item"
				onclick={(e) => {
					toggleInformation?.(e.clientX, e.clientY, value as Player, true);
					onClose();
				}}
			>
				<svg viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path
						d="M6.56297 0C8.30358 0 9.97289 0.691454 11.2037 1.92225C12.4345 3.15304 13.1259 4.82236 13.1259 6.56297C13.1259 8.30358 12.4345 9.97289 11.2037 11.2037C9.97289 12.4345 8.30358 13.1259 6.56297 13.1259C4.82236 13.1259 3.15304 12.4345 1.92225 11.2037C0.691453 9.97289 0 8.30358 0 6.56297C0 4.82236 0.691453 3.15304 1.92225 1.92225C3.15304 0.691454 4.82236 0 6.56297 0ZM7.54734 4.02938C8.03484 4.02938 8.43047 3.69094 8.43047 3.18937C8.43047 2.68781 8.03391 2.34938 7.54734 2.34938C7.05984 2.34938 6.66609 2.68781 6.66609 3.18937C6.66609 3.69094 7.05984 4.02938 7.54734 4.02938ZM7.71891 9.30469C7.71891 9.20438 7.75359 8.94375 7.73391 8.79562L6.96328 9.6825C6.80391 9.85031 6.60422 9.96656 6.51047 9.93563C6.46794 9.91997 6.43239 9.88965 6.41022 9.85012C6.38805 9.8106 6.38071 9.76445 6.38953 9.72L7.67391 5.6625C7.77891 5.14781 7.49016 4.67812 6.87797 4.61812C6.23203 4.61812 5.28141 5.27344 4.70297 6.105C4.70297 6.20438 4.68422 6.45187 4.70391 6.6L5.47359 5.71219C5.63297 5.54625 5.81859 5.42906 5.91234 5.46094C5.95853 5.47752 5.99638 5.51154 6.01776 5.55571C6.03915 5.59988 6.04236 5.65067 6.02672 5.69719L4.75359 9.735C4.60641 10.2075 4.88484 10.6706 5.55984 10.7756C6.55359 10.7756 7.14047 10.1363 7.71984 9.30469H7.71891Z"
					/>
				</svg>
				{t("information")}
			</button>
			{#if value.status == "online"}
				<button
					class="menu-item"
					onclick={() => {
						gotoPlayer(Number(value.id));
						onClose();
					}}
				>
					<svg viewBox="0 0 10 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path
							d="M8.4375 0C7.92114 0 7.5 0.421143 7.5 0.9375V7.46704C7.49268 7.229 7.3938 7.00195 7.22534 6.83716L1.60034 1.21216C1.23413 0.845948 0.640869 0.845948 0.274658 1.21216C0.0988772 1.38794 0 1.62598 0 1.875C0 2.12402 0.0988772 2.36206 0.274658 2.53784L5.23682 7.5L0.274658 12.4622C0.0988772 12.6379 0 12.876 0 13.125C0 13.374 0.0988772 13.6121 0.274658 13.7878C0.640869 14.1541 1.23413 14.1541 1.60034 13.7878L7.22534 8.16284C7.3938 7.99439 7.49268 7.771 7.5 7.53662V14.0625C7.5 14.5789 7.92114 15 8.4375 15C8.95386 15 9.375 14.5789 9.375 14.0625V0.9375C9.375 0.421143 8.95386 0 8.4375 0Z"
						/>
					</svg>
					{t("teleport")}
				</button>
				<button
					class="menu-item"
					onclick={() => {
						bringPlayer(Number(value.id));
						onClose();
					}}
				>
					<svg viewBox="0 0 13 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path d="M3.73707 9.50836L2.88567 10.3598L7.52583 15L12.166 10.3598L11.3146 9.50836L8.1279 12.6951V0H0V1.20413H6.92377V12.6951L3.73707 9.50836Z" />
					</svg>
					{t("bring")}
				</button>
				<button
					class="menu-item"
					onclick={() => {
						spectatePlayer(Number(value.id));
						onClose();
					}}
				>
					<svg viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path
							d="M8.89533 1.04651C10.2257 1.04651 11.1708 1.04762 11.8878 1.14402C12.5897 1.23839 12.9941 1.41537 13.2893 1.71063C13.6292 2.05049 13.7772 2.31395 13.8591 2.78361C13.9514 3.31298 13.9535 4.06808 13.9535 5.40698C13.9535 5.69597 14.1877 5.93023 14.4767 5.93023C14.7657 5.93023 15 5.69597 15 5.40698V5.33978C15 4.08454 15 3.23422 14.89 2.60371C14.7677 1.90231 14.5069 1.44815 14.0294 0.970633C13.5072 0.448521 12.8452 0.21681 12.0272 0.106842C11.2324 -2.06572e-05 10.2169 -1.36373e-05 8.93468 3.16188e-07H8.89533C8.60635 3.16188e-07 8.37207 0.234272 8.37207 0.523256C8.37207 0.81224 8.60635 1.04651 8.89533 1.04651Z"
						/>
						<path
							d="M0.523264 9.06976C0.812248 9.06976 1.04652 9.30404 1.04652 9.59302C1.04652 10.9319 1.04853 11.687 1.1409 12.2164C1.22285 12.686 1.37077 12.9495 1.71064 13.2894C2.0059 13.5846 2.4103 13.7616 3.11222 13.8559C3.8292 13.9524 4.77431 13.9535 6.10465 13.9535C6.39363 13.9535 6.62791 14.1878 6.62791 14.4767C6.62791 14.7657 6.39363 15 6.10465 15H6.0653C4.78314 15 3.76758 15 2.97278 14.8932C2.15481 14.7832 1.49275 14.5515 0.970641 14.0294C0.493124 13.5518 0.232355 13.0976 0.109969 12.3963C-5.46214e-05 11.7658 -3.36546e-05 10.9155 1.2291e-06 9.66027L8.21532e-06 9.59302C8.21532e-06 9.30404 0.234273 9.06976 0.523264 9.06976Z"
						/>
						<path
							d="M14.4767 9.06976C14.7657 9.06976 15 9.30404 15 9.59302V9.66021C15 10.9155 15 11.7658 14.89 12.3963C14.7677 13.0976 14.5069 13.5518 14.0294 14.0294C13.5072 14.5515 12.8452 14.7832 12.0272 14.8932C11.2324 15 10.2169 15 8.93468 15H8.89533C8.60635 15 8.37207 14.7657 8.37207 14.4767C8.37207 14.1878 8.60635 13.9535 8.89533 13.9535C10.2257 13.9535 11.1708 13.9524 11.8878 13.8559C12.5897 13.7616 12.9941 13.5846 13.2893 13.2894C13.6292 12.9495 13.7772 12.686 13.8591 12.2164C13.9514 11.687 13.9535 10.9319 13.9535 9.59302C13.9535 9.30404 14.1877 9.06976 14.4767 9.06976Z"
						/>
						<path
							d="M6.0653 3.16188e-07H6.10465C6.39363 3.16188e-07 6.62791 0.234272 6.62791 0.523256C6.62791 0.81224 6.39363 1.04651 6.10465 1.04651C4.77432 1.04651 3.8292 1.04762 3.11222 1.14402C2.4103 1.23839 2.0059 1.41537 1.71064 1.71063C1.37077 2.05049 1.22285 2.31395 1.1409 2.78361C1.04853 3.31298 1.04652 4.06808 1.04652 5.40698C1.04652 5.69597 0.812248 5.93023 0.523264 5.93023C0.234273 5.93023 8.21532e-06 5.69597 8.21532e-06 5.40698L1.2291e-06 5.33978C-3.36546e-05 4.08456 -5.46214e-05 3.23421 0.109969 2.60371C0.232355 1.90231 0.493124 1.44815 0.970641 0.970633C1.49275 0.448521 2.15481 0.21681 2.97278 0.106842C3.76758 -2.06572e-05 4.78315 -1.36373e-05 6.0653 3.16188e-07Z"
						/>
						<path
							d="M7.50002 6.6279C7.01835 6.6279 6.62793 7.01832 6.62793 7.49999C6.62793 7.98167 7.01835 8.37209 7.50002 8.37209C7.9817 8.37209 8.37212 7.98167 8.37212 7.49999C8.37212 7.01832 7.9817 6.6279 7.50002 6.6279Z"
						/>
						<path
							fill-rule="evenodd"
							clip-rule="evenodd"
							d="M3.23889 8.93707C2.82381 8.4556 2.61627 8.21484 2.61627 7.5C2.61627 6.78516 2.82381 6.54439 3.23889 6.06294C4.06769 5.10156 5.45768 4.01163 7.49999 4.01163C9.54229 4.01163 10.9323 5.10155 11.7611 6.06294C12.1761 6.54439 12.3837 6.78516 12.3837 7.5C12.3837 8.21484 12.1761 8.4556 11.7611 8.93707C10.9323 9.89846 9.54229 10.9884 7.49999 10.9884C5.45768 10.9884 4.06769 9.89846 3.23889 8.93707ZM5.58139 7.5C5.58139 6.44037 6.44036 5.58139 7.49999 5.58139C8.55961 5.58139 9.41859 6.44037 9.41859 7.5C9.41859 8.55963 8.55961 9.4186 7.49999 9.4186C6.44036 9.4186 5.58139 8.55963 5.58139 7.5Z"
						/>
					</svg>
					{t("spectate")}
				</button>
				<button
					class="menu-item"
					onclick={() => {
						openConfirm("notify");
						onClose();
					}}
				>
					<svg viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path d="M2 3.5A1.5 1.5 0 0 1 3.5 2h8A1.5 1.5 0 0 1 13 3.5v5A1.5 1.5 0 0 1 11.5 10H8.2L5 12.5V10H3.5A1.5 1.5 0 0 1 2 8.5v-5Z" fill="currentColor" />
					</svg>
					{t("notify_player")}
				</button>
				<button class="menu-item" onclick={() => { openConfirm("give_money"); onClose(); }}>{t("give_money")}</button>
				<button class="menu-item" onclick={() => { openConfirm("take_money"); onClose(); }}>{t("take_money")}</button>
				<button class="menu-item" onclick={() => { openConfirm("set_health"); onClose(); }}>{t("set_health")}</button>
				<button class="menu-item" onclick={() => { openConfirm("set_armor"); onClose(); }}>{t("set_armor")}</button>
				<button
					class="menu-item has-submenu"
					class:active={submenuOpen === "tools"}
					aria-expanded={submenuOpen === "tools"}
					onclick={() => toggleSubmenu("tools")}
				>
					<span>{t("player_tools")}</span>
					<svg viewBox="0 0 12 12" aria-hidden="true">
						<path d="M4 2L8 6L4 10" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
					</svg>
				</button>
				{#if submenuOpen === "tools"}
					<div class="context-submenu">
						<div class="context-title">{t("player_tools")}</div>
						<button class="menu-item" onclick={() => openTrollConfirm("revive_player")}>{t("revive_player")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("kill_player")}>{t("kill_player")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("freeze_player")}>{t("freeze_player")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("unfreeze_player")}>{t("unfreeze_player")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_model")}>{t("set_model")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("open_clothing")}>{t("open_clothing")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("give_all_weapons")}>{t("give_all_weapons")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_bucket")}>{t("set_bucket")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_radio")}>{t("set_radio")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_job")}>{t("set_job")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_name")}>{t("set_name")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_thirst")}>{t("set_thirst")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("set_hunger")}>{t("set_hunger")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("ace_add")}>{t("ace_add")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("ace_remove")}>{t("ace_remove")}</button>
					</div>
				{/if}
				<button
					class="menu-item has-submenu"
					class:active={submenuOpen === "troll"}
					aria-expanded={submenuOpen === "troll"}
					onclick={() => toggleSubmenu("troll")}
				>
					<span>{t("troll_options")}</span>
					<svg viewBox="0 0 12 12" aria-hidden="true">
						<path d="M4 2L8 6L4 10" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
					</svg>
				</button>
				{#if submenuOpen === "troll"}
					<div class="context-submenu">
						<div class="context-title">{t("troll_options")}</div>
						<button class="menu-item" onclick={() => openTrollConfirm("troll_burn")}>{t("troll_burn")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("troll_explode")}>{t("troll_explode")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("troll_sky")}>{t("troll_sky")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("troll_random")}>{t("troll_random")}</button>
						<button class="menu-item" onclick={() => openTrollConfirm("troll_nausea")}>{t("troll_nausea")}</button>
					</div>
				{/if}
			{/if}
			{#if value.status === "online"}
				<button
					class="menu-item danger"
					onclick={() => {
						openConfirm("kick");
						onClose();
					}}
				>
					<svg width="15" height="15" viewBox="0 0 15 15" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
						<path d="M12.85 2.15L2.15 12.85" />
						<path d="M2.15 2.15L12.85 12.85" />
					</svg>
					{t("kick")}
				</button>
			{/if}
			{#if value.status === "online" || value.identifier}
				<button
					class="menu-item danger"
					onclick={() => {
						openConfirm("ban");
						onClose();
					}}
				>
					<svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path
							d="M7.49991 0.877075C3.84222 0.877075 0.877075 3.84222 0.877075 7.49991C0.877075 11.1576 3.84222 14.1227 7.49991 14.1227C11.1576 14.1227 14.1227 11.1576 14.1227 7.49991C14.1227 3.84222 11.1576 0.877075 7.49991 0.877075ZM3.85768 3.15057C4.84311 2.32448 6.11342 1.82708 7.49991 1.82708C10.6329 1.82708 13.1727 4.36689 13.1727 7.49991C13.1727 8.88638 12.6753 10.1567 11.8492 11.1421L3.85768 3.15057ZM3.15057 3.85768C2.32448 4.84311 1.82708 6.11342 1.82708 7.49991C1.82708 10.6329 4.36689 13.1727 7.49991 13.1727C8.88638 13.1727 10.1567 12.6753 11.1421 11.8492L3.15057 3.85768Z"
							fill="currentColor"
							fill-rule="evenodd"
							clip-rule="evenodd"
						>
						</path>
					</svg>
					{t("ban")}
				</button>
			{/if}
			{#if value.status === "online"}
				<button
					class="menu-item danger"
					onclick={() => {
						openConfirm("clean_inventory");
						onClose();
					}}
				>
					{t("clean_inventory")}
				</button>
			{/if}
			{#if value.char_identifier}
				<button
					class="menu-item danger"
					onclick={() => {
						openConfirm("delete_character");
						onClose();
					}}
				>
					{t("delete_character")}
				</button>
			{/if}
		{:else if type === "ban"}
			<div class="context-title context-title-stacked">
				<span>{t("target")}</span>
				<small>{value.identifier}</small>
			</div>
			<button
				class="menu-item"
				onclick={() => {
					openConfirm("change_expiry");
					onClose();
				}}
			>
				<svg width="15" height="15" viewBox="0 0 15 15" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
					<path d="M12.85 2.15L2.15 12.85" />
					<path d="M2.15 2.15L12.85 12.85" />
				</svg>
				{t("change_expiry")}
			</button>
			<button
				class="menu-item danger"
				onclick={() => {
					openConfirm("revoke");
					onClose();
				}}
			>
				<svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path
						d="M7.49991 0.877075C3.84222 0.877075 0.877075 3.84222 0.877075 7.49991C0.877075 11.1576 3.84222 14.1227 7.49991 14.1227C11.1576 14.1227 14.1227 11.1576 14.1227 7.49991C14.1227 3.84222 11.1576 0.877075 7.49991 0.877075ZM3.85768 3.15057C4.84311 2.32448 6.11342 1.82708 7.49991 1.82708C10.6329 1.82708 13.1727 4.36689 13.1727 7.49991C13.1727 8.88638 12.6753 10.1567 11.8492 11.1421L3.85768 3.15057ZM3.15057 3.85768C2.32448 4.84311 1.82708 6.11342 1.82708 7.49991C1.82708 10.6329 4.36689 13.1727 7.49991 13.1727C8.88638 13.1727 10.1567 12.6753 11.1421 11.8492L3.15057 3.85768Z"
						fill="currentColor"
						fill-rule="evenodd"
						clip-rule="evenodd"
					>
					</path>
				</svg>
				{t("revoke")}
			</button>
		{:else if type === "vehicle"}
			<div class="context-title">
				{value.plate} - {value.name}
			</div>

			<button
				class="menu-item"
				onclick={async () => {
					copyToClipboard(value.plate);
					onClose();
				}}
			>
				<svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
					<path
						d="m6 19v2c0 .621.52 1 1 1h2v-1.5h-1.5v-1.5zm7.5 3h-3.5v-1.5h3.5zm4.5 0h-3.5v-1.5h3.5zm4-3h-1.5v1.5h-1.5v1.5h2c.478 0 1-.379 1-1zm-1.5-1v-3.363h1.5v3.363zm0-4.363v-3.637h1.5v3.637zm-13-3.637v3.637h-1.5v-3.637zm11.5-4v1.5h1.5v1.5h1.5v-2c0-.478-.379-1-1-1zm-10 0h-2c-.62 0-1 .519-1 1v2h1.5v-1.5h1.5zm4.5 1.5h-3.5v-1.5h3.5zm3-1.5v-2.5h-13v13h2.5v-1.863h1.5v3.363h-4.5c-.48 0-1-.379-1-1v-14c0-.481.38-1 1-1h14c.621 0 1 .522 1 1v4.5h-3.5v-1.5z"
						fill-rule="nonzero"
					/>
				</svg>
				{t("copy_plate")}
			</button>

			<button
				class="menu-item"
				onclick={async () => {
					copyToClipboard(value.owner ?? "");
					onClose();
				}}
			>
				<svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
					<path
						d="m6 19v2c0 .621.52 1 1 1h2v-1.5h-1.5v-1.5zm7.5 3h-3.5v-1.5h3.5zm4.5 0h-3.5v-1.5h3.5zm4-3h-1.5v1.5h-1.5v1.5h2c.478 0 1-.379 1-1zm-1.5-1v-3.363h1.5v3.363zm0-4.363v-3.637h1.5v3.637zm-13-3.637v3.637h-1.5v-3.637zm11.5-4v1.5h1.5v1.5h1.5v-2c0-.478-.379-1-1-1zm-10 0h-2c-.62 0-1 .519-1 1v2h1.5v-1.5h1.5zm4.5 1.5h-3.5v-1.5h3.5zm3-1.5v-2.5h-13v13h2.5v-1.863h1.5v3.363h-4.5c-.48 0-1-.379-1-1v-14c0-.481.38-1 1-1h14c.621 0 1 .522 1 1v4.5h-3.5v-1.5z"
						fill-rule="nonzero"
					/>
				</svg>
				{t("copy_owner")}
			</button>

			<button
				class="menu-item"
				onclick={async () => {
					await handleImpoundClick(value);
					onClose();
				}}
			>
				<svg width="15" height="15" viewBox="0 0 15 15" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
					<path d="M12.85 2.15L2.15 12.85" />
					<path d="M2.15 2.15L12.85 12.85" />
				</svg>
				{value.impounded ? t("unimpound") : t("impound")}
			</button>

			<button
				class="menu-item danger"
				onclick={async () => {
					openConfirm("delete_vehicle");
					onClose();
				}}
			>
				<svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path
						d="M7.49991 0.877075C3.84222 0.877075 0.877075 3.84222 0.877075 7.49991C0.877075 11.1576 3.84222 14.1227 7.49991 14.1227C11.1576 14.1227 14.1227 11.1576 14.1227 7.49991C14.1227 3.84222 11.1576 0.877075 7.49991 0.877075ZM3.85768 3.15057C4.84311 2.32448 6.11342 1.82708 7.49991 1.82708C10.6329 1.82708 13.1727 4.36689 13.1727 7.49991C13.1727 8.88638 12.6753 10.1567 11.8492 11.1421L3.85768 3.15057ZM3.15057 3.85768C2.32448 4.84311 1.82708 6.11342 1.82708 7.49991C1.82708 10.6329 4.36689 13.1727 7.49991 13.1727C8.88638 13.1727 10.1567 12.6753 11.1421 11.8492L3.15057 3.85768Z"
						fill="currentColor"
						fill-rule="evenodd"
						clip-rule="evenodd"
					>
					</path>
				</svg>
				{t("delete_vehicle")}
			</button>
		{/if}
	</div>
{/if}

<ConfirmAction
	open={confirmOpen}
	{confirmType}
	title={getConfirmTitle()}
	onCancel={closeConfirm}
	onConfirm={async (data) => {
		if (!confirmType || !tempValue) return;

		try {
			switch (confirmType) {
				case "kick":
					await kickPlayer(Number((tempValue as Player).id), data.reason);
					break;

				case "ban":
					if ((tempValue as Player).status === "online") {
						await banPlayer(Number((tempValue as Player).id), data.reason, data.duration ?? undefined);
					} else {
						const identifier = (tempValue as Player).identifier;
						if (identifier) {
							await banOfflinePlayer(identifier, data.reason ?? "", data.duration ?? undefined);
						}
					}
					break;

				case "notify":
					await notifyPlayer(Number((tempValue as Player).id), data.reason ?? "");
					break;

				case "give_money":
					await runPlayerAction((tempValue as Player).id, "giveMoney", { amount: data.amount, account: "money" });
					break;

				case "take_money":
					await runPlayerAction((tempValue as Player).id, "takeMoney", { amount: data.amount, account: "money" });
					break;

				case "set_health":
					await runPlayerAction((tempValue as Player).id, "setHealth", { amount: data.amount });
					break;

				case "set_armor":
					await runPlayerAction((tempValue as Player).id, "setArmor", { amount: data.amount });
					break;

				case "clean_inventory":
					await runPlayerAction((tempValue as Player).id, "cleanInventory");
					break;

				case "kill_player":
					await runPlayerAction((tempValue as Player).id, "killPlayer");
					break;

				case "revive_player":
					await runPlayerAction((tempValue as Player).id, "revivePlayer");
					break;

				case "freeze_player":
					await runPlayerAction((tempValue as Player).id, "freezePlayer", { enabled: true });
					break;

				case "unfreeze_player":
					await runPlayerAction((tempValue as Player).id, "freezePlayer", { enabled: false });
					break;

				case "set_model":
					await runPlayerAction((tempValue as Player).id, "setModel", { model: data.text });
					break;

				case "open_clothing":
					await runPlayerAction((tempValue as Player).id, "openClothing");
					break;

				case "give_all_weapons":
					await runPlayerAction((tempValue as Player).id, "giveAllWeapons");
					break;

				case "set_bucket":
					await runPlayerAction((tempValue as Player).id, "setRoutingBucket", { bucket: data.amount });
					break;

				case "set_radio":
					await runPlayerAction((tempValue as Player).id, "setRadio", { channel: data.amount });
					break;

				case "set_job":
					await runPlayerAction((tempValue as Player).id, "setJob", { job: data.text, grade: data.amount ?? 0 });
					break;

				case "set_name":
					await runPlayerAction((tempValue as Player).id, "setName", { firstName: data.text, lastName: data.secondaryText });
					break;

				case "set_thirst":
					await runPlayerAction((tempValue as Player).id, "setThirst", { amount: data.amount });
					break;

				case "set_hunger":
					await runPlayerAction((tempValue as Player).id, "setHunger", { amount: data.amount });
					break;

				case "ace_add":
					await runPlayerAction((tempValue as Player).id, "aceAdd", { group: data.text });
					break;

				case "ace_remove":
					await runPlayerAction((tempValue as Player).id, "aceRemove", { group: data.text });
					break;

				case "delete_character":
					if ((tempValue as Player).char_identifier) {
						await runPlayerAction((tempValue as Player).id, "deleteCharacter", { identifier: (tempValue as Player).char_identifier });
					}
					break;

				case "troll_burn":
					await runPlayerAction((tempValue as Player).id, "troll", { trollAction: "burn" });
					break;

				case "troll_explode":
					await runPlayerAction((tempValue as Player).id, "troll", { trollAction: "explode" });
					break;

				case "troll_sky":
					await runPlayerAction((tempValue as Player).id, "troll", { trollAction: "sky" });
					break;

				case "troll_random":
					await runPlayerAction((tempValue as Player).id, "troll", { trollAction: "randomTeleport" });
					break;

				case "troll_nausea":
					await runPlayerAction((tempValue as Player).id, "troll", { trollAction: "nausea" });
					break;

				case "change_expiry":
					await changeBanExpiry((tempValue as Ban).identifier, data.newDate);
					break;

				case "revoke":
					await revokeBan((tempValue as Ban).identifier);
					break;

				case "delete_vehicle":
					await deleteVehicle((tempValue as Vehicle).plate);
					break;

				case "impound_vehicle":
					if (!data.impoundName) return;
					await impoundVehicle((tempValue as Vehicle).plate, data.impoundName);
					break;
			}
		} catch (e) {
			console.error("Confirm action failed", e);
		} finally {
			closeConfirm();
		}
	}}
/>

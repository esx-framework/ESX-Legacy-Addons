<script lang="ts">
	import { getRadioChannelPlayers, runAdminMenuAction, runServerAction, type RadioPlayer } from "$lib/shared/nui/admin";
	import { notifications } from "$lib/shared/stores/notifications.svelte";
	import { server } from "$lib/shared/stores/server.svelte";
	import { t } from "$lib/shared/util/util";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import Dropdown, { type DropdownOption } from "$lib/shared/components/Dropdown.svelte";

	let notificationMessage = $state("");
	let moneyAmount = $state(0);
	let moneyAccount = $state("money");
	let vehicleModel = $state(uiState.vehicleConfig.defaultModel);
	let spawnPrimaryColor = $state(uiState.vehicleConfig.defaultColor);
	let spawnSecondaryColor = $state(uiState.vehicleConfig.defaultColor);
	let customizePrimaryColor = $state(uiState.vehicleConfig.defaultColor);
	let customizeSecondaryColor = $state(uiState.vehicleConfig.defaultColor);
	let vehicleEngine = $state(5);
	let vehicleBrakes = $state(5);
	let vehicleTransmission = $state(5);
	let vehicleSuspension = $state(5);
	let vehicleArmor = $state(5);
	let vehicleMaxPerformance = $state(false);
	let vehicleTurbo = $state(true);
	let vehicleXenon = $state(false);
	let vehicleNeon = $state(false);
	let vehicleNeonColor = $state(uiState.vehicleConfig.neonPresets[0]?.id ?? "white");
	let vehicleWindowTint = $state(uiState.vehicleConfig.windowTints[0]?.id ?? 0);
	let vehicleWheelCategory = $state(uiState.vehicleConfig.wheelCategories[0]?.id ?? "sport");
	let vehicleWheelDesign = $state(uiState.vehicleConfig.wheelDesigns[0]?.id ?? -1);
	let vehicleBulletproofTires = $state(false);
	let radioChannel = $state(1);
	let radioPlayers = $state<RadioPlayer[]>([]);
	let radioLoading = $state(false);
	let busy = $state<string | null>(null);

	const weatherOptions: DropdownOption[] = ["CLEAR", "EXTRASUNNY", "CLOUDS", "OVERCAST", "RAIN", "THUNDER", "FOGGY", "XMAS"].map((value) => ({
		value,
		label: value,
	}));
	const hourOptions: DropdownOption<number>[] = Array.from({ length: 24 }, (_, hour) => ({
		value: hour,
		label: String(hour).padStart(2, "0"),
	}));
	const minuteOptions: DropdownOption<number>[] = Array.from({ length: 60 }, (_, minute) => ({
		value: minute,
		label: String(minute).padStart(2, "0"),
	}));
	const moneyAccounts: DropdownOption[] = [
		{ value: "money", label: "Cash" },
		{ value: "bank", label: "Bank" },
		{ value: "black_money", label: "Black Money" },
	];
	const performanceLevels: DropdownOption<number>[] = [1, 2, 3, 4, 5].map((value) => ({
		value,
		label: `${value}/5`,
	}));
	const vehicleColorOptions = $derived<DropdownOption[]>(uiState.vehicleConfig.colorPresets.map((preset) => ({ value: preset.id, label: preset.label })));
	const neonColorOptions = $derived<DropdownOption[]>(uiState.vehicleConfig.neonPresets.map((preset) => ({ value: preset.id, label: preset.label })));
	const windowTintOptions = $derived<DropdownOption<number>[]>(uiState.vehicleConfig.windowTints.map((tint) => ({ value: tint.id, label: tint.label })));
	const wheelCategoryOptions = $derived<DropdownOption[]>(uiState.vehicleConfig.wheelCategories.map((category) => ({ value: category.id, label: category.label })));
	const wheelDesignOptions = $derived<DropdownOption<number>[]>(uiState.vehicleConfig.wheelDesigns.map((design) => ({ value: design.id, label: design.label })));

	async function action(name: string, payload: Record<string, unknown> = {}) {
		if (busy) return;

		busy = name;
		const res = await runServerAction(name, payload);

		if (res?.success) {
			if (res.serverData) {
				server.set(res.serverData);
			}

			notifications.success("Action completed.");
		}

		busy = null;
	}

	function toggleBlackout() {
		void action("blackout", { enabled: !server.blackout });
	}

	function togglePvp() {
		void action("pvp", { enabled: !server.pvp });
	}

	async function lookupRadioPlayers() {
		if (radioLoading || radioChannel <= 0) return;

		radioLoading = true;
		radioPlayers = await getRadioChannelPlayers(radioChannel);
		radioLoading = false;
	}

	async function runVehicleAction(name: string, payload: Record<string, unknown>) {
		if (busy) return;

		busy = name;
		const res = await runAdminMenuAction(name, payload);

		if (res?.success) {
			notifications.success("Vehicle action completed.");
		}

		busy = null;
	}

	function spawnVehicle() {
		void runVehicleAction("spawnVehicle", {
			model: vehicleModel,
			color: spawnPrimaryColor,
			primaryColor: spawnPrimaryColor,
			secondaryColor: spawnSecondaryColor,
			deleteCurrent: true,
		});
	}

	function setMaxPerformance(enabled: boolean) {
		vehicleMaxPerformance = enabled;

		if (!enabled) return;

		vehicleEngine = 5;
		vehicleBrakes = 5;
		vehicleTransmission = 5;
		vehicleSuspension = 5;
		vehicleArmor = 5;
		vehicleTurbo = true;
	}

	function applyPerformance() {
		void runVehicleAction("setVehiclePerformance", {
			engineLevel: vehicleEngine,
			brakeLevel: vehicleBrakes,
			transmissionLevel: vehicleTransmission,
			suspensionLevel: vehicleSuspension,
			armorLevel: vehicleArmor,
			turbo: vehicleTurbo,
			xenon: vehicleXenon,
			neon: vehicleNeon,
			neonColor: vehicleNeonColor,
			color: customizePrimaryColor,
			primaryColor: customizePrimaryColor,
			secondaryColor: customizeSecondaryColor,
			windowTint: vehicleWindowTint,
			wheelCategory: vehicleWheelCategory,
			wheelDesign: vehicleWheelDesign,
			bulletproofTires: vehicleBulletproofTires,
			maxPerformance: vehicleMaxPerformance,
		});
	}
</script>

<div class="server-management">
	<header class="management-header">
		<div>
			<h2>Server Management</h2>
			<span>Environment, player-wide actions, broadcasts, and cleanup.</span>
		</div>
		<div class="status-pills">
			<span class:enabled={server.blackout}>Blackout {server.blackout ? "On" : "Off"}</span>
			<span class:enabled={server.pvp}>PvP {server.pvp ? "On" : "Off"}</span>
		</div>
	</header>

	<section class="management-section">
		<div class="section-title">
			<h3>Environment</h3>
			<span>Weather, time, blackout, and PvP.</span>
		</div>
		<div class="control-row">
			<label class="field">
				<span>Weather</span>
				<Dropdown value={server.weather} options={weatherOptions} onChange={(value) => (server.weather = String(value))} />
			</label>
			<button type="button" disabled={busy !== null} onclick={() => action("weather", { weather: server.weather })}>Apply Weather</button>
			<label class="field compact">
				<span>Hour</span>
				<Dropdown value={server.hour} options={hourOptions} onChange={(value) => (server.hour = Number(value))} />
			</label>
			<label class="field compact">
				<span>Minute</span>
				<Dropdown value={server.minute} options={minuteOptions} onChange={(value) => (server.minute = Number(value))} />
			</label>
			<button type="button" disabled={busy !== null} onclick={() => action("time", { hour: server.hour, minute: server.minute })}>Apply Time</button>
			<button type="button" class:active={server.blackout} disabled={busy !== null} onclick={toggleBlackout}>Toggle Blackout</button>
			<button type="button" class:active={server.pvp} disabled={busy !== null} onclick={togglePvp}>Toggle PvP</button>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>{t("vehicle_spawner", "Vehicle Spawner")}</h3>
			<span>Spawn a vehicle with the selected model and paint.</span>
		</div>
		<div class="vehicle-spawner-grid">
			<label class="field vehicle-model-field">
				<span>{t("vehicle_model", "Vehicle Model")}</span>
				<input type="text" bind:value={vehicleModel} placeholder={uiState.vehicleConfig.defaultModel} />
			</label>
			<label class="field">
				<span>{t("primary_color", "Primary Color")}</span>
				<Dropdown value={spawnPrimaryColor} options={vehicleColorOptions} onChange={(value) => (spawnPrimaryColor = String(value))} />
			</label>
			<label class="field">
				<span>{t("secondary_color", "Secondary Color")}</span>
				<Dropdown value={spawnSecondaryColor} options={vehicleColorOptions} onChange={(value) => (spawnSecondaryColor = String(value))} />
			</label>
			<button type="button" class="primary-action" disabled={busy !== null || vehicleModel.trim() === ""} onclick={spawnVehicle}>{t("spawn_vehicle", "Spawn Vehicle")}</button>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>{t("customize_vehicle", "Customize Vehicle")}</h3>
			<span>Apply performance, paint, lights, and tire options to the vehicle you are in.</span>
		</div>
		<div class="vehicle-customizer">
			<div class="customizer-grid">
				<label class="field compact">
					<span>{t("engine_level", "Engine")}</span>
					<Dropdown value={vehicleEngine} options={performanceLevels} onChange={(value) => { vehicleEngine = Number(value); vehicleMaxPerformance = false; }} />
				</label>
				<label class="field compact">
					<span>{t("brake_level", "Brakes")}</span>
					<Dropdown value={vehicleBrakes} options={performanceLevels} onChange={(value) => { vehicleBrakes = Number(value); vehicleMaxPerformance = false; }} />
				</label>
				<label class="field compact">
					<span>{t("transmission_level", "Transmission")}</span>
					<Dropdown value={vehicleTransmission} options={performanceLevels} onChange={(value) => { vehicleTransmission = Number(value); vehicleMaxPerformance = false; }} />
				</label>
				<label class="field compact">
					<span>{t("suspension_level", "Suspension")}</span>
					<Dropdown value={vehicleSuspension} options={performanceLevels} onChange={(value) => { vehicleSuspension = Number(value); vehicleMaxPerformance = false; }} />
				</label>
				<label class="field compact">
					<span>{t("vehicle_armor", "Vehicle Armor")}</span>
					<Dropdown value={vehicleArmor} options={performanceLevels} onChange={(value) => { vehicleArmor = Number(value); vehicleMaxPerformance = false; }} />
				</label>
				<label class="check-field">
					<input type="checkbox" checked={vehicleMaxPerformance} onchange={(event) => setMaxPerformance(event.currentTarget.checked)} />
					<span>{t("max_performance", "Max Performance")}</span>
				</label>
			</div>

			<div class="customizer-grid">
				<label class="field">
					<span>{t("primary_color", "Primary Color")}</span>
					<Dropdown value={customizePrimaryColor} options={vehicleColorOptions} onChange={(value) => (customizePrimaryColor = String(value))} />
				</label>
				<label class="field">
					<span>{t("secondary_color", "Secondary Color")}</span>
					<Dropdown value={customizeSecondaryColor} options={vehicleColorOptions} onChange={(value) => (customizeSecondaryColor = String(value))} />
				</label>
				<label class="field">
					<span>{t("neon_color", "Neon Color")}</span>
					<Dropdown value={vehicleNeonColor} options={neonColorOptions} onChange={(value) => (vehicleNeonColor = String(value))} />
				</label>
				<label class="field">
					<span>{t("window_tint", "Window Tint")}</span>
					<Dropdown value={vehicleWindowTint} options={windowTintOptions} onChange={(value) => (vehicleWindowTint = Number(value))} />
				</label>
				<label class="field">
					<span>{t("wheel_category", "Wheel Category")}</span>
					<Dropdown value={vehicleWheelCategory} options={wheelCategoryOptions} onChange={(value) => (vehicleWheelCategory = String(value))} />
				</label>
				<label class="field">
					<span>{t("wheel_design", "Disc Design")}</span>
					<Dropdown value={vehicleWheelDesign} options={wheelDesignOptions} onChange={(value) => (vehicleWheelDesign = Number(value))} />
				</label>
			</div>

			<div class="customizer-toggles">
				<label class="check-field">
					<input type="checkbox" bind:checked={vehicleTurbo} />
					<span>{t("turbo", "Turbo")}</span>
				</label>
				<label class="check-field">
					<input type="checkbox" bind:checked={vehicleXenon} />
					<span>{t("xenon_lights", "Xenon")}</span>
				</label>
				<label class="check-field">
					<input type="checkbox" bind:checked={vehicleNeon} />
					<span>{t("neon_lights", "Neon")}</span>
				</label>
				<label class="check-field">
					<input type="checkbox" bind:checked={vehicleBulletproofTires} />
					<span>{t("bulletproof_tires", "Bulletproof Tires")}</span>
				</label>
			</div>
			<div class="customizer-actions">
				<button type="button" class="primary-action" disabled={busy !== null} onclick={applyPerformance}>{t("apply_customization", "Apply Customization")}</button>
			</div>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>Players</h3>
			<span>Server-wide emergency actions.</span>
		</div>
		<div class="action-grid">
			<button type="button" disabled={busy !== null} onclick={() => action("freezeAll")}>Freeze All</button>
			<button type="button" disabled={busy !== null} onclick={() => action("unfreezeAll")}>Unfreeze All</button>
			<button type="button" disabled={busy !== null} onclick={() => action("bringAll")}>Bring All</button>
			<button type="button" disabled={busy !== null} onclick={() => action("reviveAll")}>Revive All</button>
			<button type="button" class="danger" disabled={busy !== null} onclick={() => action("kickAll")}>Kick All</button>
			<button type="button" class="danger" disabled={busy !== null} onclick={() => action("killAll")}>Kill All</button>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>Radio</h3>
			<span>See character names in a specific channel.</span>
		</div>
		<div class="radio-panel">
			<div class="control-row radio-row">
				<label class="field compact">
					<span>Channel</span>
					<input type="number" min="1" bind:value={radioChannel} />
				</label>
				<button type="button" disabled={radioLoading || radioChannel <= 0} onclick={lookupRadioPlayers}>
					{radioLoading ? "Checking..." : "Lookup Channel"}
				</button>
			</div>
			<div class="radio-results">
				{#if radioPlayers.length === 0}
					<span>No players found in this channel.</span>
				{:else}
					{#each radioPlayers as player}
						<div class="radio-player">
							<strong>#{player.id}</strong>
							<span>{player.name}</span>
							<small>{player.char_identifier ?? ""}</small>
						</div>
					{/each}
				{/if}
			</div>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>Cleanup</h3>
			<span>Remove world entities for everyone.</span>
		</div>
		<div class="action-grid">
			<button type="button" disabled={busy !== null} onclick={() => action("deleteVehicles")}>Delete Vehicles</button>
			<button type="button" disabled={busy !== null} onclick={() => action("deletePeds")}>Delete Peds</button>
			<button type="button" disabled={busy !== null} onclick={() => action("deleteObjects")}>Delete Objects</button>
		</div>
	</section>

	<section class="management-section">
		<div class="section-title">
			<h3>Broadcasts</h3>
			<span>Notify players or give everyone money.</span>
		</div>
		<div class="control-row broadcast-row">
			<label class="field message-field">
				<span>Notification</span>
				<input type="text" bind:value={notificationMessage} />
			</label>
			<button type="button" disabled={busy !== null || notificationMessage.trim() === ""} onclick={() => action("notifyAll", { message: notificationMessage })}>Send</button>
			<label class="field">
				<span>Account</span>
				<Dropdown value={moneyAccount} options={moneyAccounts} onChange={(value) => (moneyAccount = String(value))} />
			</label>
			<label class="field compact">
				<span>Amount</span>
				<input type="number" min="0" bind:value={moneyAmount} />
			</label>
			<button type="button" disabled={busy !== null || moneyAmount <= 0} onclick={() => action("giveMoneyAll", { account: moneyAccount, amount: moneyAmount })}>Give Money</button>
		</div>
	</section>
</div>

<style>
	.server-management {
		display: flex;
		flex-direction: column;
		gap: 1.1vh;
		height: 100%;
		min-height: 0;
		overflow-y: auto;
		overflow-x: hidden;
		padding-right: 0.4vh;
	}

	.management-header,
	.management-section {
		display: grid;
		grid-template-columns: 22vh minmax(0, 1fr);
		gap: 1.4vh;
		align-items: start;
		padding-bottom: 1.1vh;
		border-bottom: 0.1vh solid #2E2E2C;
	}

	.management-header {
		align-items: center;
	}

	h2,
	h3 {
		margin: 0;
		font-weight: 500;
	}

	h2 {
		font-size: 1.8vh;
	}

	h3 {
		font-size: 1.45vh;
	}

	.management-header span,
	.section-title span {
		display: block;
		margin-top: 0.2vh;
		color: rgba(242, 242, 242, 0.54);
		font-size: 1.05vh;
		line-height: 1.35;
	}

	.status-pills {
		display: flex;
		justify-content: flex-end;
		gap: 0.7vh;
	}

	.status-pills span {
		margin: 0;
		padding: 0.45vh 0.8vh;
		border: 0.1vh solid #2E2E2C;
		border-radius: 0.4vh;
		color: rgba(242, 242, 242, 0.7);
	}

	.status-pills span.enabled {
		border-color: rgba(251, 155, 4, 0.7);
		color: #FB9B04;
	}

	.control-row,
	.action-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(13vh, 1fr));
		gap: 0.7vh;
		align-items: end;
	}

	.action-grid {
		grid-template-columns: repeat(auto-fit, minmax(11vh, 1fr));
	}

	.broadcast-row {
		grid-template-columns: minmax(20vh, 2fr) minmax(8vh, 0.7fr) minmax(12vh, 1fr) minmax(9vh, 0.8fr) minmax(10vh, 1fr);
	}

	.radio-panel {
		display: grid;
		gap: 0.8vh;
	}

	.vehicle-spawner-grid,
	.vehicle-customizer {
		display: grid;
		gap: 0.8vh;
	}

	.vehicle-spawner-grid {
		grid-template-columns: minmax(18vh, 1.4fr) minmax(13vh, 0.9fr) minmax(13vh, 0.9fr) minmax(12vh, 0.75fr);
		align-items: end;
	}

	.vehicle-model-field {
		min-width: 18vh;
	}

	.customizer-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(10.5vh, 1fr));
		gap: 0.7vh;
		align-items: end;
	}

	.customizer-toggles {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(12vh, 1fr));
		gap: 0.7vh;
		align-items: center;
	}

	.customizer-actions {
		display: flex;
		justify-content: flex-end;
	}

	.customizer-actions .primary-action {
		width: min(18vh, 100%);
	}

	.radio-row {
		grid-template-columns: minmax(8vh, 0.45fr) minmax(12vh, 0.65fr) minmax(12vh, 1fr);
	}

	.radio-results {
		display: grid;
		gap: 0.45vh;
		max-height: 18vh;
		overflow-y: auto;
	}

	.radio-results > span {
		color: rgba(242, 242, 242, 0.5);
		font-size: 1.05vh;
	}

	.radio-player {
		display: grid;
		grid-template-columns: 5.5vh minmax(0, 1fr) minmax(0, 1.25fr);
		gap: 0.8vh;
		align-items: center;
		min-height: 3vh;
		padding: 0 0.8vh;
		border: 0.1vh solid #2E2E2C;
		border-radius: 0.4vh;
		background: rgba(37, 37, 37, 0.45);
		font-size: 1.05vh;
	}

	.radio-player strong {
		color: #FB9B04;
		font-weight: 600;
	}

	.radio-player span,
	.radio-player small {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.radio-player small {
		color: rgba(242, 242, 242, 0.45);
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: 0.3vh;
		min-width: 0;
		color: rgba(242, 242, 242, 0.58);
		font-size: 1vh;
	}

	.field.compact {
		min-width: 6vh;
	}

	.message-field {
		grid-column: span 1;
	}

	.check-field {
		display: flex;
		align-items: center;
		gap: 0.7vh;
		min-height: 3.4vh;
		color: rgba(242, 242, 242, 0.72);
		font-size: 1.05vh;
	}

	input,
	button {
		box-sizing: border-box;
		width: 100%;
		min-width: 0;
		height: 3.4vh;
		border: 0.1vh solid #2E2E2C;
		border-radius: 0.4vh;
		background: rgba(37, 37, 37, 0.6);
		color: #F2F2F2;
		font-family: "Poppins", sans-serif;
		font-size: 1.12vh;
	}

	input {
		padding: 0 0.9vh;
		outline: none;
	}

	input[type="checkbox"] {
		width: 1.45vh;
		height: 1.45vh;
		accent-color: #FB9B04;
	}

	button {
		cursor: pointer;
	}

	button:hover {
		border-color: rgba(251, 155, 4, 0.65);
		background: rgba(251, 155, 4, 0.08);
	}

	button:active {
		border-color: #FB9B04;
		background: rgba(251, 155, 4, 0.16);
	}

	button.active {
		border-color: #FB9B04;
		background: rgba(251, 155, 4, 0.16);
	}

	button.danger:hover {
		border-color: rgba(242, 63, 63, 0.75);
		background: rgba(242, 63, 63, 0.1);
	}

	button:disabled {
		cursor: default;
		opacity: 0.55;
	}

	@media (max-width: 1200px) {
		.management-header,
		.management-section {
			grid-template-columns: 1fr;
		}

		.status-pills {
			justify-content: flex-start;
		}

		.broadcast-row,
		.radio-row,
		.vehicle-spawner-grid,
		.customizer-grid,
		.customizer-toggles {
			grid-template-columns: repeat(auto-fit, minmax(13vh, 1fr));
		}

		.customizer-actions {
			justify-content: stretch;
		}

		.customizer-actions .primary-action {
			width: 100%;
		}
	}
</style>

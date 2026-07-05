<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import DatePicker from "./DatePicker.svelte";

	const { open, confirmType, title, onConfirm, onCancel } = $props<{
		open: boolean;
		confirmType: string | null;
		title: string;
		onConfirm: (data: { reason?: string; duration?: number | null; newDate?: number | null; impoundName?: string | null; amount?: number | null; text?: string; secondaryText?: string }) => void;
		onCancel: () => void;
	}>();

	let impoundOpen: boolean = $state(false);
	let selectedImpound: string | null = $state(null);

	const impoundNames = $derived(Object.keys(uiState.impounds ?? {}));

	let openedAt = $state<number | null>(null);

	$effect(() => {
		if (open) {
			openedAt = Date.now();
		} else {
			openedAt = null;
		}
	});

	let newDate: string = $state("");
	let reason: string = $state("");
	let textValue: string = $state("");
	let secondaryTextValue: string = $state("");
	let amountValue: number | null = $state(null);
	let durationValue: number | null = $state(null);
	type DurationUnit = "minutes" | "hours" | "days" | "months" | "years";

	let durationUnit: DurationUnit = $state("days");
	let unitOpen: boolean = $state(false);

	const unitToMinutes: Record<DurationUnit, number> = {
		minutes: 1,
		hours: 60,
		days: 1440,
		months: 43200,
		years: 525600,
	};

	const units: DurationUnit[] = ["minutes", "hours", "days", "months", "years"];
	const noInputConfirmTypes = new Set([
		"delete_vehicle",
		"revoke",
		"clean_inventory",
		"delete_character",
		"kill_player",
		"revive_player",
		"freeze_player",
		"unfreeze_player",
		"open_clothing",
		"give_all_weapons",
		"troll_burn",
		"troll_explode",
		"troll_sky",
		"troll_random",
		"troll_nausea",
	]);
	const textConfirmTypes = new Set(["set_model", "ace_add", "ace_remove"]);
	const numericConfirmTypes = new Set(["set_bucket", "set_radio", "set_thirst", "set_hunger"]);

	function confirm() {
		if (confirmType && noInputConfirmTypes.has(confirmType)) {
			onConfirm({});
			reset();
			return;
		}

		if (confirmType === "impound_vehicle") {
			if (!selectedImpound) return;

			onConfirm({ impoundName: selectedImpound });
			reset();
			return;
		}

		if (confirmType === "revoke") {
			onConfirm({});
			reset();
			return;
		}

		if (confirmType === "change_expiry") {
			if (!newDate) return;

			const timestamp = new Date(newDate + "T00:00:00").getTime();

			onConfirm({ newDate: timestamp });
			reset();
			return;
		}

		if (confirmType === "notify" && reason.trim() === "") {
			return;
		}

		if (confirmType === "give_money" || confirmType === "take_money") {
			if (amountValue === null || amountValue <= 0) return;

			onConfirm({ amount: amountValue });
			reset();
			return;
		}

		if (confirmType === "set_health" || confirmType === "set_armor") {
			if (amountValue === null || amountValue < 0) return;

			onConfirm({ amount: amountValue });
			reset();
			return;
		}

		if (confirmType === "set_name") {
			if (textValue.trim() === "" || secondaryTextValue.trim() === "") return;

			onConfirm({ text: textValue.trim(), secondaryText: secondaryTextValue.trim() });
			reset();
			return;
		}

		if (confirmType === "set_job") {
			if (textValue.trim() === "") return;

			onConfirm({ text: textValue.trim(), amount: amountValue ?? 0 });
			reset();
			return;
		}

		if (confirmType && textConfirmTypes.has(confirmType)) {
			if (textValue.trim() === "") return;

			onConfirm({ text: textValue.trim() });
			reset();
			return;
		}

		if (confirmType && numericConfirmTypes.has(confirmType)) {
			if (amountValue === null || amountValue < 0) return;

			onConfirm({ amount: amountValue });
			reset();
			return;
		}

		let duration: number | null = null;

		if (confirmType === "ban" && durationValue !== null) {
			duration = durationValue * unitToMinutes[durationUnit];
		}

		onConfirm({ reason, duration });
		reset();
	}

	function cancel() {
		onCancel();
		reset();
	}

	function reset() {
		newDate = "";
		reason = "";
		textValue = "";
		secondaryTextValue = "";
		amountValue = null;
		durationValue = null;
		durationUnit = "days";
		unitOpen = false;

		selectedImpound = null;
		impoundOpen = false;
	}

	function toggleUnit() {
		unitOpen = !unitOpen;
	}

	function selectUnit(value: DurationUnit) {
		durationUnit = value;
		unitOpen = false;
	}

	function toggleImpound() {
		impoundOpen = !impoundOpen;
	}

	function selectImpound(name: string) {
		selectedImpound = name;
		impoundOpen = false;
	}

	function stopPropagation(event: Event) {
		event.stopPropagation();
	}
</script>

<svelte:window
	onclick={() => {
		if (!open || openedAt === null) return;
		if (Date.now() - openedAt < 1000) return;

		cancel();
	}}
	onkeydown={(e) => {
		if (e.key !== "Escape") return;
		if (!open || openedAt === null) return;
		if (Date.now() - openedAt < 1000) return;

		cancel();
	}}
/>

{#if open}
	<div class="confirm-modal-backdrop">
		<div class="confirm-modal" role="dialog" aria-modal="true" aria-label={title} tabindex="-1" onclick={stopPropagation} onkeydown={stopPropagation}>
			<div class="confirm-modal-header">
				<div class="confirm-modal-title">{title}</div>
			</div>

			<div class="confirm-modal-body">
				{#if confirmType === "change_expiry"}
					<label class="confirm-field">
						<span class="confirm-label">
							{t("new_expiry_date")}
						</span>

						<DatePicker value={newDate} min={new Date().toISOString().split("T")[0]} onChange={(value) => (newDate = value)} />
					</label>
				{/if}
				{#if confirmType === "impound_vehicle"}
					<label class="confirm-field">
						<span class="confirm-label">
							{t("select_impound")}
						</span>

						<div class="confirm-dropdown lg-dropdown" role="presentation" onclick={stopPropagation} onkeydown={stopPropagation}>
							<button type="button" tabindex="-1" class="confirm-dropdown-trigger" aria-expanded={impoundOpen} onclick={toggleImpound}>
								<span>{selectedImpound ?? t("select_impound")}</span>

								<svg class="confirm-dropdown-arrow" class:open={impoundOpen} viewBox="0 0 11 10">
									<path
										d="M3.30202 1C4.07182 -0.333333 5.99632 -0.333333 6.76612 1L9.79721 6.25C10.567 7.58333 9.60476 9.25 8.06516 9.25H2.00298C0.463381 9.25 -0.498867 7.58333 0.270933 6.25L3.30202 1Z"
										fill="currentColor"
									/>
								</svg>
							</button>

							<div class="confirm-dropdown-menu" class:open={impoundOpen} tabindex="-1">
								{#each impoundNames as name}
									<button
										type="button"
										class="confirm-dropdown-item"
										class:selected={name === selectedImpound}
										tabindex="-1"
										onclick={(e) => {
											e.preventDefault();
											selectImpound(name);
										}}
									>
										{name}
									</button>
								{/each}
							</div>
						</div>
					</label>
				{/if}
				{#if confirmType === "ban" || confirmType === "kick" || confirmType === "notify"}
					<label class="confirm-field">
						<span class="confirm-label">
							{confirmType === "notify" ? t("notification_message") : t("reason")}
						</span>

						<input class="confirm-input" type="text" bind:value={reason} placeholder={confirmType === "notify" ? t("notification_message") : t("ban_reason_placeholder")} />
					</label>
				{/if}
				{#if confirmType === "set_model" || confirmType === "ace_add" || confirmType === "ace_remove"}
					<label class="confirm-field">
						<span class="confirm-label">
							{confirmType === "set_model" ? t("model_name") : t("ace_group")}
						</span>

						<input class="confirm-input" type="text" bind:value={textValue} placeholder={confirmType === "set_model" ? "mp_m_freemode_01" : "admin"} />
					</label>
				{/if}
				{#if confirmType === "set_name"}
					<label class="confirm-field">
						<span class="confirm-label">{t("first_name")}</span>
						<input class="confirm-input" type="text" bind:value={textValue} />
					</label>
					<label class="confirm-field">
						<span class="confirm-label">{t("last_name")}</span>
						<input class="confirm-input" type="text" bind:value={secondaryTextValue} />
					</label>
				{/if}
				{#if confirmType === "set_job"}
					<label class="confirm-field">
						<span class="confirm-label">{t("job")}</span>
						<input class="confirm-input" type="text" bind:value={textValue} placeholder="police" />
					</label>
					<label class="confirm-field">
						<span class="confirm-label">{t("job_grade")}</span>
						<input class="confirm-input" type="number" min="0" bind:value={amountValue} />
					</label>
				{/if}
				{#if confirmType === "set_bucket" || confirmType === "set_radio" || confirmType === "set_thirst" || confirmType === "set_hunger"}
					<label class="confirm-field">
						<span class="confirm-label">
							{confirmType === "set_bucket"
								? t("routing_bucket")
								: confirmType === "set_radio"
									? t("radio_channel")
									: confirmType === "set_thirst"
										? t("thirst")
										: t("hunger")}
						</span>

						<input class="confirm-input" type="number" min="0" max={confirmType === "set_thirst" || confirmType === "set_hunger" ? 100 : undefined} bind:value={amountValue} />
					</label>
				{/if}
				{#if confirmType === "give_money" || confirmType === "take_money" || confirmType === "set_health" || confirmType === "set_armor"}
					<label class="confirm-field">
						<span class="confirm-label">
							{confirmType === "set_health" ? t("health") : confirmType === "set_armor" ? t("armor") : t("money")}
						</span>

						<input class="confirm-input" type="number" min={confirmType === "set_health" || confirmType === "set_armor" ? 0 : 1} max={confirmType === "set_health" || confirmType === "set_armor" ? 100 : undefined} bind:value={amountValue} />
					</label>
				{/if}
				{#if confirmType === "ban"}
					<label class="confirm-field">
						<span class="confirm-label">
							{t("duration")}
						</span>

						<div class="confirm-duration-row">
							<input class="confirm-input duration-input" type="number" min="0" bind:value={durationValue} placeholder={t("permanent")} />

							<div class="confirm-dropdown" role="presentation" onclick={stopPropagation} onkeydown={stopPropagation}>
								<button type="button" tabindex="-1" class="confirm-dropdown-trigger" aria-expanded={unitOpen} onclick={toggleUnit}>
									<span>{t(durationUnit)}</span>

									<svg class="confirm-dropdown-arrow" class:open={unitOpen} viewBox="0 0 11 10" xmlns="http://www.w3.org/2000/svg">
										<path
											d="M3.30202 1C4.07182 -0.333333 5.99632 -0.333333 6.76612 1L9.79721 6.25C10.567 7.58333 9.60476 9.25 8.06516 9.25H2.00298C0.463381 9.25 -0.498867 7.58333 0.270933 6.25L3.30202 1Z"
											fill="currentColor"
										/>
									</svg>
								</button>

								<div class="confirm-dropdown-menu" class:open={unitOpen} tabindex="-1">
									{#each units as unit}
										<button type="button" class="confirm-dropdown-item" class:selected={unit === durationUnit} tabindex="-1" onclick={() => selectUnit(unit)}>
											{t(unit)}
										</button>
									{/each}
								</div>
							</div>
						</div>

						<div class="confirm-hint">
							{t("duration_desc")}
						</div>
					</label>
				{/if}
			</div>

			<!-- Actions -->
			<div class="confirm-actions">
				<button class="confirm-btn cancel" type="button" tabindex="-1" onclick={cancel}>
					{t("cancel")}
				</button>

				<button class="confirm-btn confirm" type="button" tabindex="-1" onclick={confirm}>
					{t("confirm")}
				</button>
			</div>
		</div>
	</div>
{/if}

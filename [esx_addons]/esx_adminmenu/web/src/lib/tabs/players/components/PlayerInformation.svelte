<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./Actions.css";
	import { computePosition, offset, flip, shift, autoUpdate, type VirtualElement } from "@floating-ui/dom";
	import type { Player } from "../types/player";
	import { formatName, formatMoney, formatLastVisited, formatPlayTime, formatPosition } from "../../../shared/util/formatter";
	import { copyToClipboardChromium } from "$lib/shared/util/util";

	const { open, player, mouseX, mouseY, onClose } = $props<{
		open: boolean;
		player: Player | null;
		mouseX: number;
		mouseY: number;
		onClose: () => void;
	}>();

	let panelEl: HTMLDivElement | null = $state(null);

	let x = $state(0);
	let y = $state(0);

	let dragging = false;
	let hasBeenDragged = false;
	let offsetX = 0;
	let offsetY = 0;

	const anchor: VirtualElement = {
		getBoundingClientRect() {
			return new DOMRect(mouseX, mouseY, 0, 0);
		},
	};

	async function computeInitialPosition() {
		if (!panelEl || hasBeenDragged) return;

		const { x: px, y: py } = await computePosition(anchor, panelEl, {
			placement: "right-start",
			middleware: [offset(), flip(), shift()],
		});

		x = px;
		y = py;
	}

	function onMouseDown(e: MouseEvent) {
		dragging = true;
		hasBeenDragged = true;

		cleanup?.();
		cleanup = null;

		offsetX = e.clientX - x;
		offsetY = e.clientY - y;

		window.addEventListener("mousemove", onMouseMove);
		window.addEventListener("mouseup", onMouseUp);
	}

	let rafId: number | null = null;
	let pendingX = 0;
	let pendingY = 0;

	function onMouseMove(e: MouseEvent) {
		if (!dragging) return;

		pendingX = e.clientX - offsetX;
		pendingY = e.clientY - offsetY;

		if (rafId !== null) return;

		rafId = requestAnimationFrame(() => {
			x = pendingX;
			y = pendingY;
			rafId = null;
		});
	}

	function onMouseUp() {
		if (rafId !== null) {
			cancelAnimationFrame(rafId);
			rafId = null;
		}
		dragging = false;
		window.removeEventListener("mousemove", onMouseMove);
		window.removeEventListener("mouseup", onMouseUp);
	}

	let cleanup: (() => void) | null = null;

	$effect(() => {
		if (!open || !panelEl || hasBeenDragged) {
			cleanup?.();
			cleanup = null;
			return;
		}

		computeInitialPosition();

		cleanup = autoUpdate(anchor, panelEl, computeInitialPosition);

		window.addEventListener("resize", computeInitialPosition);

		return () => {
			cleanup?.();
			cleanup = null;
			window.removeEventListener("resize", computeInitialPosition);
		};
	});

	$effect(() => {
		if (!open) {
			hasBeenDragged = false;
		}
	});

	let copiedText = $state<string | null>(null);
	let copyTimeout: number | null = null;

	async function copyToClipboard(text: string) {
		copyToClipboardChromium(text);

		await new Promise((r) => setTimeout(r, 0));

		copiedText = t("copied_to_clipboard", "Copied to clipboard");

		if (copyTimeout) clearTimeout(copyTimeout);
		copyTimeout = window.setTimeout(() => {
			copiedText = null;
		}, 1000);
	}
</script>

{#if open && player}
	<div class="info-panel" bind:this={panelEl} style="left: {x}px; top: {y}px" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-label={t("player_information")} tabindex="-1">
		<div class="info-header" onmousedown={onMouseDown} role="menubar" tabindex="-1">
			{#if player.status === "online"}
				<span class="online-badge">
					<span class="online-dot"></span>
					<span>{t("online")}</span>
				</span>
			{:else}
				<span class="offline-badge">
					<span class="offline-dot"></span>
					<span>{t("offline")}</span>
				</span>
			{/if}
			<span>{t("player_information")}</span>
			<button class="info-close" onclick={onClose} aria-label="close">
				<svg viewBox="0 0 15 15" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
					<path d="M12.85 2.15L2.15 12.85" />
					<path d="M2.15 2.15L12.85 12.85" />
				</svg>
			</button>
		</div>
		<div class="info-content">
			{#if player.status === "online"}
				{@render InfoRow({ label: t("id"), value: player.id })}
			{/if}
			{#if player.identifier}
				{@render InfoRow({ label: t("identifier"), value: player.identifier })}
			{/if}
			{#if player.ip}
				{@render InfoRow({ label: t("ip_address"), value: player.ip })}
			{/if}
			{#if player.status === "online"}
				{@render InfoRow({ label: t("routing_bucket"), value: player.routing_bucket ?? 0 })}
				{@render InfoRow({ label: t("radio_channel"), value: player.radio_channel ?? 0 })}
			{/if}
			{#if player.char_identifier}
				{@render InfoRow({ label: t("char_identifier"), value: player.char_identifier })}
			{/if}
			{@render InfoRow({ label: t("name"), value: formatName(player.name) })}
			{@render InfoRow({
				label: t("gender"),
				value: player.gender === "m" ? t("male") : t("female"),
			})}

			{@render InfoRow({ label: t("job"), value: player.job ?? "Unknown" })}
			{@render InfoRow({ label: t("job_grade"), value: player.job_grade ?? "Unknown" })}

			{@render InfoRow({ label: t("money"), value: `$${formatMoney(player.cash)}` })}
			{@render InfoRow({ label: t("bank_money"), value: `$${formatMoney(player.bank)}` })}
			{@render InfoRow({ label: t("black_money"), value: `$${formatMoney(player.alt_money)}` })}

			{#if player.status === "online"}
				{@render InfoRow({ label: t("position"), value: formatPosition(player.position) })}
				{@render InfoRow({ label: t("health"), value: player.health })}
				{@render InfoRow({ label: t("armor"), value: player.armor })}
			{/if}

			{@render InfoRow({ label: t("play_time"), value: formatPlayTime(player.play_time) })}
			{@render InfoRow({ label: t("last_visited"), value: formatLastVisited(player.last_join) })}

			{#if player.identifiers && Object.keys(player.identifiers).length > 0}
				<div class="info-section-title">{t("identifiers")}</div>
				{#each Object.entries(player.identifiers) as [key, identifier]}
					{@render InfoRow({ label: key, value: String(identifier) })}
				{/each}
			{/if}

			{#if copiedText}
				<div class="clipboard-feedback">
					<svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
						<path
							d="m6 19v2c0 .621.52 1 1 1h2v-1.5h-1.5v-1.5zm7.5 3h-3.5v-1.5h3.5zm4.5 0h-3.5v-1.5h3.5zm4-3h-1.5v1.5h-1.5v1.5h2c.478 0 1-.379 1-1zm-1.5-1v-3.363h1.5v3.363zm0-4.363v-3.637h1.5v3.637zm-13-3.637v3.637h-1.5v-3.637zm11.5-4v1.5h1.5v1.5h1.5v-2c0-.478-.379-1-1-1zm-10 0h-2c-.62 0-1 .519-1 1v2h1.5v-1.5h1.5zm4.5 1.5h-3.5v-1.5h3.5zm3-1.5v-2.5h-13v13h2.5v-1.863h1.5v3.363h-4.5c-.48 0-1-.379-1-1v-14c0-.481.38-1 1-1h14c.621 0 1 .522 1 1v4.5h-3.5v-1.5z"
							fill-rule="nonzero"
						/>
					</svg>
					{copiedText}
				</div>
			{/if}
		</div>
	</div>
{/if}

{#snippet InfoRow({ label, value }: { label: string; value: string | number | null | undefined })}
	{@const displayValue = value ?? "-"}
	<div class="info-row" role="button" tabindex="0" onclick={() => value != null && copyToClipboard(String(value))} onkeydown={(e) => e.key === "Enter" && value != null && copyToClipboard(String(value))}>
		<span class="info-label">{label}</span>
		<span class="info-value">{displayValue}</span>
	</div>
{/snippet}

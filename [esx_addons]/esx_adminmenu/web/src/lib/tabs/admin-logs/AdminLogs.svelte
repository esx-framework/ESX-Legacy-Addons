<script lang="ts">
	import { onMount } from "svelte";
	import "../players/PlayerManagement.css";
	import { t } from "$lib/shared/util/util";
	import { getTimestampMs } from "$lib/shared/util/formatter";
	import { fetchAdminLogs } from "$lib/shared/nui/admin";
	import { describeLog, relativeTime, absoluteTime, buildDetails, CATEGORY_LABELS } from "./logLabels";
	import type { AdminLog } from "./types/log";

	const PAGE_SIZE = 50;

	// Ids of the rows whose details panel is open.
	let expanded = $state(new Set<number>());

	function toggleDetails(id: number) {
		// Reassigned rather than mutated so the rune picks the change up.
		const next = new Set(expanded);
		if (next.has(id)) next.delete(id);
		else next.add(id);
		expanded = next;
	}

	let logs = $state<AdminLog[]>([]);
	let loading = $state(false);
	let hasMore = $state(false);
	let nextOffset = $state(0);
	let loaded = $state(false);

	let namespaceFilter = $state("");
	let daysFilter = $state(7);
	let search = $state("");

	// Search runs on the server: filtering only the loaded page would miss every
	// older entry, which defeats the point of searching a log.
	let appliedSearch = $state("");
	let searchTimer: ReturnType<typeof setTimeout> | undefined;

	// A query under two characters matches almost everything, so it is treated
	// as no search at all rather than scanning the table for nothing.
	const MIN_SEARCH = 2;

	function normalizedSearch() {
		const value = search.trim();
		return value.length >= MIN_SEARCH ? value : "";
	}

	/** Debounced so a burst of keystrokes issues one query, not one per letter. */
	function onSearchInput() {
		clearTimeout(searchTimer);
		searchTimer = setTimeout(() => {
			const next = normalizedSearch();
			if (next === appliedSearch) return;

			appliedSearch = next;
			void load(true);
		}, 300);
	}

	function clearSearch() {
		clearTimeout(searchTimer);
		search = "";
		appliedSearch = "";
		void load(true);
	}

	async function load(reset = true) {
		if (loading) return;
		loading = true;

		const res = await fetchAdminLogs({
			search: appliedSearch || undefined,
			namespace: namespaceFilter || undefined,
			days: daysFilter > 0 ? daysFilter : undefined,
			limit: PAGE_SIZE,
			offset: reset ? 0 : nextOffset,
		});

		logs = reset ? res.logs : [...logs, ...res.logs];
		hasMore = res.hasMore;
		nextOffset = res.nextOffset;
		loading = false;
		loaded = true;
	}

	onMount(() => {
		void load(true);
	});

	// Rows grow when their details panel opens, so a virtual list (used by the
	// other tabs) would mis-measure them. A plain scroller handles variable
	// heights, and reaching the bottom pulls the next page in.
	function handleScroll(event: Event) {
		const el = event.currentTarget as HTMLDivElement;
		const remaining = el.scrollHeight - el.scrollTop - el.clientHeight;

		// Paging now works with the search applied, since the server does the
		// filtering: there is no client-side subset that could go out of sync.
		if (remaining < 150 && hasMore && !loading) {
			void load(false);
		}
	}

	// Precomputed once per row so the sentence is not rebuilt on every keystroke.
	const decorated = $derived.by(() =>
		logs.map((log) => {
			const { message, category } = describeLog(log);

			const ms = getTimestampMs(log.created_at);

			return {
				log,
				message,
				category,
				actor: log.actor_name || log.actor_identifier || "Unknown",
				when: relativeTime(ms),
				exactWhen: absoluteTime(ms),
				details: buildDetails(log),
				ok: log.success === 1 || log.success === true,
			};
		}),
	);

	const summary = $derived.by(() => {
		const count = logs.length;
		const suffix = hasMore ? "+" : "";

		if (appliedSearch !== "") {
			return `${count}${suffix} result${count === 1 ? "" : "s"} for "${appliedSearch}"`;
		}

		return `${count}${suffix} action${count === 1 ? "" : "s"}`;
	});
</script>

<div class="top-bar">
	<div class="heading">
		<span class="players-title" tabindex="-1">{t("admin_logs", "Admin Logs")}</span>
		<span class="summary">{summary}</span>
	</div>

	<div class="logs-filters">
		<select bind:value={namespaceFilter} onchange={() => load(true)} tabindex="-1" class="logs-select">
			<option value="">{t("all_categories", "All categories")}</option>
			<option value="playerActions">{t("player_actions", "Player actions")}</option>
			<option value="serverManagement">{t("server_management", "Server management")}</option>
			<option value="moderation">{t("moderation", "Moderation")}</option>
		</select>

		<select bind:value={daysFilter} onchange={() => load(true)} tabindex="-1" class="logs-select">
			<option value={1}>{t("last_24h", "Last 24h")}</option>
			<option value={7}>{t("last_7_days", "Last 7 days")}</option>
			<option value={30}>{t("last_30_days", "Last 30 days")}</option>
		</select>

		<div class="search-box" tabindex="-1">
			<svg class="search-icon" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
				<path
					d="M10.8746 10.852L14 14M12.5556 6.77778C12.5556 9.96877 9.96877 12.5556 6.77778 12.5556C3.5868 12.5556 1 9.96877 1 6.77778C1 3.5868 3.5868 1 6.77778 1C9.96877 1 12.5556 3.5868 12.5556 6.77778Z"
					stroke="currentColor"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
				/>
			</svg>

			<input
				placeholder={t("search_logs", "Search admin, player or action...")}
				type="text"
				bind:value={search}
				oninput={onSearchInput}
				onkeydown={(e) => e.key === "Escape" && clearSearch()}
				tabindex="-1"
				class="search-input"
			/>

			{#if search !== ""}
				<button type="button" class="search-clear" tabindex="-1" onclick={clearSearch} aria-label="Clear search">×</button>
			{/if}
		</div>
	</div>
</div>

<div class="list-wrapper">
	{#if loading && logs.length === 0}
		<div class="spinner-wrapper">
			<div class="spinner"></div>
		</div>
	{:else if decorated.length > 0}
		<div class="scroller" onscroll={handleScroll}>
			<div class="feed">
			{#each decorated as row (row.log.id)}
				<div class="entry" class:denied={!row.ok}>
					<span class="marker {row.category}"></span>

					<div class="body">
						<p class="sentence">
							<span class="actor">{row.actor}</span>
							{row.message}
						</p>

						<div class="meta">
							<span class="chip {row.category}">{CATEGORY_LABELS[row.category]}</span>
							<span class="when" title={row.exactWhen}>{row.when}</span>
							{#if !row.ok}
								<span class="chip denied-chip">{row.log.error || t("failed", "Denied")}</span>
							{/if}

							<button type="button" class="details-btn" tabindex="-1" onclick={() => toggleDetails(row.log.id)}>
								{expanded.has(row.log.id) ? t("hide_details", "Hide details") : t("more_info", "More info")}
							</button>
						</div>

						{#if expanded.has(row.log.id)}
							<div class="details">
								<div class="detail">
									<span class="detail-label">When</span>
									<span class="detail-value">{row.exactWhen}</span>
								</div>
								{#each row.details as detail}
									<div class="detail">
										<span class="detail-label">{detail.label}</span>
										<span class="detail-value" class:mono={detail.mono}>{detail.value}</span>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				{/each}
			</div>

			{#if hasMore}
				<button type="button" class="load-more" tabindex="-1" onclick={() => load(false)} disabled={loading}>
					{loading ? t("loading", "Loading...") : t("load_more", "Load more")}
				</button>
			{/if}
		</div>
	{:else if loaded}
		<div class="empty">
			<p class="empty-title">{t("no_logs_found", "Nothing to show")}</p>
			{#if appliedSearch !== ""}
				<p class="empty-hint">No admin action matches "{appliedSearch}" over this period.</p>
			{:else}
				<p class="empty-hint">No admin action was recorded for this period.</p>
			{/if}
		</div>
	{/if}
</div>

<style>
	.heading {
		display: flex;
		flex-direction: column;
		gap: 0.1vh;
	}

	.summary {
		font-family: "Poppins";
		font-size: 1.15vh;
		color: #7d7d7d;
	}

	.logs-filters {
		display: flex;
		align-items: center;
		gap: 1vh;
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 0.7vh;
		background: #171717;
		border: 0.1vh solid #2b2b2b;
		border-radius: 0.6vh;
		padding: 0.65vh 0.9vh;
		color: #7d7d7d;
		transition: border-color 0.15s ease;
	}

	.search-box:focus-within {
		border-color: #fb9b04;
		color: #fb9b04;
	}

	.search-icon {
		width: 1.3vh;
		height: 1.3vh;
		flex-shrink: 0;
	}

	.search-input {
		all: unset;
		width: 18vh;
		font-family: "Poppins";
		font-size: 1.3vh;
		color: #f2f2f2;
	}

	.search-input::placeholder {
		color: #6a6a6a;
	}

	.search-clear {
		all: unset;
		cursor: pointer;
		font-size: 1.7vh;
		line-height: 1;
		color: #7d7d7d;
		padding: 0 0.2vh;
	}

	.search-clear:hover {
		color: #fb9b04;
	}

	.logs-select {
		background: #171717;
		color: #f2f2f2;
		border: 0.1vh solid #2b2b2b;
		border-radius: 0.6vh;
		padding: 0.7vh 0.9vh;
		font-family: "Poppins";
		font-size: 1.3vh;
		outline: none;
		cursor: pointer;
	}

	.logs-select:hover {
		border-color: #fb9b04;
	}

	.scroller {
		height: 100%;
		overflow-y: auto;
		overflow-x: hidden;
		padding-right: 0.6vh;
		scrollbar-width: thin;
		scrollbar-color: #333 transparent;
	}

	.scroller::-webkit-scrollbar {
		width: 0.6vh;
	}

	.scroller::-webkit-scrollbar-track {
		background: transparent;
	}

	.scroller::-webkit-scrollbar-thumb {
		background: #333;
		border-radius: 1vh;
	}

	.scroller::-webkit-scrollbar-thumb:hover {
		background: #fb9b04;
	}

	.feed {
		display: flex;
		flex-direction: column;
		gap: 0.5vh;
		padding: 0.5vh 0;
	}

	.entry {
		display: flex;
		align-items: flex-start;
		gap: 1.1vh;
		padding: 1.1vh 1.4vh;
		background: #141414;
		border-radius: 0.7vh;
		border-left: 0.3vh solid transparent;
	}

	.entry:hover {
		background: #191919;
	}

	.entry.denied {
		border-left-color: #e04f4f;
	}

	.marker {
		width: 0.8vh;
		height: 0.8vh;
		border-radius: 50%;
		margin-top: 0.55vh;
		flex-shrink: 0;
	}

	.marker.moderation {
		background: #e04f4f;
	}
	.marker.economy {
		background: #3fbf5f;
	}
	.marker.player {
		background: #fb9b04;
	}
	.marker.server {
		background: #4f9be0;
	}
	.marker.other {
		background: #8f8f8f;
	}

	.body {
		display: flex;
		flex-direction: column;
		gap: 0.4vh;
		min-width: 0;
		flex: 1;
	}

	.sentence {
		margin: 0;
		font-family: "Poppins";
		font-size: 1.4vh;
		font-weight: 400;
		color: #dcdcdc;
		line-height: 1.5;
		word-break: break-word;
	}

	.actor {
		font-weight: 600;
		color: #f2f2f2;
	}

	.meta {
		display: flex;
		align-items: center;
		gap: 0.8vh;
		flex-wrap: wrap;
	}

	.chip {
		font-family: "Poppins";
		font-size: 1.05vh;
		font-weight: 500;
		padding: 0.25vh 0.7vh;
		border-radius: 1vh;
		background: #232323;
		color: #b8b8b8;
	}

	.chip.moderation {
		color: #e88585;
	}
	.chip.economy {
		color: #7ed69a;
	}
	.chip.player {
		color: #fbc164;
	}
	.chip.server {
		color: #8ec2ef;
	}

	.denied-chip {
		background: #2a1616;
		color: #e88585;
	}

	.when {
		font-family: "Poppins";
		font-size: 1.15vh;
		color: #7d7d7d;
	}

	.details-btn {
		all: unset;
		font-family: "Poppins";
		font-size: 1.1vh;
		font-weight: 500;
		color: #7d7d7d;
		cursor: pointer;
		text-decoration: underline;
		text-underline-offset: 0.25vh;
	}

	.details-btn:hover {
		color: #fb9b04;
	}

	.details {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(22vh, 1fr));
		gap: 0.5vh 1.4vh;
		margin-top: 0.7vh;
		padding: 0.9vh 1.1vh;
		background: #101010;
		border-radius: 0.6vh;
	}

	.detail {
		display: flex;
		flex-direction: column;
		gap: 0.1vh;
		min-width: 0;
	}

	.detail-label {
		font-family: "Poppins";
		font-size: 1.05vh;
		color: #6f6f6f;
	}

	.detail-value {
		font-family: "Poppins";
		font-size: 1.2vh;
		color: #d0d0d0;
		word-break: break-word;
	}

	.detail-value.mono {
		font-family: monospace;
		font-size: 1.15vh;
		color: #b0b0b0;
	}

	.load-more {
		all: unset;
		display: block;
		margin: 1.4vh auto;
		padding: 0.8vh 2.2vh;
		border-radius: 0.6vh;
		background: #1c1c1c;
		color: #e2e2e2;
		font-family: "Poppins";
		font-size: 1.3vh;
		cursor: pointer;
		text-align: center;
	}

	.load-more:hover {
		background: #fb9b04;
		color: #101010;
	}

	.empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.5vh;
		padding: 6vh 0;
	}

	.empty-title {
		margin: 0;
		font-family: "Poppins";
		font-size: 1.6vh;
		font-weight: 500;
		color: #d0d0d0;
	}

	.empty-hint {
		margin: 0;
		font-family: "Poppins";
		font-size: 1.3vh;
		color: #7d7d7d;
	}
</style>

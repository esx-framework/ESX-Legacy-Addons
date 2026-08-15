<script lang="ts">
	import { uiState } from "$lib/shared/stores/user.svelte";
	import { server } from "$lib/shared/stores/server.svelte";
	import { t } from "$lib/shared/util/util";
	import { formatMoney } from "$lib/shared/util/formatter";
	import type { Player } from "../players/types/player";

	type ChartRow = {
		label: string;
		value: number;
		display: string;
		percent: number;
		color?: string;
	};

	function playerMoney(player: Player) {
		return (Number(player.cash) || 0) + (Number(player.bank) || 0) + (Number(player.alt_money) || 0);
	}

	function clampPercent(value: number) {
		if (!Number.isFinite(value)) return 0;
		return Math.max(0, Math.min(100, value));
	}

	function barStyle(percent: number, color = "#FB9B04") {
		return `--bar-width: ${clampPercent(percent).toFixed(2)}%; --bar-color: ${color};`;
	}

	function segmentStyle(percent: number, color: string) {
		return `width: ${clampPercent(percent).toFixed(2)}%; background: ${color};`;
	}

	const players = $derived(uiState.players ?? []);
	const onlineCount = $derived(server.currentPlayers ?? players.length);
	const maxPlayers = $derived(server.maxPlayers ?? 0);
	const availableSlots = $derived(Math.max(0, maxPlayers - onlineCount));
	const playerFill = $derived(maxPlayers > 0 ? Math.min(100, (onlineCount / maxPlayers) * 100) : 0);
	const totalCash = $derived(players.reduce((sum, player) => sum + (Number(player.cash) || 0), 0));
	const totalBank = $derived(players.reduce((sum, player) => sum + (Number(player.bank) || 0), 0));
	const totalBlack = $derived(players.reduce((sum, player) => sum + (Number(player.alt_money) || 0), 0));
	const totalMoney = $derived(totalCash + totalBank + totalBlack);
	const averageMoney = $derived(players.length > 0 ? Math.round(totalMoney / players.length) : 0);
	const averageCash = $derived(players.length > 0 ? Math.round(totalCash / players.length) : 0);
	const averageBank = $derived(players.length > 0 ? Math.round(totalBank / players.length) : 0);
	const averageBlack = $derived(players.length > 0 ? Math.round(totalBlack / players.length) : 0);
	const activeStaff = $derived(players.filter((player) => player.is_staff).length);
	const nonStaff = $derived(Math.max(0, players.length - activeStaff));
	const staffPercent = $derived(players.length > 0 ? (activeStaff / players.length) * 100 : 0);
	const averageHealth = $derived(players.length > 0 ? Math.round(players.reduce((sum, player) => sum + (Number(player.health) || 0), 0) / players.length) : 0);
	const averageArmor = $derived(players.length > 0 ? Math.round(players.reduce((sum, player) => sum + (Number(player.armor) || 0), 0) / players.length) : 0);
	const sortedMoney = $derived(players.map(playerMoney).sort((a, b) => a - b));
	const medianMoney = $derived.by(() => {
		if (sortedMoney.length === 0) return 0;
		const middle = Math.floor(sortedMoney.length / 2);
		return sortedMoney.length % 2 === 0 ? Math.round((sortedMoney[middle - 1] + sortedMoney[middle]) / 2) : sortedMoney[middle];
	});
	const richestMoney = $derived(sortedMoney.at(-1) ?? 0);
	const richestPlayer = $derived(players.reduce<Player | null>((richest, player) => (!richest || playerMoney(player) > playerMoney(richest) ? player : richest), null));

	const moneyBuckets = $derived<ChartRow[]>([
		{
			label: t("money"),
			value: totalCash,
			display: `$${formatMoney(totalCash)}`,
			percent: totalMoney > 0 ? (totalCash / totalMoney) * 100 : 0,
			color: "#FB9B04",
		},
		{
			label: t("bank_money"),
			value: totalBank,
			display: `$${formatMoney(totalBank)}`,
			percent: totalMoney > 0 ? (totalBank / totalMoney) * 100 : 0,
			color: "#4ADE80",
		},
		{
			label: t("black_money"),
			value: totalBlack,
			display: `$${formatMoney(totalBlack)}`,
			percent: totalMoney > 0 ? (totalBlack / totalMoney) * 100 : 0,
			color: "#F23F3F",
		},
	]);

	const averageMoneyRows = $derived<ChartRow[]>([
		{ label: t("money"), value: averageCash, display: `$${formatMoney(averageCash)}`, percent: averageMoney > 0 ? (averageCash / averageMoney) * 100 : 0, color: "#FB9B04" },
		{ label: t("bank_money"), value: averageBank, display: `$${formatMoney(averageBank)}`, percent: averageMoney > 0 ? (averageBank / averageMoney) * 100 : 0, color: "#4ADE80" },
		{ label: t("black_money"), value: averageBlack, display: `$${formatMoney(averageBlack)}`, percent: averageMoney > 0 ? (averageBlack / averageMoney) * 100 : 0, color: "#F23F3F" },
	]);

	const playerRows = $derived<ChartRow[]>([
		{ label: t("players"), value: onlineCount, display: `${onlineCount}/${maxPlayers}`, percent: playerFill, color: "#FB9B04" },
		{ label: t("available_slots"), value: availableSlots, display: String(availableSlots), percent: maxPlayers > 0 ? (availableSlots / maxPlayers) * 100 : 0, color: "#8B8B8B" },
	]);

	const healthRows = $derived<ChartRow[]>([
		{ label: t("avg_health"), value: averageHealth, display: `${averageHealth}/100`, percent: averageHealth, color: "#4ADE80" },
		{ label: t("avg_armor"), value: averageArmor, display: `${averageArmor}/100`, percent: averageArmor, color: "#60A5FA" },
	]);

	const staffRows = $derived<ChartRow[]>([
		{ label: t("active_staff"), value: activeStaff, display: String(activeStaff), percent: staffPercent, color: "#60A5FA" },
		{ label: t("non_staff"), value: nonStaff, display: String(nonStaff), percent: players.length > 0 ? (nonStaff / players.length) * 100 : 0, color: "#8B8B8B" },
	]);

	const economyRows = $derived<ChartRow[]>([
		{
			label: t("avg_money_per_player"),
			value: averageMoney,
			display: `$${formatMoney(averageMoney)}`,
			percent: richestMoney > 0 ? (averageMoney / richestMoney) * 100 : 0,
			color: "#FB9B04",
		},
		{
			label: t("median_money"),
			value: medianMoney,
			display: `$${formatMoney(medianMoney)}`,
			percent: richestMoney > 0 ? (medianMoney / richestMoney) * 100 : 0,
			color: "#4ADE80",
		},
		{
			label: t("richest_player"),
			value: richestMoney,
			display: richestPlayer ? `${richestPlayer.name} ($${formatMoney(richestMoney)})` : "-",
			percent: richestMoney > 0 ? 100 : 0,
			color: "#F23F3F",
		},
	]);

	const jobRows = $derived.by<ChartRow[]>(() => {
		const counts = new Map<string, number>();

		for (const player of players) {
			const job = player.job || "unknown";
			counts.set(job, (counts.get(job) ?? 0) + 1);
		}

		return [...counts.entries()]
			.sort((a, b) => b[1] - a[1])
			.slice(0, 5)
			.map(([label, value]) => ({
				label,
				value,
				display: String(value),
				percent: players.length > 0 ? (value / players.length) * 100 : 0,
				color: "#FB9B04",
			}));
	});

	const wealthRows = $derived.by<ChartRow[]>(() => {
		const ranges = [
			{ label: "< $10k", min: 0, max: 10000 },
			{ label: "$10k-$100k", min: 10000, max: 100000 },
			{ label: "$100k-$1m", min: 100000, max: 1000000 },
			{ label: "$1m+", min: 1000000, max: Number.POSITIVE_INFINITY },
		];

		return ranges.map((range) => {
			const value = players.filter((player) => {
				const money = (Number(player.cash) || 0) + (Number(player.bank) || 0) + (Number(player.alt_money) || 0);
				return money >= range.min && money < range.max;
			}).length;

			return {
				label: range.label,
				value,
				display: String(value),
				percent: players.length > 0 ? (value / players.length) * 100 : 0,
				color: "#FB9B04",
			};
		});
	});
</script>

<div class="dashboard-home">
	<header class="dashboard-header">
		<div>
			<div class="dashboard-title-row">
				<h2>{t("dashboard_home")}</h2>
				<span class="staff-badge">{t("active_staff")}: {activeStaff}</span>
			</div>
			<span>{t("dashboard_snapshot")}</span>
		</div>
	</header>

	<section class="metrics-grid">
		<div class="metric-panel">
			<span>{t("players")}</span>
			<strong>{onlineCount}/{maxPlayers}</strong>
			<div class="metric-track"><span style={barStyle(playerFill)}></span></div>
		</div>
		<div class="metric-panel">
			<span>{t("total_money")}</span>
			<strong>${formatMoney(totalMoney)}</strong>
		</div>
		<div class="metric-panel">
			<span>{t("avg_money_per_player")}</span>
			<strong>${formatMoney(averageMoney)}</strong>
		</div>
		<div class="metric-panel">
			<span>{t("avg_health")}</span>
			<strong>{averageHealth}/100</strong>
		</div>
		<div class="metric-panel">
			<span>{t("avg_armor")}</span>
			<strong>{averageArmor}/100</strong>
		</div>
	</section>

	<section class="dashboard-grid">
		<div class="chart-panel wide">
			<div class="chart-title">
				<h3>{t("player_counts")}</h3>
				<span>{onlineCount} online</span>
			</div>
			<div class="stacked-meter">
				<span class="meter-online" style={segmentStyle(playerFill, "#FB9B04")}></span>
				<span class="meter-empty" style={segmentStyle(100 - playerFill, "rgba(242, 242, 242, 0.16)")}></span>
			</div>
			{@render BarList(playerRows)}
		</div>

		<div class="chart-panel wide">
			<div class="chart-title">
				<h3>{t("money_distribution")}</h3>
				<span>${formatMoney(totalMoney)}</span>
			</div>
			<div class="stacked-meter">
				{#each moneyBuckets as bucket}
					<span style={segmentStyle(bucket.percent, bucket.color ?? "#FB9B04")}></span>
				{/each}
			</div>
			{@render BarList(moneyBuckets)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("economy_summary")}</h3>
				<span>{players.length} players</span>
			</div>
			{@render BarList(economyRows)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("avg_money_breakdown")}</h3>
				<span>${formatMoney(averageMoney)}</span>
			</div>
			{@render BarList(averageMoneyRows)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("player_condition")}</h3>
				<span>{players.length} sampled</span>
			</div>
			{@render BarList(healthRows)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("staff_overview")}</h3>
				<span>{Math.round(staffPercent)}%</span>
			</div>
			{@render BarList(staffRows)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("active_player_job_distribution")}</h3>
				<span>{players.length} players</span>
			</div>
			{@render BarList(jobRows)}
		</div>

		<div class="chart-panel">
			<div class="chart-title">
				<h3>{t("wealth_bands")}</h3>
				<span>{players.length} players</span>
			</div>
			{@render BarList(wealthRows)}
		</div>
	</section>
</div>

{#snippet BarList(rows: ChartRow[])}
	<div class="bar-list">
		{#each rows as row}
			<div class="bar-row">
				<span>{row.label}</span>
				<div class="bar-track"><i style={barStyle(row.percent, row.color)}></i></div>
				<strong>{row.display}</strong>
			</div>
		{/each}
	</div>
{/snippet}

<style>
	.dashboard-home {
		display: flex;
		flex-direction: column;
		gap: 1.2vh;
		height: 100%;
		max-height: 100%;
		min-height: 0;
		overflow-y: auto;
		overflow-x: hidden;
		padding-right: 0.4vh;
	}

	.dashboard-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1vh;
		padding-bottom: 1vh;
		border-bottom: 0.1vh solid #2e2e2c;
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
		font-size: 1.28vh;
	}

	.dashboard-header span,
	.chart-title span,
	.metric-panel span,
	.bar-row span {
		color: rgba(242, 242, 242, 0.58);
		font-size: 1.02vh;
	}

	.dashboard-title-row {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.8vh;
	}

	.staff-badge {
		display: inline-flex;
		align-items: center;
		min-height: 2.2vh;
		padding: 0 0.75vh;
		border: 0.1vh solid rgba(251, 155, 4, 0.65);
		border-radius: 0.28vh;
		background: rgba(251, 155, 4, 0.14);
		color: #fb9b04 !important;
		font-size: 1vh !important;
		font-weight: 600;
		white-space: nowrap;
	}

	.metrics-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(18vh, 1fr));
		gap: 0.8vh;
	}

	.metric-panel,
	.chart-panel {
		position: relative;
		box-sizing: border-box;
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		background: rgba(37, 37, 37, 0.35);
		transition:
			transform 0.16s ease,
			border-color 0.16s ease,
			background 0.16s ease,
			box-shadow 0.16s ease;
		will-change: transform;
	}

	.metric-panel:hover,
	.chart-panel:hover {
		transform: translateY(-0.22vh);
		border-color: rgba(251, 155, 4, 0.45);
		background: rgba(37, 37, 37, 0.52);
		box-shadow: 0 0.8vh 1.8vh rgba(0, 0, 0, 0.24);
	}

	.metric-panel {
		display: flex;
		min-height: 7.4vh;
		min-width: 0;
		flex-direction: column;
		justify-content: center;
		gap: 0.45vh;
		padding: 0.9vh;
	}

	.metric-panel strong {
		color: #f2f2f2;
		font-size: 1.48vh;
		font-weight: 600;
		line-height: 1.25;
		overflow-wrap: break-word;
	}

	.metric-track,
	.bar-track,
	.stacked-meter {
		overflow: hidden;
		border-radius: 0.28vh;
		background: rgba(242, 242, 242, 0.08);
	}

	.metric-track {
		height: 0.45vh;
	}

	.metric-track span,
	.bar-track i {
		display: block;
		height: 100%;
		border-radius: inherit;
		background: #fb9b04;
		transition: width 0.28s ease, background 0.18s ease;
	}

	.metric-track span {
		width: var(--bar-width);
		background: var(--bar-color);
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(36vh, 1fr));
		gap: 0.9vh;
		min-height: 0;
	}

	.chart-panel {
		min-height: 15.5vh;
		height: min-content;
		min-width: 0;
		padding: 1vh;
	}

	.chart-panel.wide {
		grid-column: span 1;
	}

	.chart-title {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: 1vh;
		margin-bottom: 0.9vh;
	}

	.chart-title h3,
	.chart-title span {
		min-width: 0;
		overflow-wrap: break-word;
	}

	.stacked-meter {
		display: flex;
		height: 0.75vh;
		margin-bottom: 0.9vh;
	}

	.stacked-meter span {
		display: block;
		height: 100%;
		transition: width 0.28s ease, filter 0.16s ease;
	}

	.chart-panel:hover .stacked-meter span,
	.metric-panel:hover .metric-track span {
		filter: brightness(1.18);
	}

	.meter-online {
		background: #fb9b04;
	}

	.meter-empty {
		background: rgba(242, 242, 242, 0.16);
	}

	.bar-list {
		display: flex;
		flex-direction: column;
		gap: 0.68vh;
	}

	.bar-row {
		display: grid;
		grid-template-columns: minmax(8vh, 0.85fr) minmax(7vh, 1fr) minmax(9vh, 0.9fr);
		align-items: center;
		gap: 0.7vh;
		min-height: 2.45vh;
		margin: 0 -0.35vh;
		padding: 0 0.35vh;
		border-radius: 0.35vh;
		transition: background 0.14s ease;
	}

	.bar-row:hover {
		background: rgba(251, 155, 4, 0.07);
	}

	.bar-row span {
		min-width: 0;
		overflow-wrap: break-word;
	}

	.bar-track {
		height: 0.58vh;
	}

	.bar-track i {
		width: var(--bar-width);
		background: var(--bar-color);
	}

	.bar-row strong {
		color: #f2f2f2;
		font-size: 1.02vh;
		text-align: right;
		line-height: 1.25;
		overflow-wrap: anywhere;
	}

	@media (prefers-reduced-motion: reduce) {
		.metric-panel,
		.chart-panel,
		.metric-track span,
		.bar-track i,
		.stacked-meter span,
		.bar-row {
			transition: none;
		}

		.metric-panel:hover,
		.chart-panel:hover {
			transform: none;
		}
	}
</style>

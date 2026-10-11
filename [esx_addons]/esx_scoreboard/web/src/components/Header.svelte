<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script>
  import { totalPlayers, activeActivityCount } from "../stores/scoreboard.js"

  let { serverName, maxPlayers, uptime, logoUrl } = $props()

  function formatUptime(seconds) {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = seconds % 60
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
  }
</script>

<header class="scoreboard-header">
  <div class="header-left">
    {#if logoUrl && /^https:\/\//.test(logoUrl)}
      <img src={logoUrl} alt="Server Logo" class="server-logo" />
    {:else}
      <img src="./esx-logo.png" alt="ESX Logo" class="server-logo" />
    {/if}
    <div class="server-info">
      <h1 class="server-name">{serverName}</h1>
      <span class="uptime">⏱️ {formatUptime(uptime)}</span>
    </div>
  </div>

  <div class="header-stats">
    <div class="stat-box">
      <span class="stat-value">{$totalPlayers}</span>
      <span class="stat-label">Players</span>
    </div>
    <div class="stat-divider"></div>
    <div class="stat-box">
      <span class="stat-value">{maxPlayers}</span>
      <span class="stat-label">Max</span>
    </div>
    <div class="stat-divider"></div>
    <div class="stat-box activities">
      <span class="stat-value">{$activeActivityCount}</span>
      <span class="stat-label">Active Events</span>
    </div>
  </div>
</header>

<style>
  .scoreboard-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 28px;
    background: linear-gradient(135deg, var(--dark-color) 0%, var(--darkest-color) 100%);
    border-bottom: 2px solid var(--brand-color);
    border-radius: 12px 12px 0 0;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .server-logo {
    width: 120px;
    height: 52px;
    object-fit: contain;
    flex-shrink: 0;
  }

  .server-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .server-name {
    font-size: 24px;
    font-weight: 700;
    color: var(--lightest-color);
    line-height: 1.2;
  }

  .uptime {
    font-size: 12px;
    color: var(--light-color);
    font-weight: 400;
  }

  .header-stats {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .stat-box {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    min-width: 60px;
  }

  .stat-value {
    font-size: 24px;
    font-weight: 700;
    color: var(--brand-color);
    line-height: 1;
  }

  .stat-label {
    font-size: 11px;
    color: var(--light-color);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .stat-divider {
    width: 1px;
    height: 36px;
    background: var(--mid-color);
  }

  .activities .stat-value {
    color: #EF4444;
  }
</style>

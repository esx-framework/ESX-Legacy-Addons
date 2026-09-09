<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script>
  let { type = "activity", label = "", location = "" } = $props()

  const activityConfig = {
    robbery: { icon: "💰", color: "#EF4444", defaultLabel: "Robbery" },
    heist: { icon: "🏦", color: "#DC2626", defaultLabel: "Heist" },
    drug: { icon: "💊", color: "#8B5CF6", defaultLabel: "Drug Sale" },
    race: { icon: "🏎️", color: "#F59E0B", defaultLabel: "Street Race" },
    hostage: { icon: "🚫", color: "#EC4899", defaultLabel: "Hostage" },
    shootout: { icon: "🔫", color: "#DC2626", defaultLabel: "Shootout" }
  }

  const safeType = $derived(String(type || "activity").toLowerCase())
  const config = $derived(activityConfig[safeType] || { icon: "⚡", color: "#FB9B04", defaultLabel: safeType })
  const displayLabel = $derived(label || config.defaultLabel)
</script>

<span class="activity-badge" style="background-color: {config.color}20; color: {config.color}; border: 1px solid {config.color}40;">
  <span class="icon">{config.icon}</span>
  <span class="text">{displayLabel}</span>
  {#if location}
    <span class="location">@ {location}</span>
  {/if}
</span>

<style>
  .activity-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 500;
    white-space: nowrap;
    animation: pulse 2s ease-in-out infinite;
  }

  .icon {
    font-size: 12px;
  }

  .text {
    font-weight: 600;
  }

  .location {
    opacity: 0.7;
    font-size: 10px;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
  }
</style>

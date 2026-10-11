<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import type { Component } from "svelte";

	const { content, icon } = $props<{ content: string; icon?: Component }>();
</script>

<div class="data-component">
	{#if icon}
		{@const Icon = icon}
		<Icon class="data-component-icon" />
	{/if}
	<span>{content}</span>
</div>

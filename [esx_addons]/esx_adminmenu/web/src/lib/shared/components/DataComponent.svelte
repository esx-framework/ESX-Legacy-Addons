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

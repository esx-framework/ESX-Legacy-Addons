<script lang="ts">
	import { notifications } from "../stores/notifications.svelte";
</script>

{#if notifications.items.length > 0}
	<div class="notifications" aria-live="polite" aria-atomic="true">
		{#each notifications.items as item (item.id)}
			<div class="notification" class:error={item.type === "error"} class:success={item.type === "success"} class:info={item.type === "info"}>
				<span>{item.message}</span>
				<button type="button" aria-label="Dismiss notification" onclick={() => notifications.dismiss(item.id)}>
					<svg viewBox="0 0 15 15" aria-hidden="true">
						<path
							fill-rule="evenodd"
							clip-rule="evenodd"
							d="M15 13.6187L13.6187 15L7.5 8.8716L1.38132 15L0 13.6187L6.1284 7.5L0 1.38132L1.38132 0L7.5 6.1284L13.6187 0L15 1.38132L8.8716 7.5L15 13.6187Z"
						/>
					</svg>
				</button>
			</div>
		{/each}
	</div>
{/if}

<script lang="ts">
	export type DropdownOption<T extends string | number = string> = {
		value: T;
		label: string;
	};

	const {
		value,
		options,
		onChange,
		disabled = false,
	}: {
		value: string | number;
		options: DropdownOption<string | number>[];
		onChange: (value: string | number) => void;
		disabled?: boolean;
	} = $props();

	let open = $state(false);

	const selected = $derived(options.find((option) => option.value === value) ?? options[0]);

	function select(value: string | number) {
		onChange(value);
		open = false;
	}
</script>

<svelte:window onclick={() => (open = false)} />

<div class="dropdown">
	<button
		type="button"
		class="dropdown-trigger"
		class:open
		disabled={disabled}
		aria-haspopup="listbox"
		aria-expanded={open}
		onclick={(event) => {
			event.stopPropagation();
			open = !open;
		}}
	>
		<span>{selected?.label ?? ""}</span>
		<svg class:open viewBox="0 0 10 6" aria-hidden="true">
			<path d="M1 1L5 5L9 1" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" />
		</svg>
	</button>

	{#if open}
		<div class="dropdown-menu" role="listbox" tabindex="-1" onclick={(event) => event.stopPropagation()} onkeydown={(event) => event.stopPropagation()}>
			{#each options as option}
				<button
					type="button"
					class="dropdown-item"
					class:selected={option.value === value}
					role="option"
					aria-selected={option.value === value}
					onclick={() => select(option.value)}
				>
					{option.label}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.dropdown {
		position: relative;
		width: 100%;
		min-width: 0;
	}

	.dropdown-trigger {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.6vh;
		width: 100%;
		height: 3.4vh;
		box-sizing: border-box;
		padding: 0 0.9vh;
		border: 0.1vh solid #2E2E2C;
		border-radius: 0.4vh;
		background: rgba(37, 37, 37, 0.6);
		color: #F2F2F2;
		font-family: "Poppins", sans-serif;
		font-size: 1.12vh;
		cursor: pointer;
	}

	.dropdown-trigger:hover,
	.dropdown-trigger.open {
		border-color: rgba(251, 155, 4, 0.65);
	}

	.dropdown-trigger:disabled {
		cursor: default;
		opacity: 0.55;
	}

	.dropdown-trigger span {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.dropdown-trigger svg {
		width: 0.9vh;
		height: 0.6vh;
		flex-shrink: 0;
		transition: transform 0.16s ease, color 0.16s ease;
	}

	.dropdown-trigger svg.open {
		color: #FB9B04;
		transform: rotate(180deg);
	}

	.dropdown-menu {
		position: absolute;
		left: 0;
		right: 0;
		top: calc(100% + 0.4vh);
		display: flex;
		flex-direction: column;
		max-height: 22vh;
		overflow-y: auto;
		border: 0.1vh solid #2E2E2C;
		border-radius: 0.5vh;
		background: #1A1A1A;
		box-shadow: 0 1vh 2vh rgba(0, 0, 0, 0.35);
		z-index: 20;
	}

	.dropdown-item {
		all: unset;
		box-sizing: border-box;
		width: 100%;
		padding: 0.65vh 0.9vh;
		color: #F2F2F2;
		font-family: "Poppins", sans-serif;
		font-size: 1.08vh;
		cursor: pointer;
	}

	.dropdown-item:hover,
	.dropdown-item.selected {
		background: rgba(251, 155, 4, 0.14);
		color: #FB9B04;
	}
</style>

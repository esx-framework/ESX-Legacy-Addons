<script lang="ts">
	const { value, min, onChange } = $props<{
		value: string;
		min: string;
		onChange: (value: string) => void;
	}>();

	let visibleYear = $state(new Date().getFullYear());
	let visibleMonth = $state(new Date().getMonth());

	const monthFormatter = new Intl.DateTimeFormat(undefined, {
		month: "long",
		year: "numeric",
	});

	const weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

	function toDateValue(date: Date) {
		const year = date.getFullYear();
		const month = String(date.getMonth() + 1).padStart(2, "0");
		const day = String(date.getDate()).padStart(2, "0");

		return `${year}-${month}-${day}`;
	}

	function fromDateValue(dateValue: string) {
		return new Date(`${dateValue}T00:00:00`);
	}

	const minTime = $derived(fromDateValue(min).getTime());
	const monthLabel = $derived(monthFormatter.format(new Date(visibleYear, visibleMonth, 1)));

	const days = $derived.by(() => {
		const first = new Date(visibleYear, visibleMonth, 1);
		const start = new Date(first);
		const mondayOffset = (first.getDay() + 6) % 7;
		start.setDate(first.getDate() - mondayOffset);

		return Array.from({ length: 42 }, (_, index) => {
			const date = new Date(start);
			date.setDate(start.getDate() + index);

			const dateValue = toDateValue(date);

			return {
				key: dateValue,
				value: dateValue,
				label: date.getDate(),
				inMonth: date.getMonth() === visibleMonth,
				selected: dateValue === value,
				disabled: date.getTime() < minTime,
			};
		});
	});

	$effect(() => {
		if (!value) return;

		const date = fromDateValue(value);
		visibleYear = date.getFullYear();
		visibleMonth = date.getMonth();
	});

	function changeMonth(delta: number) {
		const next = new Date(visibleYear, visibleMonth + delta, 1);
		visibleYear = next.getFullYear();
		visibleMonth = next.getMonth();
	}
</script>

<div class="date-picker">
	<div class="date-picker-header">
		<button type="button" aria-label="Previous month" onclick={() => changeMonth(-1)}>
			<svg viewBox="0 0 10 10" aria-hidden="true">
				<path d="M6.7 1.1 2.8 5l3.9 3.9-.9.9L1 5 5.8.2l.9.9Z" />
			</svg>
		</button>
		<span>{monthLabel}</span>
		<button type="button" aria-label="Next month" onclick={() => changeMonth(1)}>
			<svg viewBox="0 0 10 10" aria-hidden="true">
				<path d="m3.3 1.1.9-.9L9 5 4.2 9.8l-.9-.9L7.2 5 3.3 1.1Z" />
			</svg>
		</button>
	</div>

	<div class="date-picker-weekdays">
		{#each weekdays as day}
			<span>{day}</span>
		{/each}
	</div>

	<div class="date-picker-grid">
		{#each days as day (day.key)}
			<button
				type="button"
				class:muted={!day.inMonth}
				class:selected={day.selected}
				disabled={day.disabled}
				onclick={() => onChange(day.value)}
			>
				{day.label}
			</button>
		{/each}
	</div>
</div>

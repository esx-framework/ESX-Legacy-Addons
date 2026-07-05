export class CurrentPageStore {
	value = $state("dashboard_home");

	set(value: string) {
		this.value = value;
	}
}

export const currentPage = new CurrentPageStore();

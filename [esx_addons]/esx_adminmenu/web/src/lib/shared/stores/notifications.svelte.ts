export type NotificationType = "error" | "success" | "info";

export type NotificationItem = {
	id: number;
	type: NotificationType;
	message: string;
};

const DEFAULT_TTL = 4500;

export class NotificationStore {
	items = $state<NotificationItem[]>([]);
	#nextId = 1;

	push(message: string, type: NotificationType = "error", ttl = DEFAULT_TTL) {
		const item = {
			id: this.#nextId++,
			type,
			message,
		};

		this.items = [...this.items, item];

		if (ttl > 0) {
			window.setTimeout(() => this.dismiss(item.id), ttl);
		}
	}

	error(message: string) {
		this.push(message, "error");
	}

	success(message: string) {
		this.push(message, "success");
	}

	info(message: string) {
		this.push(message, "info");
	}

	dismiss(id: number) {
		this.items = this.items.filter((item) => item.id !== id);
	}
}

export const notifications = new NotificationStore();

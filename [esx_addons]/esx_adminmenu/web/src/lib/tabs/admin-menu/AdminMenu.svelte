<script lang="ts">
    import { tick } from "svelte";
    import { fetchNui } from "$lib/shared/nui/fetchNUI";
    import type { NuiSuccess } from "$lib/shared/nui/admin";
    import { uiState } from "$lib/shared/stores/user.svelte";
    import { notifications } from "$lib/shared/stores/notifications.svelte";
    import { t } from "$lib/shared/util/util";
    import {
        adminMenuCategories,
        createAdminMenuPages,
        defaultAdminMenuPage,
        type AdminMenuItem,
    } from "./adminMenuConfig";
    import {
        AdminMenuValuesState,
        type AdminMenuValueKey,
    } from "./adminMenuValues.svelte";

    type ActionResponse = NuiSuccess & {
        active?: boolean;
        value?: string;
    };

    type SelectionArea = "controls" | "categories" | "items";

    let busyAction = $state<string | null>(null);
    let currentPageId = $state(defaultAdminMenuPage);
    let selectedArea = $state<SelectionArea>("items");
    let selectedControlIndex = $state(0);
    let selectedCategoryIndex = $state(0);
    let selectedIndex = $state(0);
    let categoriesEl: HTMLDivElement | null = $state(null);
    let actionsEl: HTMLDivElement | null = $state(null);
    let values = new AdminMenuValuesState(uiState.vehicleConfig);
    let lastVehicleConfig = uiState.vehicleConfig;
    let inputRefs = new Map<string, HTMLInputElement>();
    let inputFocusActive = false;

    const menuKeys = new Set([
        "ArrowUp",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        "Enter",
        "Backspace",
        "Tab",
    ]);
    const pages = $derived(createAdminMenuPages(uiState.vehicleConfig));
    const currentPage = $derived(
        pages[currentPageId] ?? pages[defaultAdminMenuPage] ?? pages.root,
    );
    const currentItems = $derived.by<AdminMenuItem[]>(() => {
        if (!currentPage.parentPage) return currentPage.items;

        return [
            {
                type: "back",
                id: "back",
                labelKey: "back",
                page: currentPage.parentPage,
            },
            ...currentPage.items,
        ];
    });
    const activeCategoryId = $derived(
        currentPage.categoryId ??
            adminMenuCategories.find(
                (category) => category.page === currentPage.id,
            )?.id ??
            adminMenuCategories[0]?.id ??
            "",
    );
    const activeCategoryIndex = $derived(
        Math.max(
            0,
            adminMenuCategories.findIndex(
                (category) => category.id === activeCategoryId,
            ),
        ),
    );
    const selectableItems = $derived(
        currentItems.filter((item) => item.type !== "section"),
    );
    const renderItems = $derived.by(() => {
        let index = -1;
        return currentItems.map((item) => {
            if (item.type !== "section") index += 1;
            return {
                item,
                selectableIndex: item.type === "section" ? -1 : index,
            };
        });
    });

    function registerInput(node: HTMLInputElement, id: string) {
        inputRefs.set(id, node);

        return {
            destroy() {
                inputRefs.delete(id);
            },
        };
    }

    function itemValue(item: AdminMenuItem) {
        if (
            item.type !== "option" &&
            item.type !== "toggle" &&
            item.type !== "input"
        )
            return "";
        const value = values.get(item.valueKey);

        if (item.type === "toggle") {
            return value ? t("on") : t("off");
        }

        if (item.type === "option") {
            return (
                item.options?.find((option) => option.value === value)?.label ??
                String(value)
            );
        }

        return String(value ?? "");
    }

    function clampSelection() {
        selectedIndex = Math.max(
            0,
            Math.min(selectedIndex, Math.max(0, selectableItems.length - 1)),
        );
    }

    function clampCategorySelection() {
        selectedCategoryIndex = Math.max(
            0,
            Math.min(
                selectedCategoryIndex,
                Math.max(0, adminMenuCategories.length - 1),
            ),
        );
    }

    function setPage(
        pageId: string,
        area: SelectionArea = "items",
        focusFirstInput = true,
    ) {
        currentPageId = pages[pageId] ? pageId : defaultAdminMenuPage;
        selectedArea = area;
        selectedIndex = 0;

        const page = pages[currentPageId];
        const firstInputIndex =
            page?.items.findIndex((item) => item.type === "input") ?? -1;
        const firstInput =
            firstInputIndex >= 0 ? page?.items[firstInputIndex] : null;
        if (focusFirstInput && firstInput?.type === "input") {
            selectedIndex = firstInputIndex + (page?.parentPage ? 1 : 0);
            void tick().then(() => focusInput(firstInput.id));
        }
    }

    async function navigateToPage(
        pageId: string,
        area: SelectionArea = "items",
        focusFirstInput = true,
    ) {
        await releaseFocusedInput();
        setPage(pageId, area, focusFirstInput);
    }

    async function navigateCategory(
        direction: -1 | 0 | 1,
        area: SelectionArea = "categories",
    ) {
        if (adminMenuCategories.length === 0) return;

        selectedCategoryIndex =
            (selectedCategoryIndex + direction + adminMenuCategories.length) %
            adminMenuCategories.length;
        clampCategorySelection();

        const category = adminMenuCategories[selectedCategoryIndex];
        if (category) {
            await navigateToPage(category.page, area, area !== "categories");
        }
    }

    async function setInputFocus(enabled: boolean) {
        if (inputFocusActive === enabled) return;

        inputFocusActive = enabled;
        await fetchNui<NuiSuccess>("adminMenu:setInputFocus", { enabled });
    }

    async function focusInput(id: string) {
        const input = inputRefs.get(id);
        if (!input) return;

        await setInputFocus(true);
        input.focus();
        input.select();
    }

    async function blurInput(event?: Event) {
        (event?.currentTarget as HTMLInputElement | undefined)?.blur();
        await setInputFocus(false);
    }

    function getFocusedInput() {
        const active = document.activeElement;
        if (!(active instanceof HTMLInputElement)) return null;

        for (const input of inputRefs.values()) {
            if (input === active) return input;
        }

        return null;
    }

    async function releaseFocusedInput() {
        const input = getFocusedInput();
        if (!input) return false;

        input.blur();
        await setInputFocus(false);
        return true;
    }

    function updateValue(
        key: AdminMenuValueKey,
        value: string | number | boolean,
    ) {
        values.set(key, value);
    }

    function isEditableTarget(target: EventTarget | null) {
        if (!(target instanceof HTMLElement)) return false;

        return (
            target.isContentEditable ||
            target instanceof HTMLInputElement ||
            target instanceof HTMLTextAreaElement ||
            target instanceof HTMLSelectElement
        );
    }

    async function runItemEvent(item: AdminMenuItem) {
        if (!("event" in item) || !item.event || busyAction) return null;

        busyAction = item.id;
        const payload = item.payload?.(values) ?? {};
        const res = await fetchNui<ActionResponse>(item.event, payload);

        if (res?.success) {
            if (item.id === "maxPerformance") {
                values.applyMaxPerformance();
            }

            if ("badge" in item && item.badge === "toggle") {
                uiState.setAdminMenuState(item.id, res.active ?? false);
            }

            if ("badge" in item && item.badge === "value" && res.value) {
                uiState.setAdminMenuBadge(item.id, res.value);
            }

            if (item.type === "action" && (!("badge" in item) || !item.badge)) {
                notifications.success(t(item.labelKey));
            }
        }

        busyAction = null;
        return res;
    }

    async function adjustItem(item: AdminMenuItem, direction: -1 | 1) {
        if (item.type === "action" && item.badge === "toggle") {
            await runItemEvent(item);
            return;
        }

        if (item.type === "option") {
            const options = item.options ?? [];
            if (options.length === 0) return;

            const current = options.findIndex(
                (option) => option.value === values.get(item.valueKey),
            );
            const next =
                (current + direction + options.length) % options.length;
            updateValue(item.valueKey, options[next].value);

            if (item.event) {
                await tick();
                await runItemEvent(item);
            }
        }

        if (item.type === "toggle") {
            updateValue(item.valueKey, !values.get(item.valueKey));

            if (item.event) {
                await tick();
                await runItemEvent(item);
            }
        }
    }

    async function executeItem(item: AdminMenuItem) {
        if (item.type === "page" || item.type === "back") {
            await navigateToPage(item.page);
            return;
        }

        if (item.type === "input") {
            await focusInput(item.id);
            return;
        }

        if (item.type === "option") {
            return;
        }

        if (item.type === "toggle") {
            await adjustItem(item, 1);
            return;
        }

        if (item.type === "action") {
            await runItemEvent(item);
        }
    }

    async function executeControl() {
        if (selectedControlIndex === 0) {
            await openDashboard();
            return;
        }

        await closeMenu();
    }

    async function submitInput(
        item: Extract<AdminMenuItem, { type: "input" }>,
        event?: Event,
    ) {
        await blurInput(event);

        if (item.event) {
            await runItemEvent(item);
        }
    }

    async function openDashboard() {
        if (busyAction) return;

        busyAction = "dashboard";
        const res = await fetchNui<NuiSuccess>("openDashboard");

        if (res === null || res.success) {
            uiState.openDashboard(uiState.players ?? []);
        }

        busyAction = null;
    }

    async function closeMenu() {
        const res = await fetchNui<NuiSuccess>("releaseFocus", {
            release: true,
        });

        if (res === null || res.success) {
            uiState.close();
        }
    }

    async function handleMenuKey(key: string, shiftKey = false) {
        if (!uiState.visible || uiState.mode !== "menu") return;

        if (getFocusedInput()) {
            if (key === "Tab") {
                await releaseFocusedInput();
            } else if (key === "ArrowUp" || key === "ArrowDown") {
                await releaseFocusedInput();
            } else if (key === "Enter" || key === "Escape") {
                await releaseFocusedInput();
                return;
            } else {
                return;
            }
        }

        if (key === "Tab") {
            selectedCategoryIndex =
                selectedArea === "categories"
                    ? selectedCategoryIndex
                    : activeCategoryIndex;
            selectedArea = "categories";
            await navigateCategory(shiftKey ? -1 : 1, "categories");
        } else if (selectedArea === "controls") {
            if (key === "ArrowLeft" || key === "ArrowRight") {
                selectedControlIndex = selectedControlIndex === 0 ? 1 : 0;
            } else if (key === "ArrowDown") {
                selectedArea = "items";
                selectedIndex = 0;
                clampSelection();
            } else if (key === "Enter") {
                await executeControl();
            } else if (key === "Backspace") {
                await closeMenu();
            }
        } else if (selectedArea === "categories") {
            if (key === "ArrowLeft" || key === "ArrowRight") {
                await navigateCategory(
                    key === "ArrowLeft" ? -1 : 1,
                    "categories",
                );
            } else if (key === "ArrowDown") {
                selectedArea = "items";
                selectedIndex = 0;
                clampSelection();
            } else if (key === "ArrowUp") {
                selectedArea = "items";
                selectedIndex = selectableItems.length - 1;
                clampSelection();
            } else if (key === "Enter") {
                await navigateCategory(0, "items");
            } else if (key === "Backspace") {
                if (currentPage.parentPage) {
                    await navigateToPage(currentPage.parentPage);
                } else {
                    selectedArea = "controls";
                    selectedControlIndex = 0;
                }
            }
        } else if (key === "ArrowUp") {
            if (selectedIndex <= 0) {
                selectedArea = "categories";
                selectedCategoryIndex = activeCategoryIndex;
            } else {
                selectedIndex -= 1;
                clampSelection();
            }
        } else if (key === "ArrowDown") {
            selectedIndex =
                selectedIndex >= selectableItems.length - 1
                    ? 0
                    : selectedIndex + 1;
            clampSelection();
        } else if (key === "ArrowLeft" || key === "ArrowRight") {
            const item = selectableItems[selectedIndex];
            if (item) await adjustItem(item, key === "ArrowLeft" ? -1 : 1);
        } else if (key === "Enter") {
            const item = selectableItems[selectedIndex];
            if (item) await executeItem(item);
        } else if (key === "Backspace") {
            if (currentPage.parentPage) {
                await navigateToPage(currentPage.parentPage);
            } else {
                selectedArea = "controls";
                selectedControlIndex = 0;
            }
        }

        await tick();
        const selected =
            selectedArea === "categories"
                ? categoriesEl?.querySelector("button.selected")
                : actionsEl?.querySelector(
                      "button.selected, .admin-menu-input-row.selected",
                  );
        selected?.scrollIntoView({ block: "nearest" });
    }

    $effect(() => {
        if (uiState.vehicleConfig !== lastVehicleConfig) {
            lastVehicleConfig = uiState.vehicleConfig;
            values.reset(uiState.vehicleConfig);
        }
    });

    $effect(() => {
        if (selectedArea !== "categories") {
            selectedCategoryIndex = activeCategoryIndex;
        }
    });

    $effect(() => {
        const handleKeyDown = (event: KeyboardEvent) => {
            if (!uiState.visible || uiState.mode !== "menu") return;
            if (!menuKeys.has(event.key)) return;
            if (event.key !== "Tab" && isEditableTarget(event.target)) return;

            event.preventDefault();
            void handleMenuKey(event.key, event.shiftKey);
        };

        window.addEventListener("keydown", handleKeyDown);

        return () => {
            window.removeEventListener("keydown", handleKeyDown);
        };
    });
</script>

<aside
    class="admin-menu-panel"
    aria-label={t("quick_admin_menu")}
>
    <div class="admin-menu-header">
        <div class="admin-menu-heading">
            <span class="admin-menu-title">{t(currentPage.titleKey)}</span>
            <span class="admin-menu-subtitle">{t(currentPage.subtitleKey)}</span
            >
        </div>
        <div class="admin-menu-controls">
            <button
                class="admin-menu-dashboard"
                class:selected={selectedArea === "controls" &&
                    selectedControlIndex === 0}
                type="button"
                aria-label={t("open_admin_dashboard")}
                onclick={() => {
                    selectedArea = "controls";
                    selectedControlIndex = 0;
                    void openDashboard();
                }}
            >
                <svg viewBox="0 0 20 20" aria-hidden="true">
                    <path
                        d="M3 4.5A1.5 1.5 0 0 1 4.5 3h3A1.5 1.5 0 0 1 9 4.5v3A1.5 1.5 0 0 1 7.5 9h-3A1.5 1.5 0 0 1 3 7.5v-3Zm8 0A1.5 1.5 0 0 1 12.5 3h3A1.5 1.5 0 0 1 17 4.5v3A1.5 1.5 0 0 1 15.5 9h-3A1.5 1.5 0 0 1 11 7.5v-3Zm-8 8A1.5 1.5 0 0 1 4.5 11h3A1.5 1.5 0 0 1 9 12.5v3A1.5 1.5 0 0 1 7.5 17h-3A1.5 1.5 0 0 1 3 15.5v-3Zm8 0a1.5 1.5 0 0 1 1.5-1.5h3a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1-1.5 1.5h-3a1.5 1.5 0 0 1-1.5-1.5v-3Z"
                    />
                </svg>
            </button>
            <button
                class="admin-menu-close"
                class:selected={selectedArea === "controls" &&
                    selectedControlIndex === 1}
                type="button"
                aria-label="Close admin menu"
                onclick={() => {
                    selectedArea = "controls";
                    selectedControlIndex = 1;
                    void closeMenu();
                }}
            >
                <svg viewBox="0 0 15 15" aria-hidden="true">
                    <path
                        fill-rule="evenodd"
                        clip-rule="evenodd"
                        d="M15 13.6187L13.6187 15L7.5 8.8716L1.38132 15L0 13.6187L6.1284 7.5L0 1.38132L1.38132 0L7.5 6.1284L13.6187 0L15 1.38132L8.8716 7.5L15 13.6187Z"
                    />
                </svg>
            </button>
        </div>
    </div>

    <div class="admin-menu-categories" bind:this={categoriesEl} aria-label="Admin menu categories">
        {#each adminMenuCategories as category, index}
            <button
                type="button"
                class:active={activeCategoryId === category.id}
                class:selected={selectedArea === "categories" &&
                    selectedCategoryIndex === index}
                onclick={() => {
                    selectedCategoryIndex = index;
                    void navigateToPage(category.page);
                }}
            >
                {t(category.labelKey)}
            </button>
        {/each}
    </div>

    <div class="admin-menu-actions" bind:this={actionsEl}>
        {#each renderItems as entry}
            {@const item = entry.item}
            {#if item.type === "section"}
                <div class="admin-menu-section-label">{t(item.labelKey)}</div>
            {:else if item.type === "input"}
                <label
                    class:selected={selectedArea === "items" &&
                        entry.selectableIndex === selectedIndex}
                    class="admin-menu-input-row"
                >
                    <span>{t(item.labelKey)}</span>
                    <input
                        use:registerInput={item.id}
                        value={String(values.get(item.valueKey) ?? "")}
                        placeholder={item.placeholder}
                        oninput={(event) =>
                            updateValue(
                                item.valueKey,
                                (event.currentTarget as HTMLInputElement).value,
                            )}
                        onfocus={() => setInputFocus(true)}
                        onblur={blurInput}
                        onkeydown={(event) => {
                            if (
                                event.key === "Enter" ||
                                event.key === "Escape"
                            ) {
                                event.preventDefault();
                                event.stopPropagation();
                                if (event.key === "Enter") {
                                    void submitInput(item, event);
                                } else {
                                    void blurInput(event);
                                }
                            } else if (
                                event.key === "ArrowUp" ||
                                event.key === "ArrowDown"
                            ) {
                                const key = event.key;
                                event.preventDefault();
                                event.stopPropagation();
                                void (async () => {
                                    await blurInput(event);
                                    await handleMenuKey(key);
                                })();
                            }
                        }}
                    />
                </label>
            {:else}
                <button
                    type="button"
                    class:selected={selectedArea === "items" &&
                        entry.selectableIndex === selectedIndex}
                    class:admin-menu-back={item.type === "back"}
                    class:active={(item.type === "action" &&
                        item.badge === "toggle" &&
                        uiState.adminMenuStates[item.id] === true) ||
                        (item.type === "toggle" &&
                            values.get(item.valueKey) === true)}
                    disabled={busyAction !== null}
                    onclick={() => {
                        selectedIndex = entry.selectableIndex;
                        void executeItem(item);
                    }}
                >
                    <span>{t(item.labelKey)}</span>
                    {#if item.type === "back"}
                        <small class="value-badge page-badge">&lt;</small>
                    {:else if item.type === "page"}
                        <small class="value-badge page-badge">&gt;</small>
                    {:else if item.type === "action" && item.badge === "toggle"}
                        <small
                            >{uiState.adminMenuStates[item.id]
                                ? t("on")
                                : t("off")}</small
                        >
                    {:else if item.type === "action" && item.badge === "value" && uiState.adminMenuBadges[item.id]}
                        <small class="value-badge"
                            >{uiState.adminMenuBadges[item.id]}</small
                        >
                    {:else if item.type === "toggle"}
                        <small>{itemValue(item)}</small>
                    {:else if item.type === "option"}
                        <small class="value-badge selector-badge">
                            <span class="selector-arrow">&lt;</span>
                            <span>{itemValue(item)}</span>
                            <span class="selector-arrow">&gt;</span>
                        </small>
                    {/if}
                </button>
            {/if}
        {/each}
    </div>

    <div class="admin-menu-footer">
        {currentPage.parentPage
            ? t("quick_menu_edit_hint")
            : t("quick_menu_hint")}
    </div>
</aside>

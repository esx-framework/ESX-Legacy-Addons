/**
 * Event Handlers Module
 * @module EventHandlers
 * @description Efficient event handling using event delegation pattern
 */

/**
 * Event Delegation Handler
 * Centralized event management for UI interactions
 * @returns {Object} Public API for event handling
 */
const EventHandlers = (() => {
    let clickController = null;
    let keydownController = null;

    /**
     * Handle close button click
     * @returns {void}
     */
    const handleClose = () => {
        NUIBridge.close();
    };

    /**
     * Handle custom dropdown toggle
     * @param {HTMLElement} trigger - Dropdown trigger element
     * @returns {void}
     */
    const handleDropdownToggle = (trigger) => {
        const dropdown = trigger.closest('.custom-select');
        if (!dropdown) return;

        const card = dropdown.closest('.zone-card');

        document.querySelectorAll('.custom-select.active').forEach(el => {
            if (el !== dropdown) {
                el.classList.remove('active');
                const otherCard = el.closest('.zone-card');
                if (otherCard) otherCard.classList.remove('dropdown-active');
            }
        });

        dropdown.classList.toggle('active');

        if (card) {
            if (dropdown.classList.contains('active')) {
                card.classList.add('dropdown-active');
            } else {
                card.classList.remove('dropdown-active');
            }
        }
    };

    /**
     * Handle custom dropdown option selection
     * In performance mode, skips icon animations and uses instant text updates
     * @param {HTMLElement} option - Selected option element
     * @returns {void}
     */
    const handleOptionSelect = (option) => {
        const dropdown = option.closest('.custom-select');
        if (!dropdown) return;

        const value = option.dataset.value;
        const currentValue = dropdown.dataset.value;

        if (value === currentValue) {
            dropdown.classList.remove('active');
            return;
        }

        const trigger = dropdown.querySelector('.custom-select-trigger');
        const textElement = trigger?.querySelector('span');

        const weatherName = Helpers.getWeatherDisplayName(value, State.weatherTypes);
        const iconConfig = UIController.getWeatherIcon(value);

        // In performance mode, use instant updates without animations
        if (State.performanceMode) {
            // Instant text update
            if (textElement) {
                textElement.textContent = weatherName;
            }

            // Instant icon update
            if (trigger) {
                const currentIcon = trigger.querySelector('svg') || trigger.querySelector('i');
                if (currentIcon) {
                    const newIcon = document.createElement('i');
                    newIcon.setAttribute('data-lucide', iconConfig.icon);
                    trigger.replaceChild(newIcon, currentIcon);
                    Helpers.initLucideIcons(trigger);
                }
            }
        } else {
            // Normal mode with animations
            if (textElement) {
                textElement.classList.add('slide-out');

                setTimeout(() => {
                    textElement.textContent = weatherName;
                    textElement.classList.remove('slide-out');
                    textElement.classList.add('slide-in');

                    setTimeout(() => {
                        textElement.classList.remove('slide-in');
                    }, AnimationTimings.SLIDE_ANIMATION);
                }, AnimationTimings.SLIDE_ANIMATION);
            }

            if (trigger) {
                const currentIcon = trigger.querySelector('svg') || trigger.querySelector('i');

                if (currentIcon) {
                    currentIcon.classList.add('icon-fade');

                    setTimeout(() => {
                        currentIcon.remove();

                        const newIcon = document.createElement('i');
                        newIcon.setAttribute('data-lucide', iconConfig.icon);
                        newIcon.style.opacity = '0';
                        newIcon.style.transform = 'scale(0.8)';

                        trigger.insertBefore(newIcon, trigger.firstChild);

                        Helpers.initLucideIcons(trigger);

                        setTimeout(() => {
                            const renderedIcon = trigger.querySelector('svg') || trigger.querySelector('i');
                            if (renderedIcon) {
                                renderedIcon.style.opacity = '1';
                                renderedIcon.style.transform = 'scale(1)';
                            }
                        }, AnimationTimings.ICON_FADE_IN);
                    }, AnimationTimings.ICON_FADE_OUT);
                }
            }
        }

        dropdown.dataset.value = value;

        dropdown.querySelectorAll('.custom-option').forEach(opt => {
            opt.classList.remove('selected');
        });
        option.classList.add('selected');

        dropdown.classList.remove('active');
    };

    /**
     * Handle apply weather button click
     * @param {HTMLElement} button - Clicked button element
     * @returns {void}
     */
    const handleApplyWeather = async (button) => {
        const zoneName = button.dataset.zone;
        if (!zoneName) return;

        const select = button.closest('.zone-card-body').querySelector('.custom-select');
        if (!select) return;

        const weatherType = select.dataset.value;

        button.disabled = true;
        button.textContent = UIText.BUTTON_APPLYING;

        await NUIBridge.setZoneWeather(zoneName, weatherType);

        setTimeout(() => {
            button.disabled = false;
            button.textContent = UIText.BUTTON_APPLY;
        }, AnimationTimings.BUTTON_FEEDBACK);
    };

    /**
     * Close all open dropdowns
     * @returns {void}
     */
    const closeAllDropdowns = () => {
        document.querySelectorAll('.custom-select.active').forEach(el => {
            el.classList.remove('active');
            const card = el.closest('.zone-card');
            if (card) card.classList.remove('dropdown-active');
        });
    };

    /**
     * Handle performance mode toggle button click
     * @returns {void}
     */
    const handlePerformanceModeToggle = () => {
        UIController.togglePerformanceMode();
    };

    /**
     * Global click handler with delegation
     * @param {Event} event - Click event
     * @returns {void}
     */
    const handleGlobalClick = (event) => {
        const target = event.target;

        // Performance mode toggle button
        if (target.matches('#perfToggleBtn') || target.closest('#perfToggleBtn')) {
            handlePerformanceModeToggle();
            return;
        }

        // Close button
        if (target.matches('#closeBtn, .close-btn') || target.closest('#closeBtn, .close-btn')) {
            handleClose();
            return;
        }

        // Dropdown trigger
        if (target.matches('.custom-select-trigger') || target.closest('.custom-select-trigger')) {
            const trigger = target.matches('.custom-select-trigger')
                ? target
                : target.closest('.custom-select-trigger');
            handleDropdownToggle(trigger);
            return;
        }

        // Dropdown option
        const option = target.closest('.custom-option');
        if (option) {
            handleOptionSelect(option);
            return;
        }

        // Apply button
        if (target.matches('.btn-primary[data-zone]')) {
            handleApplyWeather(target);
            return;
        }

        // Close dropdowns when clicking outside
        if (!target.closest('.custom-select')) {
            closeAllDropdowns();
        }
    };

    /**
     * Global keydown handler
     * @param {KeyboardEvent} event - Keyboard event
     * @returns {void}
     */
    const handleGlobalKeydown = (event) => {
        if (event.key === 'Escape' && State.isVisible) {
            const activeDropdown = document.querySelector('.custom-select.active');
            if (activeDropdown) {
                activeDropdown.classList.remove('active');
                const card = activeDropdown.closest('.zone-card');
                if (card) card.classList.remove('dropdown-active');
                event.stopPropagation();
            } else {
                handleClose();
            }
        }
    };

    /**
     * Setup event listeners using delegation with AbortController
     * @returns {void}
     */
    const init = () => {
        // Clean up existing listeners if any
        cleanup();

        // Create abort controllers for cleanup
        clickController = new AbortController();
        keydownController = new AbortController();

        // Global click delegation (includes close button)
        document.addEventListener('click', handleGlobalClick, {
            signal: clickController.signal
        });

        // Global keydown handler
        document.addEventListener('keydown', handleGlobalKeydown, {
            signal: keydownController.signal
        });
    };

    /**
     * Cleanup event listeners
     * Prevents memory leaks on re-initialization
     * @returns {void}
     */
    const cleanup = () => {
        if (clickController) {
            clickController.abort();
            clickController = null;
        }
        if (keydownController) {
            keydownController.abort();
            keydownController = null;
        }
    };

    return {
        init,
        cleanup
    };
})();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = EventHandlers;
}

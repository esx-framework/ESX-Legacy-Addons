/**
 * ESX Weather Admin Panel - Main Script
 * @author FiveM Developer
 * @description Type-safe weather control panel with modular architecture
 */

// ==================== Type Definitions ====================

/**
 * @typedef {string} WeatherType
 * Valid GTA5 weather types
 */

/**
 * @typedef {Object} WeatherData
 * @property {string} currentZone - Name of the current zone
 * @property {WeatherType} currentWeather - Current weather type
 * @property {Object.<string, WeatherType>} WeatherByZone - Weather data for all zones
 */

/**
 * @typedef {Object} NUIMessage
 * @property {string} action - Action type
 * @property {*} Data - Message payload
 */

/**
 * @typedef {Object} AppState
 * @property {boolean} isVisible - UI visibility state
 * @property {WeatherData|null} data - Current weather data
 * @property {Object.<string, WeatherType>} weatherTypes - Available weather types
 */

// ==================== State Management ====================

/**
 * Application state container
 * Centralized state management for predictable data flow
 * @type {AppState}
 */
const State = {
    isVisible: false,
    data: null,
    weatherTypes: {}
};

// ==================== NUI Bridge ====================

/**
 * NUI Communication Bridge
 * Handles all communication between FiveM client and NUI
 */
const NUIBridge = (() => {
    const resourceName = window.location.hostname === ''
        ? 'esx_weather'
        : GetParentResourceName();

    /**
     * Send callback response to FiveM client
     * @param {string} callbackName - Callback identifier
     * @param {*} data - Response data
     * @returns {Promise<void>}
     */
    const sendCallback = async (callbackName, data) => {
        try {
            const response = await fetch(`https://${resourceName}/${callbackName}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                throw new Error(`Callback failed: ${response.status}`);
            }
        } catch (error) {
            console.error(`[NUIBridge] Failed to send callback "${callbackName}":`, error);
        }
    };

    /**
     * Close the UI and notify client
     * @returns {Promise<void>}
     */
    const close = async () => {
        await sendCallback('close', {});
        UIController.hide();
    };

    /**
     * Set weather for a specific zone
     * @param {string} zoneName - Zone identifier
     * @param {WeatherType} weatherType - Weather type to set
     * @returns {Promise<void>}
     */
    const setZoneWeather = async (zoneName, weatherType) => {
        await sendCallback('setZoneWeather', { zoneName, weatherType });
    };

    /**
     * Request initial data from client (weather types)
     * @returns {Promise<Object.<string, WeatherType>>}
     */
    const requestWeatherTypes = async () => {
        try {
            const response = await fetch(`https://${resourceName}/ready`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });

            if (!response.ok) {
                throw new Error(`Ready callback failed: ${response.status}`);
            }

            const data = await response.json();
            return data.WeatherTypes || {};
        } catch (error) {
            console.error('[NUIBridge] Failed to fetch weather types:', error);
            return {};
        }
    };

    return {
        sendCallback,
        close,
        setZoneWeather,
        requestWeatherTypes
    };
})();

// ==================== Weather Icon Mapping ====================

/**
 * @typedef {Object} WeatherIconConfig
 * @property {string} icon - Lucide icon name
 * @property {string} animation - Animation class name
 * @property {string} gradientClass - CSS gradient class
 */

/**
 * Weather icon configuration mapping
 * @type {Object.<string, WeatherIconConfig>}
 */
const WeatherIcons = {
    CLEAR: { icon: 'sun', animation: 'animate-sun', gradientClass: 'weather-clear' },
    EXTRASUNNY: { icon: 'sun', animation: 'animate-sun', gradientClass: 'weather-extrasunny' },
    CLOUDS: { icon: 'cloud', animation: 'animate-cloud', gradientClass: 'weather-clouds' },
    OVERCAST: { icon: 'cloudy', animation: 'animate-cloud', gradientClass: 'weather-overcast' },
    RAIN: { icon: 'cloud-rain', animation: 'animate-rain', gradientClass: 'weather-rain' },
    CLEARING: { icon: 'cloud-sun', animation: '', gradientClass: 'weather-clear' },
    THUNDER: { icon: 'cloud-lightning', animation: 'animate-lightning', gradientClass: 'weather-thunder' },
    SMOG: { icon: 'cloud-fog', animation: '', gradientClass: 'weather-smog' },
    FOGGY: { icon: 'cloud-fog', animation: '', gradientClass: 'weather-foggy' },
    XMAS: { icon: 'snowflake', animation: '', gradientClass: 'weather-xmas' },
    SNOW: { icon: 'snowflake', animation: '', gradientClass: 'weather-snow' },
    SNOWLIGHT: { icon: 'cloud-snow', animation: '', gradientClass: 'weather-snowlight' },
    BLIZZARD: { icon: 'snowflake', animation: '', gradientClass: 'weather-blizzard' },
    HALLOWEEN: { icon: 'cloud', animation: '', gradientClass: 'weather-neutral' },
    NEUTRAL: { icon: 'cloud', animation: '', gradientClass: 'weather-neutral' }
};

// ==================== UI Controller ====================

/**
 * UI Controller
 * Manages DOM manipulation and rendering logic
 */
const UIController = (() => {
    const elements = {
        app: document.getElementById('app'),
        closeBtn: document.getElementById('closeBtn'),
        currentZoneName: document.getElementById('currentZoneName'),
        zonesGrid: document.getElementById('zonesGrid')
    };

    /**
     * Show the UI with animation
     * @returns {void}
     */
    const show = () => {
        State.isVisible = true;
        elements.app?.classList.remove('hidden');
    };

    /**
     * Hide the UI with animation
     * @returns {void}
     */
    const hide = () => {
        State.isVisible = false;
        elements.app?.classList.add('hidden');
    };

    /**
     * Update current zone display
     * @param {string} zoneName - Zone name to display
     * @param {WeatherType} weatherType - Current weather type
     * @returns {void}
     */
    const updateCurrentZone = (zoneName, weatherType) => {
        const container = document.querySelector('.current-zone-info');
        if (!container) return;

        const iconConfig = getWeatherIcon(weatherType);

        container.className = `current-zone-info ${iconConfig.gradientClass}`;

        container.innerHTML = `
            <i data-lucide="${iconConfig.icon}" class="current-zone-icon ${iconConfig.animation}"></i>
            <div class="current-zone-details">
                <span class="current-zone-label">Current Location</span>
                <h2 class="current-zone-name">${zoneName}</h2>
                <span class="current-zone-weather">${weatherType} Weather</span>
            </div>
        `;

        if (typeof lucide !== 'undefined' && lucide.createIcons) {
            lucide.createIcons();
        }
    };

    /**
     * Get weather icon configuration
     * @param {WeatherType} weatherType - Weather type
     * @returns {WeatherIconConfig}
     */
    const getWeatherIcon = (weatherType) => {
        return WeatherIcons[weatherType] || WeatherIcons.NEUTRAL;
    };

    /**
     * Create a zone card element
     * @param {string} zoneName - Zone name
     * @param {WeatherType} weatherType - Current weather
     * @param {boolean} isCurrent - Is this the current zone
     * @returns {HTMLElement}
     */
    const createZoneCard = (zoneName, weatherType, isCurrent) => {
        const card = document.createElement('div');
        const iconConfig = getWeatherIcon(weatherType);

        card.className = `zone-card ${iconConfig.gradientClass} ${isCurrent ? 'current' : ''}`;
        card.dataset.zone = zoneName;
        card.dataset.weather = weatherType;

        const currentWeatherName = Object.keys(State.weatherTypes).find(
            key => State.weatherTypes[key] === weatherType
        ) || weatherType;

        const weatherOptions = Object.entries(State.weatherTypes)
            .map(([key, value]) => {
                const selectedClass = value === weatherType ? 'selected' : '';
                return `<div class="custom-option ${selectedClass}" data-value="${value}">
                    <span>${key}</span>
                </div>`;
            })
            .join('');

        card.innerHTML = `
            <i data-lucide="${iconConfig.icon}" class="weather-icon ${iconConfig.animation}"></i>
            <div class="zone-card-header">
                ${isCurrent ? '<span class="current-badge">Current</span>' : ''}
                <h4 class="zone-card-title">${zoneName}</h4>
            </div>
            <div class="zone-card-body">
                <div class="form-group">
                    <div class="custom-select" data-zone="${zoneName}" data-value="${weatherType}">
                        <div class="custom-select-trigger">
                            <i data-lucide="${iconConfig.icon}"></i>
                            <span>${currentWeatherName}</span>
                        </div>
                        <div class="custom-select-dropdown">
                            ${weatherOptions}
                        </div>
                    </div>
                </div>
                <button class="btn btn-primary" data-zone="${zoneName}">Apply</button>
            </div>
        `;

        return card;
    };

    /**
     * Render all zone cards
     * @param {WeatherData} data - Weather data to render
     * @returns {void}
     */
    const renderZones = (data) => {
        if (!elements.zonesGrid) return;

        const fragment = document.createDocumentFragment();

        Object.entries(data.WeatherByZone).forEach(([zoneName, weatherType]) => {
            const isCurrent = zoneName === data.currentZone;
            const card = createZoneCard(zoneName, weatherType, isCurrent);
            fragment.appendChild(card);
        });

        elements.zonesGrid.innerHTML = '';
        elements.zonesGrid.appendChild(fragment);

        if (typeof lucide !== 'undefined' && lucide.createIcons) {
            lucide.createIcons();
        }
    };

    /**
     * Update weather display for a specific zone
     * @param {string} zoneName - Zone to update
     * @param {WeatherType} weatherType - New weather type
     * @returns {void}
     */
    const updateZoneWeather = (zoneName, weatherType) => {
        const card = elements.zonesGrid?.querySelector(`[data-zone="${zoneName}"]`);
        if (!card) return;

        const iconConfig = getWeatherIcon(weatherType);
        const oldWeather = card.dataset.weather;

        card.className = `zone-card ${iconConfig.gradientClass}`;
        if (card.classList.contains('current')) {
            card.classList.add('current');
        }
        card.dataset.weather = weatherType;

        const icon = card.querySelector('.weather-icon');
        if (icon) {
            icon.setAttribute('data-lucide', iconConfig.icon);
            icon.className = `weather-icon ${iconConfig.animation}`;

            if (typeof lucide !== 'undefined' && lucide.createIcons) {
                lucide.createIcons();
            }
        }

        const customSelect = card.querySelector('.custom-select');
        if (customSelect) {
            customSelect.dataset.value = weatherType;

            const trigger = customSelect.querySelector('.custom-select-trigger');
            if (trigger) {
                const triggerIcon = trigger.querySelector('i');
                const triggerText = trigger.querySelector('span');

                const weatherName = Object.keys(State.weatherTypes).find(
                    key => State.weatherTypes[key] === weatherType
                ) || weatherType;

                if (triggerIcon) {
                    triggerIcon.setAttribute('data-lucide', iconConfig.icon);
                }
                if (triggerText) {
                    triggerText.textContent = weatherName;
                }

                if (typeof lucide !== 'undefined' && lucide.createIcons) {
                    lucide.createIcons();
                }
            }

            customSelect.querySelectorAll('.custom-option').forEach(opt => {
                if (opt.dataset.value === weatherType) {
                    opt.classList.add('selected');
                } else {
                    opt.classList.remove('selected');
                }
            });
        }
    };

    return {
        show,
        hide,
        updateCurrentZone,
        renderZones,
        updateZoneWeather,
        getWeatherIcon,
        elements
    };
})();

// ==================== Event Handlers ====================

/**
 * Event Delegation Handler
 * Efficient event handling using event delegation pattern
 */
const EventHandlers = (() => {
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
        const isActive = dropdown.classList.contains('active');

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
        const iconElement = trigger?.querySelector('svg') || trigger?.querySelector('i');
        const textElement = trigger?.querySelector('span');

        const weatherName = Object.keys(State.weatherTypes).find(
            key => State.weatherTypes[key] === value
        ) || value;
        const iconConfig = UIController.getWeatherIcon(value);

        if (textElement) {
            textElement.classList.add('slide-out');

            setTimeout(() => {
                textElement.textContent = weatherName;
                textElement.classList.remove('slide-out');
                textElement.classList.add('slide-in');

                setTimeout(() => {
                    textElement.classList.remove('slide-in');
                }, 200);
            }, 200);
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

                    if (typeof lucide !== 'undefined' && lucide.createIcons) {
                        lucide.createIcons({ root: trigger });
                    }

                    setTimeout(() => {
                        const renderedIcon = trigger.querySelector('svg') || trigger.querySelector('i');
                        if (renderedIcon) {
                            renderedIcon.style.opacity = '1';
                            renderedIcon.style.transform = 'scale(1)';
                        }
                    }, 50);
                }, 350);
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
        button.textContent = 'Applying...';

        await NUIBridge.setZoneWeather(zoneName, weatherType);

        setTimeout(() => {
            button.disabled = false;
            button.textContent = 'Apply';
        }, 500);
    };

    /**
     * Setup event listeners using delegation
     * @returns {void}
     */
    const init = () => {
        UIController.elements.closeBtn?.addEventListener('click', handleClose);

        document.addEventListener('click', (event) => {
            const target = event.target;

            if (target.matches('.custom-select-trigger') || target.closest('.custom-select-trigger')) {
                const trigger = target.matches('.custom-select-trigger')
                    ? target
                    : target.closest('.custom-select-trigger');
                handleDropdownToggle(trigger);
                return;
            }

            const option = target.closest('.custom-option');
            if (option) {
                handleOptionSelect(option);
                return;
            }

            if (target.matches('.btn-primary[data-zone]')) {
                handleApplyWeather(target);
                return;
            }

            if (!target.closest('.custom-select')) {
                document.querySelectorAll('.custom-select.active').forEach(el => {
                    el.classList.remove('active');
                    const card = el.closest('.zone-card');
                    if (card) card.classList.remove('dropdown-active');
                });
            }
        });

        document.addEventListener('keydown', (event) => {
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
        });
    };

    return {
        init
    };
})();

// ==================== NUI Message Handler ====================

/**
 * Handle incoming NUI messages from FiveM client
 * @param {MessageEvent<NUIMessage>} event - Message event
 * @returns {void}
 */
const handleNUIMessage = (event) => {
    const { action, Data } = event.data;

    switch (action) {
        case 'show':
            State.data = Data;
            UIController.updateCurrentZone(Data.currentZone, Data.currentWeather);
            UIController.renderZones(Data);
            UIController.show();
            break;

        case 'updateWeatherZones':
            if (!State.isVisible || !State.data) break;

            Object.entries(Data.WeatherByZone).forEach(([zoneName, weatherType]) => {
                State.data.WeatherByZone[zoneName] = weatherType;
                UIController.updateZoneWeather(zoneName, weatherType);
            });
            break;

        default:
            console.warn(`[NUI] Unknown action: ${action}`);
    }
};

// ==================== Initialization ====================

/**
 * Initialize the application
 * @returns {Promise<void>}
 */
const init = async () => {
    try {
        State.weatherTypes = await NUIBridge.requestWeatherTypes();

        if (Object.keys(State.weatherTypes).length === 0) {
            console.error('[Init] Failed to load weather types');
            return;
        }

        EventHandlers.init();
        window.addEventListener('message', handleNUIMessage);

        console.log('[Init] Weather Admin Panel initialized successfully');
    } catch (error) {
        console.error('[Init] Initialization failed:', error);
    }
};

/**
 * Utility: Get parent resource name for development
 * @returns {string}
 */
function GetParentResourceName() {
    const match = window.location.hostname.match(/^([a-z0-9_-]+)\./i);
    return match ? match[1] : 'esx_weather';
}

// Start the application
document.addEventListener('DOMContentLoaded', init);

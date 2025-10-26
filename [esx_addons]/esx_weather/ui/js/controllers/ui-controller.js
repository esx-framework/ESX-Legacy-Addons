/**
 * UI Controller Module
 * @module UIController
 * @description Manages DOM manipulation and rendering logic
 */

/**
 * UI Controller
 * Handles all UI rendering, updates, and DOM operations
 * @returns {Object} Public API for UI control
 */
const UIController = (() => {
    let elements = {};

    /**
     * Initialize DOM element references
     * Must be called after DOM is ready
     * @returns {void}
     */
    const initElements = () => {
        elements = {
            app: document.getElementById('app'),
            closeBtn: document.getElementById('closeBtn'),
            currentZoneName: document.getElementById('currentZoneName'),
            zonesGrid: document.getElementById('zonesGrid')
        };
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
     * Get weather icon configuration
     * @param {WeatherType} weatherType - Weather type
     * @returns {WeatherIconConfig}
     */
    const getWeatherIcon = (weatherType) => {
        return WeatherIcons[weatherType] || WeatherIcons.NEUTRAL;
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

        // Create elements safely
        const icon = document.createElement('i');
        icon.setAttribute('data-lucide', iconConfig.icon);
        icon.className = `current-zone-icon ${iconConfig.animation}`;

        const details = document.createElement('div');
        details.className = 'current-zone-details';

        const label = document.createElement('span');
        label.className = 'current-zone-label';
        label.textContent = UIText.CURRENT_LOCATION_LABEL;

        const name = document.createElement('h2');
        name.className = 'current-zone-name';
        name.textContent = zoneName;

        const weather = document.createElement('span');
        weather.className = 'current-zone-weather';
        weather.textContent = `${weatherType} ${UIText.WEATHER_SUFFIX}`;

        details.appendChild(label);
        details.appendChild(name);
        details.appendChild(weather);

        container.innerHTML = '';
        container.appendChild(icon);
        container.appendChild(details);

        Helpers.initLucideIcons();
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

        card.className = `zone-card ${iconConfig.gradientClass}${isCurrent ? ' current' : ''}`;
        card.dataset.zone = zoneName;
        card.dataset.weather = weatherType;

        // Create icon
        const icon = document.createElement('i');
        icon.setAttribute('data-lucide', iconConfig.icon);
        icon.className = `weather-icon ${iconConfig.animation}`;

        // Create header
        const header = document.createElement('div');
        header.className = 'zone-card-header';

        if (isCurrent) {
            const badge = document.createElement('span');
            badge.className = 'current-badge';
            badge.textContent = UIText.CURRENT_BADGE;
            header.appendChild(badge);
        }

        const title = document.createElement('h4');
        title.className = 'zone-card-title';
        title.textContent = zoneName;
        header.appendChild(title);

        // Create body
        const body = document.createElement('div');
        body.className = 'zone-card-body';

        // Create form group
        const formGroup = document.createElement('div');
        formGroup.className = 'form-group';

        // Create custom select
        const customSelect = createWeatherSelect(zoneName, weatherType);
        formGroup.appendChild(customSelect);

        // Create apply button
        const button = document.createElement('button');
        button.className = 'btn btn-primary';
        button.dataset.zone = zoneName;
        button.textContent = UIText.BUTTON_APPLY;

        body.appendChild(formGroup);
        body.appendChild(button);

        // Assemble card
        card.appendChild(icon);
        card.appendChild(header);
        card.appendChild(body);

        return card;
    };

    /**
     * Create weather select dropdown
     * @param {string} zoneName - Zone name
     * @param {WeatherType} currentWeather - Current weather type
     * @returns {HTMLElement} Select element
     */
    const createWeatherSelect = (zoneName, currentWeather) => {
        const customSelect = document.createElement('div');
        customSelect.className = 'custom-select';
        customSelect.dataset.zone = zoneName;
        customSelect.dataset.value = currentWeather;

        const currentWeatherName = Helpers.getWeatherDisplayName(currentWeather, State.weatherTypes);
        const iconConfig = getWeatherIcon(currentWeather);

        // Create trigger
        const trigger = document.createElement('div');
        trigger.className = 'custom-select-trigger';

        const triggerIcon = document.createElement('i');
        triggerIcon.setAttribute('data-lucide', iconConfig.icon);

        const triggerText = document.createElement('span');
        triggerText.textContent = currentWeatherName;

        trigger.appendChild(triggerIcon);
        trigger.appendChild(triggerText);

        // Create dropdown
        const dropdown = document.createElement('div');
        dropdown.className = 'custom-select-dropdown';

        Object.entries(State.weatherTypes).forEach(([key, value]) => {
            const option = document.createElement('div');
            option.className = `custom-option${value === currentWeather ? ' selected' : ''}`;
            option.dataset.value = value;

            const optionText = document.createElement('span');
            optionText.textContent = key;

            option.appendChild(optionText);
            dropdown.appendChild(option);
        });

        customSelect.appendChild(trigger);
        customSelect.appendChild(dropdown);

        return customSelect;
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

        Helpers.initLucideIcons();
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
        const isCurrent = card.classList.contains('current');

        // Update card classes (preserve 'current' class)
        card.className = `zone-card ${iconConfig.gradientClass}${isCurrent ? ' current' : ''}`;
        card.dataset.weather = weatherType;

        // Update weather icon
        const icon = card.querySelector('.weather-icon');
        if (icon) {
            icon.setAttribute('data-lucide', iconConfig.icon);
            icon.className = `weather-icon ${iconConfig.animation}`;
            Helpers.initLucideIcons();
        }

        // Update custom select
        const customSelect = card.querySelector('.custom-select');
        if (customSelect) {
            customSelect.dataset.value = weatherType;

            const trigger = customSelect.querySelector('.custom-select-trigger');
            if (trigger) {
                const triggerIcon = trigger.querySelector('i');
                const triggerText = trigger.querySelector('span');

                const weatherName = Helpers.getWeatherDisplayName(weatherType, State.weatherTypes);

                if (triggerIcon) {
                    triggerIcon.setAttribute('data-lucide', iconConfig.icon);
                }
                if (triggerText) {
                    triggerText.textContent = weatherName;
                }

                Helpers.initLucideIcons();
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
        initElements,
        show,
        hide,
        updateCurrentZone,
        renderZones,
        updateZoneWeather,
        getWeatherIcon,
        elements
    };
})();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = UIController;
}

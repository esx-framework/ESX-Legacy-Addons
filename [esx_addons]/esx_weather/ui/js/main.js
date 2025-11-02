/**
 * Main Application Module
 * @module Main
 * @description Application initialization and NUI message orchestration
 */

/**
 * @typedef {Object} NUIMessage
 * @property {string} action - Action type
 * @property {*} Data - Message payload
 */

/**
 * Handle incoming NUI messages from FiveM client
 * Routes messages to appropriate handlers based on action type
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

/**
 * Initialize the application
 * Sets up weather types, event handlers, and message listeners
 * @returns {Promise<void>}
 */
const init = async () => {
    try {
        // Initialize DOM elements first
        UIController.initElements();

        // Fetch weather types from server
        State.weatherTypes = await NUIBridge.requestWeatherTypes();

        if (Object.keys(State.weatherTypes).length === 0) {
            console.error('[Init] Failed to load weather types');
            return;
        }

        // Initialize performance mode based on saved setting
        UIController.initPerformanceMode();

        // Initialize event handlers
        EventHandlers.init();

        // Register NUI message listener
        window.addEventListener('message', handleNUIMessage);

        console.log('[Init] Weather Admin Panel initialized successfully');
        console.log(`[Init] Performance Mode: ${State.performanceMode ? 'ON' : 'OFF'}`);
    } catch (error) {
        console.error('[Init] Initialization failed:', error);
    }
};

// Start the application when DOM is ready
document.addEventListener('DOMContentLoaded', init);

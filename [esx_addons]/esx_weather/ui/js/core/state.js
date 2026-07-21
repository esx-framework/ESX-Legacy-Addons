/**
 * State Management Module
 * @module State
 * @description Centralized application state container for predictable data flow
 */

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
 * @typedef {Object} AppState
 * @property {boolean} isVisible - UI visibility state
 * @property {WeatherData|null} data - Current weather data
 * @property {Object.<string, WeatherType>} weatherTypes - Available weather types
 */

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

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = State;
}

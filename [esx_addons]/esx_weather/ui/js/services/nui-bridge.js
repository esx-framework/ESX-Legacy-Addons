/**
 * NUI Bridge Service
 * @module NUIBridge
 * @description Handles all communication between FiveM client and NUI
 */

/**
 * NUI Communication Bridge
 * Manages fetch requests and callbacks to FiveM client
 * @returns {Object} Public API for NUI communication
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
        if (typeof UIController !== 'undefined') {
            UIController.hide();
        }
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

/**
 * Utility: Get parent resource name for development
 * @returns {string}
 */
function GetParentResourceName() {
    const match = window.location.hostname.match(/^([a-z0-9_-]+)\./i);
    return match ? match[1] : 'esx_weather';
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NUIBridge;
}

/**
 * Constants Module
 * @module Constants
 * @description Weather icon configurations and application constants
 */

/**
 * @typedef {Object} WeatherIconConfig
 * @property {string} icon - Lucide icon name
 * @property {string} animation - Animation class name
 * @property {string} gradientClass - CSS gradient class
 */

/**
 * Weather icon configuration mapping
 * Maps weather types to their visual representation
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

/**
 * Animation timing constants (in milliseconds)
 * Centralized timing values for consistent animations
 * @type {Object.<string, number>}
 */
const AnimationTimings = {
    SLIDE_ANIMATION: 200,
    ICON_FADE_OUT: 350,
    ICON_FADE_IN: 50,
    BUTTON_FEEDBACK: 500
};

/**
 * UI text constants
 * Centralized text for easier i18n implementation
 * @type {Object.<string, string>}
 */
const UIText = {
    CURRENT_LOCATION_LABEL: 'Current Location',
    WEATHER_SUFFIX: 'Weather',
    CURRENT_BADGE: 'Current',
    BUTTON_APPLY: 'Apply',
    BUTTON_APPLYING: 'Applying...'
};

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { WeatherIcons, AnimationTimings, UIText };
}

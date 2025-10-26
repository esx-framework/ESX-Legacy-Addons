/**
 * Helper Functions Module
 * @module Helpers
 * @description Shared utility functions to eliminate code duplication
 */

/**
 * Helper utilities for common operations
 */
const Helpers = (() => {
    /**
     * Get weather display name from weather type
     * Converts weather type value back to display name
     * @param {WeatherType} weatherType - Weather type value
     * @param {Object.<string, WeatherType>} weatherTypes - Available weather types
     * @returns {string} Weather display name
     * @example
     * getWeatherDisplayName('CLEAR', { CLEAR: 'CLEAR', RAIN: 'RAIN' })
     * // Returns: 'CLEAR'
     */
    const getWeatherDisplayName = (weatherType, weatherTypes) => {
        if (!weatherTypes || typeof weatherTypes !== 'object') {
            return weatherType;
        }

        const displayName = Object.keys(weatherTypes).find(
            key => weatherTypes[key] === weatherType
        );

        return displayName || weatherType;
    };

    /**
     * Safely initialize Lucide icons
     * @param {HTMLElement} [root] - Optional root element to scope icon creation
     * @returns {void}
     */
    const initLucideIcons = (root) => {
        if (typeof lucide !== 'undefined' && lucide.createIcons) {
            lucide.createIcons(root ? { root } : undefined);
        }
    };

    /**
     * Debounce function execution
     * Delays function execution until after wait milliseconds have elapsed
     * @param {Function} func - Function to debounce
     * @param {number} wait - Milliseconds to wait
     * @returns {Function} Debounced function
     */
    const debounce = (func, wait) => {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    };

    /**
     * Create a DOM element with attributes and children
     * @param {string} tag - HTML tag name
     * @param {Object} [attributes] - Element attributes
     * @param {Array<HTMLElement|string>} [children] - Child elements or text
     * @returns {HTMLElement} Created element
     * @example
     * createElement('div', { class: 'card' }, ['Hello World'])
     */
    const createElement = (tag, attributes = {}, children = []) => {
        const element = document.createElement(tag);

        Object.entries(attributes).forEach(([key, value]) => {
            if (key === 'class') {
                element.className = value;
            } else if (key === 'dataset') {
                Object.entries(value).forEach(([dataKey, dataValue]) => {
                    element.dataset[dataKey] = dataValue;
                });
            } else if (key.startsWith('on') && typeof value === 'function') {
                element.addEventListener(key.substring(2).toLowerCase(), value);
            } else {
                element.setAttribute(key, value);
            }
        });

        children.forEach(child => {
            if (typeof child === 'string') {
                element.appendChild(document.createTextNode(child));
            } else if (child instanceof HTMLElement) {
                element.appendChild(child);
            }
        });

        return element;
    };

    /**
     * Remove all event listeners by cloning and replacing node
     * @param {HTMLElement} element - Element to clean
     * @returns {HTMLElement} Cleaned element
     */
    const removeAllEventListeners = (element) => {
        if (!element) return element;
        const clone = element.cloneNode(true);
        element.parentNode?.replaceChild(clone, element);
        return clone;
    };

    /**
     * Check if element exists in DOM
     * @param {string} selector - CSS selector
     * @returns {boolean} Element exists
     */
    const elementExists = (selector) => {
        return document.querySelector(selector) !== null;
    };

    /**
     * Wait for element to exist in DOM
     * @param {string} selector - CSS selector
     * @param {number} [timeout=5000] - Timeout in milliseconds
     * @returns {Promise<HTMLElement>} Found element
     */
    const waitForElement = (selector, timeout = 5000) => {
        return new Promise((resolve, reject) => {
            const element = document.querySelector(selector);
            if (element) {
                return resolve(element);
            }

            const observer = new MutationObserver(() => {
                const element = document.querySelector(selector);
                if (element) {
                    observer.disconnect();
                    resolve(element);
                }
            });

            observer.observe(document.body, {
                childList: true,
                subtree: true
            });

            setTimeout(() => {
                observer.disconnect();
                reject(new Error(`Element ${selector} not found within ${timeout}ms`));
            }, timeout);
        });
    };

    return {
        getWeatherDisplayName,
        initLucideIcons,
        debounce,
        createElement,
        removeAllEventListeners,
        elementExists,
        waitForElement
    };
})();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Helpers;
}

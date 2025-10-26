/**
 * Sanitizer Utility Module
 * @module Sanitizer
 * @description XSS protection for user-generated content
 */

/**
 * HTML Sanitizer
 * Prevents XSS attacks by escaping dangerous characters
 */
const Sanitizer = (() => {
    /**
     * Escape HTML special characters to prevent XSS
     * @param {string} str - String to sanitize
     * @returns {string} Sanitized string
     * @example
     * sanitizeHTML('<script>alert("xss")</script>')
     * // Returns: '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'
     */
    const sanitizeHTML = (str) => {
        if (typeof str !== 'string') {
            return '';
        }

        const htmlEscapeMap = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#x27;',
            '/': '&#x2F;'
        };

        return str.replace(/[&<>"'/]/g, (char) => htmlEscapeMap[char]);
    };

    /**
     * Sanitize attribute values for safe use in HTML attributes
     * @param {string} value - Attribute value to sanitize
     * @returns {string} Sanitized attribute value
     * @example
     * sanitizeAttribute('onclick="alert(1)"')
     * // Returns: 'onclick=&quot;alert(1)&quot;'
     */
    const sanitizeAttribute = (value) => {
        if (typeof value !== 'string') {
            return '';
        }

        return value
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#x27;')
            .replace(/`/g, '&#x60;');
    };

    /**
     * Create a safe text node (alternative to innerHTML)
     * @param {string} text - Text content
     * @returns {Text} DOM Text node
     */
    const createTextNode = (text) => {
        return document.createTextNode(String(text));
    };

    /**
     * Safely set element text content
     * @param {HTMLElement} element - Target element
     * @param {string} text - Text to set
     * @returns {void}
     */
    const setTextContent = (element, text) => {
        if (!element) return;
        element.textContent = String(text);
    };

    /**
     * Validate weather type against known types
     * @param {string} weatherType - Weather type to validate
     * @param {Object.<string, string>} validTypes - Valid weather types
     * @returns {boolean} Is valid weather type
     */
    const isValidWeatherType = (weatherType, validTypes) => {
        if (typeof weatherType !== 'string') return false;
        return Object.values(validTypes).includes(weatherType);
    };

    /**
     * Validate zone name (alphanumeric + spaces only)
     * @param {string} zoneName - Zone name to validate
     * @returns {boolean} Is valid zone name
     */
    const isValidZoneName = (zoneName) => {
        if (typeof zoneName !== 'string') return false;
        // Allow alphanumeric, spaces, hyphens, underscores
        return /^[a-zA-Z0-9\s\-_]+$/.test(zoneName);
    };

    return {
        sanitizeHTML,
        sanitizeAttribute,
        createTextNode,
        setTextContent,
        isValidWeatherType,
        isValidZoneName
    };
})();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Sanitizer;
}

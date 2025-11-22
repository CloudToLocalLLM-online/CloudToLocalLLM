/**
 * String utilities for CloudToLocalLLM API Backend
 */

/**
 * Safely stringify an object
 * @param {*} obj - Object to stringify
 * @param {number} space - Indentation spaces
 * @returns {string} JSON string
 */
export function stringify(obj, space = 2) {
  try {
    return JSON.stringify(obj, null, space);
  } catch {
    return String(obj);
  }
}

/**
 * Truncate a string to a maximum length
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @param {string} suffix - Suffix to add if truncated
 * @returns {string} Truncated string
 */
export function truncate(str, maxLength = 100, suffix = '...') {
  if (str.length <= maxLength) {
    return str;
  }
  return str.substring(0, maxLength - suffix.length) + suffix;
}

export default {
  stringify,
  truncate,
};

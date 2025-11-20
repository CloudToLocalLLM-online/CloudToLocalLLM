/**
 * Hash utilities for CloudToLocalLLM API Backend
 */

import crypto from 'crypto';

/**
 * Generate SHA256 hash of a string
 * @param {string} str - String to hash
 * @returns {string} Hex-encoded hash
 */
export function sha256(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

/**
 * Generate MD5 hash of a string
 * @param {string} str - String to hash
 * @returns {string} Hex-encoded hash
 */
export function md5(str) {
  return crypto.createHash('md5').update(str).digest('hex');
}

/**
 * Generate random hash
 * @returns {string} Random hex hash
 */
export function randomHash() {
  return crypto.randomBytes(32).toString('hex');
}

export default {
  sha256,
  md5,
  randomHash,
};

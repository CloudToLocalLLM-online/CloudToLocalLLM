/// SSH Host Key Manager
/// Manages SSH host key verification using Trust On First Use (TOFU) pattern
///
/// Requirements:
/// - 7.5: THE Client SHALL verify server host key on first connection (TOFU)
/// - 7.5: THE Client SHALL cache verified host keys in SharedPreferences
/// - 7.5: THE Client SHALL warn user on host key changes
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Result of host key verification
class HostKeyVerificationResult {
  final bool verified;
  final bool isNewKey;
  final String? message;
  final String? suggestion;

  HostKeyVerificationResult({
    required this.verified,
    required this.isNewKey,
    this.message,
    this.suggestion,
  });
}

/// SSH Host Key Manager
/// Implements Trust On First Use (TOFU) pattern for SSH host key verification
class SSHHostKeyManager {
  static const String _storageKey = 'ssh_host_keys';

  final SharedPreferences _prefs;

  SSHHostKeyManager({required SharedPreferences prefs}) : _prefs = prefs;

  /// Verify host key using TOFU pattern
  ///
  /// On first connection: cache the key and return verified=true
  /// On subsequent connections: compare with cached key
  /// If key changed: warn user and return verified=false
  ///
  /// Requirements: 7.5
  Future<HostKeyVerificationResult> verifyHostKey({
    required String host,
    required String key,
  }) async {
    try {
      final cachedKeys = _loadCachedKeys();

      if (cachedKeys.containsKey(host)) {
        // Host key exists in cache
        final cachedKey = cachedKeys[host];

        if (cachedKey == key) {
          // Key matches - connection is verified
          return HostKeyVerificationResult(
            verified: true,
            isNewKey: false,
            message: 'Host key verified',
          );
        } else {
          // Key mismatch - potential security issue
          return HostKeyVerificationResult(
            verified: false,
            isNewKey: false,
            message:
                'Host key has changed. This could indicate a security issue.',
            suggestion:
                'If you trust this change, click "Trust New Key" to update the cached key.',
          );
        }
      } else {
        // First time seeing this host - cache the key (TOFU)
        cachedKeys[host] = key;
        await _saveCachedKeys(cachedKeys);

        return HostKeyVerificationResult(
          verified: true,
          isNewKey: true,
          message: 'New host key cached',
          suggestion: 'Host key has been cached for future connections.',
        );
      }
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error verifying host key: $e');
      return HostKeyVerificationResult(
        verified: false,
        isNewKey: false,
        message: 'Error verifying host key: $e',
      );
    }
  }

  /// Trust a new host key and update cache
  /// Called when user confirms they want to trust a new key
  ///
  /// Requirements: 7.5
  Future<bool> trustNewKey({
    required String host,
    required String key,
  }) async {
    try {
      final cachedKeys = _loadCachedKeys();
      cachedKeys[host] = key;
      await _saveCachedKeys(cachedKeys);

      debugPrint('[SSHHostKeyManager] Trusted new key for host: $host');
      return true;
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error trusting new key: $e');
      return false;
    }
  }

  /// Get all trusted host keys
  ///
  /// Requirements: 7.5
  Map<String, String> getTrustedKeys() {
    return _loadCachedKeys();
  }

  /// Clear all trusted host keys
  ///
  /// Requirements: 7.5
  Future<bool> clearAllKeys() async {
    try {
      await _prefs.remove(_storageKey);
      debugPrint('[SSHHostKeyManager] Cleared all trusted host keys');
      return true;
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error clearing keys: $e');
      return false;
    }
  }

  /// Remove a specific host key from cache
  ///
  /// Requirements: 7.5
  Future<bool> removeKey(String host) async {
    try {
      final cachedKeys = _loadCachedKeys();
      cachedKeys.remove(host);
      await _saveCachedKeys(cachedKeys);

      debugPrint('[SSHHostKeyManager] Removed key for host: $host');
      return true;
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error removing key: $e');
      return false;
    }
  }

  /// Add a manually trusted host key
  ///
  /// Requirements: 7.5
  Future<bool> addManualKey({
    required String host,
    required String key,
  }) async {
    try {
      final cachedKeys = _loadCachedKeys();
      cachedKeys[host] = key;
      await _saveCachedKeys(cachedKeys);

      debugPrint('[SSHHostKeyManager] Added manual key for host: $host');
      return true;
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error adding manual key: $e');
      return false;
    }
  }

  /// Load cached keys from SharedPreferences
  /// Returns Map where key is host and value is base64 encoded key
  Map<String, String> _loadCachedKeys() {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString == null) {
        return {};
      }

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.cast<String, String>();
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error loading cached keys: $e');
      return {};
    }
  }

  /// Save cached keys to SharedPreferences
  Future<bool> _saveCachedKeys(Map<String, String> keys) async {
    try {
      final jsonString = jsonEncode(keys);
      await _prefs.setString(_storageKey, jsonString);
      return true;
    } catch (e) {
      debugPrint('[SSHHostKeyManager] Error saving cached keys: $e');
      return false;
    }
  }
}

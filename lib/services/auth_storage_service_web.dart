import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web-compatible authentication storage service
/// Uses localStorage with structured JSON storage for reliable token persistence
class AuthStorageService {
  static const String _tokenDataKey = 'cloudtolocalllm_token_data';

  /// Store authentication tokens
  static Future<void> storeTokens({
    required String accessToken,
    String? idToken,
    String? refreshToken,
    required DateTime expiresAt,
    String? scope,
    String? audience,
  }) async {
    try {
      debugPrint('🗄️ [AuthStorage] Storing authentication tokens in localStorage');

      final tokenData = {
        'access_token': accessToken,
        'id_token': idToken,
        'refresh_token': refreshToken,
        'token_type': 'Bearer',
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'scope': scope,
        'audience': audience,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final jsonString = json.encode(tokenData);
      web.window.localStorage.setItem(_tokenDataKey, jsonString);

      debugPrint('🗄️ [AuthStorage] Tokens stored successfully in localStorage');
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error storing tokens: $e');
      rethrow;
    }
  }

  /// Load stored authentication tokens
  static Future<Map<String, dynamic>?> loadTokens() async {
    try {
      debugPrint('🗄️ [AuthStorage] Loading stored tokens from localStorage');

      final jsonString = web.window.localStorage.getItem(_tokenDataKey);
      
      if (jsonString == null) {
        debugPrint('🗄️ [AuthStorage] No stored tokens found');
        return null;
      }

      final tokenData = json.decode(jsonString) as Map<String, dynamic>;
      final expiresAtMs = tokenData['expires_at'] as int?;
      
      if (expiresAtMs == null) {
        debugPrint('🗄️ [AuthStorage] Invalid token data - no expiry');
        await clearTokens();
        return null;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);

      // Check if token is expired
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('🗄️ [AuthStorage] Stored tokens are expired, clearing');
        await clearTokens();
        return null;
      }

      debugPrint('🗄️ [AuthStorage] Valid tokens loaded successfully');
      return {
        'access_token': tokenData['access_token'],
        'id_token': tokenData['id_token'],
        'refresh_token': tokenData['refresh_token'],
        'token_type': tokenData['token_type'],
        'expires_at': expiresAt,
        'scope': tokenData['scope'],
        'audience': tokenData['audience'],
      };
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error loading tokens: $e');
      await clearTokens(); // Clear corrupted data
      return null;
    }
  }

  /// Clear all stored tokens
  static Future<void> clearTokens() async {
    try {
      debugPrint('🗄️ [AuthStorage] Clearing stored tokens');
      
      web.window.localStorage.removeItem(_tokenDataKey);
      
      // Also clear legacy keys for cleanup
      web.window.localStorage.removeItem('cloudtolocalllm_access_token');
      web.window.localStorage.removeItem('cloudtolocalllm_id_token');
      web.window.localStorage.removeItem('cloudtolocalllm_token_expiry');
      
      debugPrint('🗄️ [AuthStorage] Tokens cleared successfully');
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error clearing tokens: $e');
    }
  }

  /// Check if valid tokens exist
  static Future<bool> hasValidTokens() async {
    final tokens = await loadTokens();
    return tokens != null;
  }

  /// Get access token if valid
  static Future<String?> getAccessToken() async {
    final tokens = await loadTokens();
    return tokens?['access_token'];
  }

  /// Get ID token if valid
  static Future<String?> getIdToken() async {
    final tokens = await loadTokens();
    return tokens?['id_token'];
  }

  /// Get token expiry if valid
  static Future<DateTime?> getTokenExpiry() async {
    final tokens = await loadTokens();
    return tokens?['expires_at'];
  }
}

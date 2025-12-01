import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../config/app_config.dart';

/// Session storage service for managing authentication sessions in PostgreSQL
class SessionStorageService {
  final String _baseUrl = AppConfig.apiBaseUrl;
  final Dio _dio = Dio();

  SessionStorageService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  /// Create a new session for an authenticated user
  Future<SessionModel> createSession({
    required UserModel user,
  }) async {
    // Generate a unique session token
    final token = _generateSessionToken();
    final expiresAt =
        DateTime.now().add(const Duration(hours: 24)); // 24 hour sessions

    final sessionData = {
      'userId': user.id,
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
      'userProfile': {
        'email': user.email,
        'name': user.name,
        'nickname': user.nickname,
        'picture': user.picture,
        'email_verified': user.emailVerified != null,
        'email_verified_at': user.emailVerified?.toIso8601String(),
      },
    };

    try {
      final response = await _dio.post(
        '/auth/sessions',
        data: sessionData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 201) {
        final responseData = response.data;
        final session = SessionModel(
          id: responseData['id'],
          userId: user.id,
          token: token,
          expiresAt: expiresAt,
          user: user,
        );

        // Store session token locally
        await _storeSessionToken(token);

        return session;
      } else {
        throw Exception('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to create session: $e');
      // Return a local session for now if API is unavailable
      final session = SessionModel(
        id: _generateId(),
        userId: user.id,
        token: token,
        expiresAt: expiresAt,
        user: user,
        createdAt: DateTime.now(),
        lastActivity: DateTime.now(),
      );

      // Still store locally even if API fails
      await _storeSessionToken(token);

      return session;
    }
  }

  /// Get current valid session (if any)
  Future<SessionModel?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('session_token');

      if (storedToken == null || storedToken.isEmpty) {
        debugPrint(' No stored session token found');
        return null;
      }

      debugPrint(' Found stored session token, validating...');
      final session = await validateSession(storedToken);

      if (session == null) {
        debugPrint(' Stored session token is invalid, clearing...');
        await prefs.remove('session_token');
      }

      return session;
    } catch (e) {
      debugPrint(' Error getting current session: $e');
      return null;
    }
  }

  /// Store session token locally
  Future<void> _storeSessionToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', token);
      debugPrint(' Stored session token locally');
    } catch (e) {
      debugPrint(' Failed to store session token: $e');
    }
  }

  /// Clear stored session token
  Future<void> _clearStoredSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      debugPrint(' Cleared stored session token');
    } catch (e) {
      debugPrint(' Failed to clear session token: $e');
    }
  }

  /// Validate a session token
  Future<SessionModel?> validateSession(String token) async {
    try {
      final response = await _dio.get(
        '/auth/sessions/validate/$token',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        // Parse user data and create SessionModel
        final user = UserModel(
          id: responseData['user']['id'],
          email: responseData['user']['email'],
          name: responseData['user']['name'],
          picture: responseData['user']['picture'],
          nickname: responseData['user']['nickname'],
          emailVerified:
              responseData['user']['email_verified'] ? DateTime.now() : null,
          createdAt: DateTime.now(), // API should provide this
          updatedAt: DateTime.now(), // API should provide this
        );

        return SessionModel(
          id: responseData['session']['id'],
          userId: responseData['user']['id'],
          token: token,
          expiresAt: DateTime.parse(responseData['session']['expiresAt']),
          user: user,
          createdAt: DateTime.parse(responseData['session']['createdAt']),
          lastActivity: DateTime.parse(responseData['session']['lastActivity']),
        );
      } else if (response.statusCode == 404) {
        return null; // Session not found or expired
      } else {
        throw Exception('Failed to validate session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to validate session: $e');
      return null;
    }
  }

  /// Invalidate a session
  Future<void> invalidateSession(String token) async {
    // Clear local storage first
    await _clearStoredSessionToken();

    try {
      final response = await _dio.delete(
        '/auth/sessions/$token',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to invalidate session: ${response.statusCode}');
      }

      debugPrint(' Session invalidated: $token');
    } catch (e) {
      debugPrint(' Failed to invalidate session remotely: $e');
      // Local storage is already cleared, so session is effectively invalidated
    }
  }

  /// Clean up expired sessions
  Future<void> cleanupExpiredSessions() async {
    try {
      final response = await _dio.post(
        '/auth/sessions/cleanup',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        debugPrint(
            '[SessionStorage] Cleaned up ${result['deleted']} expired sessions');
      } else {
        throw Exception('Failed to cleanup sessions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to cleanup sessions: $e');
    }
  }

  String _generateSessionToken() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode('$random' 'session_salt');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  String _generateId() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode('$random' 'id_salt');
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32);
  }
}

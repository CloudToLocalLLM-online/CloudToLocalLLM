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
  SessionModel? _currentSession;

  SessionStorageService() {
    _setupDio();
  }

  SessionModel? get currentSession => _currentSession;

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  /// Create or retrieve a session for an authenticated user
  Future<SessionModel> createSession({
    required UserModel user,
    String? accessToken,
  }) async {
    // If we have an access token, use the new /current endpoint which auto-syncs
    if (accessToken != null) {
      try {
        final response = await _dio.get(
          '/auth/sessions/current',
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          }),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          final session = SessionModel(
            id: responseData['session']['id'],
            userId: responseData['user']['id'],
            token: responseData['session']['token'],
            accessToken: responseData['session']['jwtAccessToken'],
            idToken: responseData['session']['jwtIdToken'],
            refreshToken: responseData['session']['refreshToken'],
            expiresAt: DateTime.parse(responseData['session']['expiresAt']),
            user: user,
            createdAt: DateTime.parse(responseData['session']['createdAt']),
            lastActivity:
                DateTime.parse(responseData['session']['lastActivity']),
          );

          // Store session token locally
          await _storeSessionToken(session.token);
          _currentSession = session;

          return session;
        }
      } catch (e) {
        debugPrint(' Failed to create session via /current: $e');
      }
    }

    // Fallback to local session generation if API is unavailable or fails
    final token = _generateSessionToken();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

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
    _currentSession = session;

    return session;
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

        final session = SessionModel(
          id: responseData['session']['id'],
          userId: responseData['user']['id'],
          token: token,
          accessToken: responseData['session']['jwtAccessToken'],
          idToken: responseData['session']['jwtIdToken'],
          refreshToken: responseData['session']['refreshToken'],
          expiresAt: DateTime.parse(responseData['session']['expiresAt']),
          user: user,
          createdAt: DateTime.parse(responseData['session']['createdAt']),
          lastActivity: DateTime.parse(responseData['session']['lastActivity']),
        );

        _currentSession = session;
        return session;
      } else if (response.statusCode == 404) {
        _currentSession = null;
        return null; // Session not found or expired
      } else {
        _currentSession = null;
        throw Exception('Failed to validate session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to validate session: $e');
      _currentSession = null;
      return null;
    }
  }

  /// Update tokens for the current session in PostgreSQL
  Future<void> syncTokens({
    required String sessionToken,
    String? accessToken,
    String? idToken,
    String? refreshToken,
  }) async {
    try {
      final response = await _dio.put(
        '/auth/sessions/tokens',
        data: {
          'sessionToken': sessionToken,
          'accessToken': accessToken,
          'idToken': idToken,
          'refreshToken': refreshToken,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        debugPrint(' Tokens synchronized with PostgreSQL');
        if (_currentSession != null && _currentSession!.token == sessionToken) {
          _currentSession = _currentSession!.copyWith(
            accessToken: accessToken,
            idToken: idToken,
            refreshToken: refreshToken,
          );
        }
      } else {
        throw Exception('Failed to sync tokens: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Failed to sync tokens with PostgreSQL: $e');
      rethrow;
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

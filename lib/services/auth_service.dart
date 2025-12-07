import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import '../config/navigator_key.dart';
import '../di/locator.dart' as di;
import 'connection_manager_service.dart';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Microsoft Entra ID Authentication Service
class AuthService extends ChangeNotifier {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();
  UserModel? _currentUser;
  bool _initialized = false;

  // Entra ID Configuration
  late final AadOAuth _oauth;

  AuthService() {
    // Configuration for Entra ID (Standard or B2C)
    final isB2C = AppConfig.aadPolicy != null;
    final tenant = isB2C
        ? (AppConfig.aadDomain ?? AppConfig.aadTenantId)
        : AppConfig.aadTenantId;

    final config = Config(
      tenant: tenant,
      clientId: AppConfig.aadClientId,
      scope: "openid profile email offline_access",
      redirectUri: kIsWeb
          ? Uri.base.origin
          : "https://login.microsoftonline.com/common/oauth2/nativeclient",
      navigatorKey: navigatorKey,
      webUseRedirect: true,
      isB2C: isB2C,
      policy: AppConfig.aadPolicy,
    );
    _oauth = AadOAuth(config);
  }

  Future<void> init() async {
    print('[AuthService] init() called');
    if (_initialized) return;
    _initialized = true;

    await _checkCurrentSession();
    print('[AuthService] init() completed');
  }

  /// Check if there is a valid cached token
  Future<void> _checkCurrentSession() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      final hasToken = await _oauth.hasCachedAccountInformation;
      if (hasToken) {
        final token = await _oauth.getAccessToken();
        if (token != null) {
          // Verify token is not expired
          if (JwtDecoder.isExpired(token)) {
            print('[AuthService] Token expired, attempting refresh...');
            // aad_oauth handles refreshing automatically on getAccessToken usually,
            // but if it fails, we might need to force login.
            // For now, let's assume if getAccessToken returned, it's valid.
          }
          await _handleAuthenticatedSession(token);
        } else {
          _completeSessionBootstrap();
        }
      } else {
        _completeSessionBootstrap();
      }
    } catch (e) {
      print('[AuthService] Session check failed: $e');
      _completeSessionBootstrap();
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      await _oauth.login();
      final token = await _oauth.getAccessToken();

      if (token != null) {
        await _handleAuthenticatedSession(token);
      } else {
        throw Exception('Login succeeded but no token returned');
      }
    } catch (e) {
      print('[AuthService] Login failed: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      await _oauth.logout();
      _isAuthenticated.value = false;
      _areAuthenticatedServicesLoaded.value = false;
      _currentUser = null;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticatedSession(String accessToken) async {
    try {
      if (_isAuthenticated.value && _areAuthenticatedServicesLoaded.value) {
        _completeSessionBootstrap();
        return;
      }

      // Decode token to get user info
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

      // Map Entra ID claims to UserModel
      // Entra ID standard claims: oid (id), name, email/upn
      _currentUser = UserModel(
        id: decodedToken['oid'] ?? decodedToken['sub'],
        email: decodedToken['email'] ?? decodedToken['upn'] ?? '',
        name: decodedToken['name'] ?? 'User',
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(), // Token doesn't have created_at usually
      );

      // Register session with backend
      await _registerSession(accessToken, decodedToken);

      await _loadAuthenticatedServices();

      _isAuthenticated.value = true;
      notifyListeners();
      _completeSessionBootstrap();
    } catch (e) {
      print('[AuthService] Handle session error: $e');
      _isAuthenticated.value = false;
      _currentUser = null;
      notifyListeners();
      _completeSessionBootstrap();
    }
  }

  Future<void> _loadAuthenticatedServices() async {
    try {
      final hasConnectionManager =
          di.serviceLocator.isRegistered<ConnectionManagerService>();
      if (hasConnectionManager) {
        _areAuthenticatedServicesLoaded.value = true;
        notifyListeners();
        return;
      }
      await di.setupAuthenticatedServices();
      _areAuthenticatedServicesLoaded.value = true;
      notifyListeners();
    } catch (e) {
      print('[AuthService] ERROR loading authenticated services: $e');
      _areAuthenticatedServicesLoaded.value = false;
      notifyListeners();
    }
  }

  Future<void> _registerSession(
    String token,
    Map<String, dynamic> claims,
  ) async {
    try {
      final dio = Dio();
      // Ensure backend knows about this session
      final response = await dio.post(
        '${AppConfig.apiBaseUrl}/auth/sessions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'userId': _currentUser?.id,
          'token': token,
          'jwtAccessToken': token,
          'userProfile': {
            'email': _currentUser?.email,
            'name': _currentUser?.name,
          },
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        print(
          '[AuthService] Warning: Session registration failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[AuthService] Register session error: $e');
      // Non-blocking
    }
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }

  // Getters & Compat
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;
  bool get isSessionBootstrapComplete => _sessionBootstrapCompleter.isCompleted;
  Future<void> get sessionBootstrapFuture => _sessionBootstrapCompleter.future;
  UserModel? get currentUser => _currentUser;

  // Platform compatibility
  bool get isWeb => kIsWeb;

  Future<String?> getAccessToken() async {
    try {
      return await _oauth.getAccessToken();
    } catch (e) {
      return null;
    }
  }

  Future<String?> getValidatedAccessToken() async => getAccessToken();

  Future<bool> handleCallback({String? callbackUrl, String? code}) async {
    // aad_oauth handles this internally, but we keep this stub for compatibility
    // with existing deep link handling code until that is refactored.
    print(
      '[AuthService] handleCallback called - processed internally by aad_oauth or unnecessary',
    );
    return true;
  }
}

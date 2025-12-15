import 'dart:async';
import 'dart:io';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/url_scheme_registration_service.dart'
    if (dart.library.html) '../../services/url_scheme_registration_service_stub.dart';

/// Error types for authentication failures
enum AuthErrorType {
  network,
  cancelled,
  invalidCredentials,
  configuration,
  unknown
}

/// Structured authentication exception with recovery suggestions
class AuthException implements Exception {
  final AuthErrorType type;
  final String message;
  final String? recoverySuggestion;

  AuthException(this.type, this.message, {this.recoverySuggestion});

  factory AuthException.network(String details) =>
      AuthException(AuthErrorType.network, 'Network connection error: $details',
          recoverySuggestion: 'Check your internet connection and try again');

  factory AuthException.cancelled() =>
      AuthException(AuthErrorType.cancelled, 'Authentication was cancelled',
          recoverySuggestion: 'Tap the login button to try again');

  factory AuthException.invalidCredentials() => AuthException(
      AuthErrorType.invalidCredentials, 'Invalid credentials provided',
      recoverySuggestion: 'Please check your credentials and try again');

  factory AuthException.configuration(String details) => AuthException(
      AuthErrorType.configuration, 'Configuration error: $details',
      recoverySuggestion: 'Please check your application configuration');
}

/// Auth0 implementation of the authentication provider using auth0_flutter
class Auth0AuthProvider implements AuthProvider {
  late final Auth0 _auth0;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Auth0 configuration
  final String _domain;
  final String _clientId;
  final String _audience;
  final String _redirectUrl;

  Auth0AuthProvider({
    String? domain,
    String? clientId,
    String? audience,
  })  : _domain = domain ??
            const String.fromEnvironment('AUTH0_DOMAIN',
                defaultValue: 'dev-v2f2p008x3dr74ww.us.auth0.com'),
        _clientId = clientId ??
            const String.fromEnvironment('AUTH0_CLIENT_ID',
                defaultValue: 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A'),
        _audience = audience ??
            const String.fromEnvironment('AUTH0_AUDIENCE',
                defaultValue: 'https://api.cloudtolocalllm.online'),
        _redirectUrl =
            '${UrlSchemeRegistrationService.customScheme}://dev-v2f2p008x3dr74ww.us.auth0.com/windows/${UrlSchemeRegistrationService.customScheme}/callback' {
    _appLinks = AppLinks();
    _auth0 = Auth0(_domain, _clientId);
  }

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  // Auth0 endpoints
  String get _authorizationEndpoint => 'https://$_domain/authorize';
  String get _tokenEndpoint => 'https://$_domain/oauth/token';
  // String get _userInfoEndpoint => 'https://$_domain/userinfo'; // Not used currently
  String get _endSessionEndpoint => 'https://$_domain/v2/logout';

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    try {
      // Register URL scheme for Windows desktop OAuth callbacks
      if (!kIsWeb && Platform.isWindows) {
        final isRegistered =
            await UrlSchemeRegistrationService.isSchemeRegistered();
        if (!isRegistered) {
          debugPrint(
              '[Auth0AuthProvider] Registering URL scheme for OAuth callbacks...');
          final registered =
              await UrlSchemeRegistrationService.registerUrlScheme();
          if (!registered) {
            debugPrint(
                '[Auth0AuthProvider] WARNING: Failed to register URL scheme. OAuth may not work.');
          }
        } else {
          debugPrint('[Auth0AuthProvider] URL scheme already registered');
        }

        // Listen for incoming URLs (OAuth callbacks)
        _linkSubscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
            debugPrint('[Auth0AuthProvider] Received URL callback: $uri');
            _handleIncomingUrl(uri);
          },
          onError: (err) {
            debugPrint('[Auth0AuthProvider] URL link stream error: $err');
          },
        );
      }

      // Check for existing credentials
      final accessToken = await _secureStorage.read(key: 'access_token');
      final idToken = await _secureStorage.read(key: 'id_token');

      if (accessToken != null && accessToken.isNotEmpty && idToken != null) {
        // Check if tokens are still valid
        if (!JwtDecoder.isExpired(accessToken) &&
            !JwtDecoder.isExpired(idToken)) {
          _currentUser = _idTokenToUser(idToken);
          _authStateController.add(true);
        } else {
          // Tokens expired, try to refresh
          final refreshToken = await _secureStorage.read(key: 'refresh_token');
          if (refreshToken != null) {
            await _refreshTokens(refreshToken);
          } else {
            _authStateController.add(false);
          }
        }
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Initialize error: $e');
      // No existing credentials
      _authStateController.add(false);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'access_token');
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Error getting access token: $e');
      return null;
    }
  }

  @override
  Future<void> login() async {
    try {
      debugPrint('[Auth0AuthProvider] Starting login');

      final result = await _auth0
          .webAuthentication(
        scheme: UrlSchemeRegistrationService.customScheme,
      )
          .login(
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        audience: _audience,
      );

      debugPrint('[Auth0AuthProvider] Login successful, storing tokens');

      // Store tokens securely
      await _secureStorage.write(
          key: 'access_token', value: result.accessToken);
      await _secureStorage.write(key: 'id_token', value: result.idToken);
      if (result.refreshToken != null) {
        await _secureStorage.write(
            key: 'refresh_token', value: result.refreshToken);
      }

      // Parse user info from ID token
      if (result.idToken.isNotEmpty) {
        _currentUser = _idTokenToUser(result.idToken);
        _authStateController.add(true);
      } else {
        throw AuthException.configuration('No ID token received');
      }
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Login error: $e');
      _authStateController.add(false);
      throw _categorizeError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Clear stored tokens
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'id_token');
      await _secureStorage.delete(key: 'refresh_token');

      _currentUser = null;
      _authStateController.add(false);

      // Perform logout with Auth0
      try {
        await _auth0
            .webAuthentication(
              scheme: UrlSchemeRegistrationService.customScheme,
            )
            .logout();
      } catch (e) {
        debugPrint('[Auth0AuthProvider] Logout error (non-critical): $e');
      }
    } catch (e) {
      // Even if logout fails, clear local state
      _currentUser = null;
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    // Auth0 Flutter handles callback automatically
    // This method is for compatibility with the interface
    return true;
  }

  /// Categorizes raw errors into structured AuthExceptions
  AuthException _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('cancelled') ||
        errorString.contains('user_cancelled')) {
      return AuthException.cancelled();
    } else if (errorString.contains('network') ||
        errorString.contains('timeout')) {
      return AuthException.network(error.toString());
    } else if (errorString.contains('invalid') ||
        errorString.contains('unauthorized')) {
      return AuthException.invalidCredentials();
    } else {
      return AuthException(
          AuthErrorType.unknown, 'Authentication failed: ${error.toString()}');
    }
  }

  /// Parses user information from ID token
  UserModel _idTokenToUser(String idToken) {
    final payload = JwtDecoder.decode(idToken);
    final now = DateTime.now();

    return UserModel(
      id: payload['sub'] ?? '',
      email: payload['email'] ?? '',
      name: payload['name'] ?? payload['email'] ?? '',
      nickname: payload['nickname'],
      picture: payload['picture'],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Refreshes access token using refresh token
  Future<void> _refreshTokens(String refreshToken) async {
    try {
      debugPrint('[Auth0AuthProvider] Refreshing tokens...');

      final result = await _appAuth.token(TokenRequest(
        _clientId,
        _redirectUrl,
        refreshToken: refreshToken,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: _authorizationEndpoint,
          tokenEndpoint: _tokenEndpoint,
          endSessionEndpoint: _endSessionEndpoint,
        ),
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        additionalParameters: {
          'audience': _audience,
        },
      ));

      debugPrint('[Auth0AuthProvider] Token refresh successful');

      // Store new tokens
      await _secureStorage.write(
          key: 'access_token', value: result.accessToken);
      if (result.idToken?.isNotEmpty == true) {
        await _secureStorage.write(key: 'id_token', value: result.idToken);
        _currentUser = _idTokenToUser(result.idToken!);
      }
      if (result.refreshToken?.isNotEmpty == true) {
        await _secureStorage.write(
            key: 'refresh_token', value: result.refreshToken);
      }

      _authStateController.add(true);
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Token refresh error: $e');
      _authStateController.add(false);
    }
  }

  /// Handles incoming URLs from OAuth callbacks
  void _handleIncomingUrl(Uri uri) {
    debugPrint('[Auth0AuthProvider] Processing OAuth callback URL: $uri');
    // The auth0_flutter package should handle the callback automatically
    // This is mainly for logging and debugging purposes
    if (uri.scheme == UrlSchemeRegistrationService.customScheme) {
      debugPrint(
          '[Auth0AuthProvider] Received OAuth callback with custom scheme');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _authStateController.close();
  }
}

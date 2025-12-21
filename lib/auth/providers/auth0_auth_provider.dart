import 'dart:async';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart'
    if (dart.library.io) 'auth0_flutter_stub.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/url_scheme_registration_service.dart'
    if (dart.library.js_interop) '../../services/url_scheme_registration_service_stub.dart';
import 'auth0_web_script_helper_stub.dart'
    if (dart.library.js_interop) 'auth0_web_script_helper_web.dart';
import '../../services/token_storage_service.dart';
import '../../services/session_storage_service.dart';
import '../../di/locator.dart' as di;

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
  Auth0Web? _auth0Web;
  late final TokenStorageService _tokenStorage;
  late final SessionStorageService _sessionStorage;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Auth0 configuration
  final String _domain;
  final String _clientId;
  final String _audience;

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
                defaultValue: 'https://api.cloudtolocalllm.online') {
    _appLinks = AppLinks();
    _tokenStorage = di.serviceLocator.get<TokenStorageService>();
    _sessionStorage = di.serviceLocator.get<SessionStorageService>();
    if (!kIsWeb) {
      _auth0 = Auth0(_domain, _clientId);
    } else {
      _auth0Web = Auth0Web(_domain, _clientId);
    }
  }

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    debugPrint('[Auth0AuthProvider] initialize() called');
    try {
      debugPrint('[Auth0AuthProvider] Initializing...');

      if (kIsWeb) {
        await _initializeWeb();
      } else {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          debugPrint(
              '[Auth0AuthProvider] Checking Windows URL scheme registration');
          final isRegistered =
              await UrlSchemeRegistrationService.isSchemeRegistered();
          if (!isRegistered) {
            debugPrint(
                '[Auth0AuthProvider] Registering URL scheme for OAuth callbacks...');
            await UrlSchemeRegistrationService.registerUrlScheme();
          }

          _linkSubscription = _appLinks.uriLinkStream.listen(
            (Uri uri) {
              debugPrint('[Auth0AuthProvider] Received URL callback: $uri');
              _handleIncomingUrl(uri);
            },
            onError: (err) =>
                debugPrint('[Auth0AuthProvider] URL link stream error: $err'),
          );
        }
      }

      // Check for existing session in PostgreSQL first
      final session = await _sessionStorage.getCurrentSession();
      if (session != null && session.isValid) {
        debugPrint('[Auth0AuthProvider] Found valid session in PostgreSQL');
        if (session.accessToken != null && session.idToken != null) {
          _currentUser = session.user;

          // Update local storage with tokens from PostgreSQL
          await _tokenStorage.saveToken('access_token', session.accessToken!);
          await _tokenStorage.saveToken('id_token', session.idToken!);
          if (session.refreshToken != null) {
            await _tokenStorage.saveToken(
                'refresh_token', session.refreshToken!);
          }

          _authStateController.add(true);
          return;
        }
      }

      // Fallback to local storage if PostgreSQL session is not available
      final accessToken = await _tokenStorage.getToken('access_token');
      final idToken = await _tokenStorage.getToken('id_token');

      if (accessToken != null && idToken != null) {
        debugPrint('[Auth0AuthProvider] Found tokens in secure SQLite storage');
        if (!JwtDecoder.isExpired(accessToken) &&
            !JwtDecoder.isExpired(idToken)) {
          debugPrint('[Auth0AuthProvider] Tokens are valid, restoring session');
          _currentUser = _idTokenToUser(idToken);
          _authStateController.add(true);
          return;
        } else {
          debugPrint('[Auth0AuthProvider] Tokens expired, attempting refresh');
          final refreshToken = await _tokenStorage.getToken('refresh_token');
          if (refreshToken != null) {
            await _refreshTokens(refreshToken);
            if (_currentUser != null) return;
          }
        }
      }

      // Web session recovery (silent login)
      if (kIsWeb && _auth0Web != null) {
        debugPrint(
            '[Auth0AuthProvider] No valid tokens in storage, attempting silent auth (prompt=none)...');
        try {
          final credentials = await _auth0Web!.onLoad();
          if (credentials != null) {
            debugPrint(
                '[Auth0AuthProvider] Web session recovered via onLoad()');
            await _storeCredentials(credentials);
            return;
          }
        } catch (e) {
          debugPrint(
              '[Auth0AuthProvider] Silent auth failed or no active session: $e');
        }
      }

      debugPrint('[Auth0AuthProvider] Initialized: No user session found');
      _authStateController.add(false);
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Initialize error: $e');
      _authStateController.add(false);
    }
  }

  Future<void> _initializeWeb() async {
    debugPrint('[Auth0AuthProvider] Initializing Web...');
    await loadAuth0Script();
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _tokenStorage.getToken('access_token');
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Error getting access token: $e');
      return null;
    }
  }

  Future<void> _storeCredentials(Credentials result) async {
    debugPrint('[Auth0AuthProvider] Storing credentials');

    if (result.idToken.isNotEmpty) {
      _currentUser = _idTokenToUser(result.idToken);

      // Create session in PostgreSQL
      try {
        final session = await _sessionStorage.createSession(
          user: _currentUser!,
          accessToken: result.accessToken,
        );
        debugPrint(
            '[Auth0AuthProvider] Session created in PostgreSQL: ${session.token}');

        // Sync tokens to PostgreSQL
        await _sessionStorage.syncTokens(
          sessionToken: session.token,
          accessToken: result.accessToken,
          idToken: result.idToken,
          refreshToken: result.refreshToken,
        );
      } catch (e) {
        debugPrint(
            '[Auth0AuthProvider] Failed to sync session to PostgreSQL: $e');
      }

      _authStateController.add(true);
    }

    // Still store locally as fallback/cache
    await _tokenStorage.saveToken('access_token', result.accessToken);
    await _tokenStorage.saveToken('id_token', result.idToken);
    if (result.refreshToken != null) {
      await _tokenStorage.saveToken('refresh_token', result.refreshToken!);
    }
  }

  @override
  Future<void> login() async {
    try {
      debugPrint('[Auth0AuthProvider] Starting interactive login');

      if (kIsWeb && _auth0Web != null) {
        final redirectUrl = Uri.base.origin;
        debugPrint('[Auth0AuthProvider] Using redirect URL: $redirectUrl');
        await _auth0Web!.loginWithRedirect(
          scopes: {'openid', 'profile', 'email', 'offline_access'},
          audience: _audience,
          redirectUri: redirectUrl.toString(),
        );
        // Note: loginWithRedirect will cause the page to reload.
        // The result will be processed in initialize() via onLoad() after the redirect back.
      } else {
        final result = await _auth0.webAuthentication().login(
          scopes: {'openid', 'profile', 'email', 'offline_access'},
          audience: _audience,
        );

        debugPrint('[Auth0AuthProvider] Login successful');
        await _storeCredentials(result);
      }
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Login error detail: $e');
      _authStateController.add(false);
      throw _categorizeError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Clear stored tokens
      await _tokenStorage.deleteToken('access_token');
      await _tokenStorage.deleteToken('id_token');
      await _tokenStorage.deleteToken('refresh_token');

      _currentUser = null;
      _authStateController.add(false);

      // Perform logout with Auth0
      try {
        if (kIsWeb) {
          if (_auth0Web != null) {
            await _auth0Web!.logout();
          }
        } else {
          if (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) {
            await _auth0
                .webAuthentication(
                  scheme: UrlSchemeRegistrationService.customScheme,
                )
                .logout();
          }
        }
      } catch (e) {
        debugPrint('[Auth0AuthProvider] Logout error (non-critical): $e');
      }
    } catch (e) {
      _currentUser = null;
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    return true;
  }

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

  Future<void> _refreshTokens(String refreshToken) async {
    try {
      debugPrint('[Auth0AuthProvider] Refreshing tokens...');

      Credentials credentials;
      if (kIsWeb && _auth0Web != null) {
        // Auth0Web doesn't have a direct equivalent for renewCredentials in the same way?
        // Actually it uses checkSession() internally.
        // For simplicity on web, if onLoad() fails, we just force login.
        return;
      } else {
        credentials = await _auth0.api.renewCredentials(
          refreshToken: refreshToken,
        );
      }

      await _storeCredentials(credentials);
      debugPrint('[Auth0AuthProvider] Token refresh successful');
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Token refresh error: $e');
      _authStateController.add(false);
    }
  }

  void _handleIncomingUrl(Uri uri) {
    debugPrint('[Auth0AuthProvider] Processing OAuth callback URL: $uri');
  }

  void dispose() {
    _linkSubscription?.cancel();
    _authStateController.close();
  }
}

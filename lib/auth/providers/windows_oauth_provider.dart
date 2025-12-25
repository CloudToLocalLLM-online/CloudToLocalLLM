import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/url_scheme_registration_service.dart';
import '../../services/session_storage_service.dart';
import '../../di/locator.dart' as di;

/// Windows-specific OAuth implementation for Auth0
/// Uses manual browser launch and URL scheme callback handling
class WindowsOAuthProvider implements AuthProvider {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final SessionStorageService _sessionStorage;
  // late final AppLinks _appLinks; // Used for deep link handling
  Completer<Map<String, String>>? _authCompleter;

  // Auth0 configuration
  final String _domain;
  final String _clientId;
  final String _audience;
  final String _redirectUrl;

  WindowsOAuthProvider({
    String? domain,
    String? clientId,
    String? audience,
  })  : _domain = domain ?? const String.fromEnvironment('AUTH0_DOMAIN'),
        _clientId = clientId ?? const String.fromEnvironment('AUTH0_CLIENT_ID'),
        _audience = audience ?? const String.fromEnvironment('AUTH0_AUDIENCE'),
        _redirectUrl =
            '${UrlSchemeRegistrationService.customScheme}://${domain ?? const String.fromEnvironment('AUTH0_DOMAIN')}/windows/${UrlSchemeRegistrationService.customScheme}/callback' {
    if (_domain.isEmpty || _clientId.isEmpty || _audience.isEmpty) {
      throw Exception(
          'CRITICAL: Missing required Auth0 environment variables for Windows provider. Zero-fallback policy in effect.');
    }
    _sessionStorage = di.serviceLocator.get<SessionStorageService>();
  }

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  // Auth0 endpoints
  String get _authorizationEndpoint => 'https://$_domain/authorize';
  String get _tokenEndpoint => 'https://$_domain/oauth/token';

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    try {
      // Register URL scheme for Windows desktop OAuth callbacks
      if (Platform.isWindows) {
        final isRegistered =
            await UrlSchemeRegistrationService.isSchemeRegistered();
        if (!isRegistered) {
          debugPrint(
              '[WindowsOAuth] Registering URL scheme for OAuth callbacks...');
          final registered =
              await UrlSchemeRegistrationService.registerUrlScheme();
          if (!registered) {
            debugPrint(
                '[WindowsOAuth] WARNING: Failed to register URL scheme. OAuth may not work.');
          }
        } else {
          debugPrint('[WindowsOAuth] URL scheme already registered');
        }

        // Start monitoring for callback files (alternative to app_links)
        _startCallbackFileMonitoring();
      }

      // Check for existing session in PostgreSQL first
      final session = await _sessionStorage.getCurrentSession();
      if (session != null && session.isValid) {
        debugPrint('[WindowsOAuth] Found valid session in PostgreSQL');
        if (session.accessToken != null && session.idToken != null) {
          _currentUser = session.user;

          // Update local storage with tokens from PostgreSQL
          await _secureStorage.write(
              key: 'access_token', value: session.accessToken!);
          await _secureStorage.write(key: 'id_token', value: session.idToken!);
          if (session.refreshToken != null) {
            await _secureStorage.write(
                key: 'refresh_token', value: session.refreshToken!);
          }

          _authStateController.add(true);
          return;
        }
      }

      // Check for existing credentials locally
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
      debugPrint('[WindowsOAuth] Initialize error: $e');
      _authStateController.add(false);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'access_token');
    } catch (e) {
      debugPrint('[WindowsOAuth] Error getting access token: $e');
      return null;
    }
  }

  @override
  Future<void> login() async {
    try {
      debugPrint('[WindowsOAuth] Starting OAuth login flow...');

      // Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);
      final nonce = _generateRandomString(32);

      // Store PKCE parameters for later use
      await _secureStorage.write(key: 'code_verifier', value: codeVerifier);
      await _secureStorage.write(key: 'oauth_state', value: state);
      await _secureStorage.write(key: 'oauth_nonce', value: nonce);

      // Build authorization URL
      final authUrl =
          Uri.parse(_authorizationEndpoint).replace(queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUrl,
        'scope': 'openid profile email offline_access',
        'audience': _audience,
        'state': state,
        'nonce': nonce,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      debugPrint('[WindowsOAuth] Opening browser with URL: $authUrl');

      // Set up completer to wait for callback
      _authCompleter = Completer<Map<String, String>>();

      // Launch browser
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);

        // Wait for callback with timeout
        final callbackParams = await _authCompleter!.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () =>
              throw Exception('OAuth timeout - no callback received'),
        );

        // Exchange authorization code for tokens
        await _exchangeCodeForTokens(
            callbackParams, codeVerifier, state, nonce);
      } else {
        throw Exception('Could not launch browser for OAuth');
      }
    } catch (e) {
      debugPrint('[WindowsOAuth] Login error: $e');
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Clear stored tokens
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'id_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'code_verifier');
      await _secureStorage.delete(key: 'oauth_state');
      await _secureStorage.delete(key: 'oauth_nonce');

      _currentUser = null;
      _authStateController.add(false);

      debugPrint('[WindowsOAuth] Logout completed');
    } catch (e) {
      // Even if logout fails, clear local state
      _currentUser = null;
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (url != null) {
      final uri = Uri.parse(url);
      _handleIncomingUrl(uri);
      return true;
    }
    return false;
  }

  /// Handles incoming URLs from OAuth callbacks
  void _handleIncomingUrl(Uri uri) {
    debugPrint('[WindowsOAuth] Processing OAuth callback URL: $uri');
    debugPrint('[WindowsOAuth] URI scheme: ${uri.scheme}');
    debugPrint(
        '[WindowsOAuth] Expected scheme: ${UrlSchemeRegistrationService.customScheme}');
    debugPrint('[WindowsOAuth] URI query parameters: ${uri.queryParameters}');
    debugPrint(
        '[WindowsOAuth] Auth completer exists: ${_authCompleter != null}');

    if (uri.scheme == UrlSchemeRegistrationService.customScheme &&
        _authCompleter != null) {
      final params = uri.queryParameters;

      if (params.containsKey('error')) {
        debugPrint(
            '[WindowsOAuth] OAuth error received: ${params['error']} - ${params['error_description']}');
        _authCompleter!.completeError(Exception(
            'OAuth error: ${params['error']} - ${params['error_description']}'));
      } else if (params.containsKey('code')) {
        debugPrint(
            '[WindowsOAuth] Authorization code received: ${params['code']?.substring(0, 10)}...');
        _authCompleter!.complete(params);
      } else {
        debugPrint(
            '[WindowsOAuth] Invalid callback - no code or error in parameters');
        _authCompleter!.completeError(
            Exception('Invalid OAuth callback - no code or error'));
      }
    } else {
      debugPrint(
          '[WindowsOAuth] Callback ignored - wrong scheme or no completer');
    }
  }

  /// Exchanges authorization code for tokens
  Future<void> _exchangeCodeForTokens(
    Map<String, String> callbackParams,
    String codeVerifier,
    String expectedState,
    String nonce,
  ) async {
    try {
      // Verify state parameter
      final receivedState = callbackParams['state'];
      if (receivedState != expectedState) {
        throw Exception('OAuth state mismatch - possible CSRF attack');
      }

      final authCode = callbackParams['code']!;
      debugPrint('[WindowsOAuth] Exchanging authorization code for tokens...');

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'code': authCode,
          'redirect_uri': _redirectUrl,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        await _storeCredentials(tokenData);
        debugPrint('[WindowsOAuth] Login successful!');
      } else {
        throw Exception(
            'Token exchange failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[WindowsOAuth] Token exchange error: $e');
      _authStateController.add(false);
      rethrow;
    }
  }

  Future<void> _storeCredentials(Map<String, dynamic> result) async {
    debugPrint('[WindowsOAuth] Storing credentials');

    final accessToken = result['access_token'] as String;
    final idToken = result['id_token'] as String;
    final refreshToken = result['refresh_token'] as String?;

    if (idToken.isNotEmpty) {
      _currentUser = _idTokenToUser(idToken);

      // Create session in PostgreSQL
      try {
        final session = await _sessionStorage.createSession(
          user: _currentUser!,
          accessToken: accessToken,
        );
        debugPrint(
            '[WindowsOAuth] Session created in PostgreSQL: ${session.token}');

        // Sync tokens to PostgreSQL
        await _sessionStorage.syncTokens(
          sessionToken: session.token,
          accessToken: accessToken,
          idToken: idToken,
          refreshToken: refreshToken,
        );
      } catch (e) {
        debugPrint('[WindowsOAuth] Failed to sync session to PostgreSQL: $e');
      }

      _authStateController.add(true);
    }

    // Still store locally as fallback/cache
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'id_token', value: idToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }
  }

  /// Refreshes access token using refresh token
  Future<void> _refreshTokens(String refreshToken) async {
    try {
      debugPrint('[WindowsOAuth] Refreshing tokens...');

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        await _storeCredentials(tokenData);
        debugPrint('[WindowsOAuth] Token refresh successful');
      } else {
        debugPrint(
            '[WindowsOAuth] Token refresh failed: ${response.statusCode}');
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('[WindowsOAuth] Token refresh error: $e');
      _authStateController.add(false);
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

  /// Generates a cryptographically secure random string for PKCE code verifier
  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Generates PKCE code challenge from code verifier
  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random string for state/nonce parameters
  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (i) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Starts monitoring for callback files written by new app instances
  void _startCallbackFileMonitoring() {
    debugPrint('[WindowsOAuth] Starting callback file monitoring...');

    // Check for callback files every 500ms during OAuth flow
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_authCompleter == null) {
        // No active OAuth flow, stop monitoring
        return;
      }

      _checkForCallbackFile();
    });
  }

  /// Checks for callback files and processes them
  Future<void> _checkForCallbackFile() async {
    try {
      final tempDir = Directory.systemTemp;
      final callbackFile = File('${tempDir.path}/cloudtolocalllm_callback.txt');

      if (await callbackFile.exists()) {
        final callbackUrl = await callbackFile.readAsString();
        debugPrint('[WindowsOAuth] Found callback file with URL: $callbackUrl');

        // Delete the file to prevent reprocessing
        await callbackFile.delete();

        // Process the callback URL
        final uri = Uri.parse(callbackUrl);
        _handleIncomingUrl(uri);
      }
    } catch (e) {
      debugPrint('[WindowsOAuth] Error checking callback file: $e');
    }
  }

  void dispose() {
    _authStateController.close();
  }
}

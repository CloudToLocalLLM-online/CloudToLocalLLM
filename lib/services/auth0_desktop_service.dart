import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth0_service.dart';

/// Auth0 Desktop Service for Flutter Desktop/Mobile platforms
/// Implements PKCE flow for secure authentication
class Auth0DesktopService implements Auth0Service {
  static final Auth0DesktopService _instance = Auth0DesktopService._internal();
  factory Auth0DesktopService() => _instance;
  Auth0DesktopService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Storage keys
  static const String _accessTokenKey = 'auth0_access_token';
  static const String _refreshTokenKey = 'auth0_refresh_token';
  static const String _userKey = 'auth0_user';
  static const String _codeVerifierKey = 'auth0_code_verifier';
  
  final _authStateController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  
  // PKCE code verifier for the current auth session
  String? _codeVerifier;

  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  Map<String, dynamic>? get currentUser => _currentUser;
  
  @override
  String? getAccessToken() => _accessToken;
  
  @override
  Future<bool> handleRedirectCallback() async {
    // Desktop handles redirects internally via the callback server
    return true;
  }

  @override
  Future<void> initialize() async {
    try {
      debugPrint('🔐 [Auth0Desktop] Initializing desktop auth service');
      
      // Check if we have stored tokens
      await checkAuthStatus();
      
      debugPrint('✅ [Auth0Desktop] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Initialization error: $e');
    }
  }

  /// Check authentication status using stored tokens
  Future<void> checkAuthStatus() async {
    try {
      _accessToken = await _storage.read(key: _accessTokenKey);
      _refreshToken = await _storage.read(key: _refreshTokenKey);
      final userJson = await _storage.read(key: _userKey);
      
      if (userJson != null) {
        _currentUser = jsonDecode(userJson);
      }
      
      if (_accessToken != null && _currentUser != null) {
        // Validate token is not expired
        if (await _isTokenValid(_accessToken!)) {
          _isAuthenticated = true;
          debugPrint('✅ [Auth0Desktop] User is authenticated');
        } else {
          // Token expired, try to refresh
          debugPrint('⚠️ [Auth0Desktop] Token expired, attempting refresh');
          if (_refreshToken != null) {
            await _refreshAccessToken();
          } else {
            await logout();
          }
        }
      } else {
        _isAuthenticated = false;
        debugPrint('ℹ️ [Auth0Desktop] User is not authenticated');
      }
      
      _authStateController.add(_isAuthenticated);
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Error checking auth status: $e');
      _isAuthenticated = false;
      _authStateController.add(false);
    }
  }

  @override
  Future<void> login() async {
    try {
      debugPrint('🔐 [Auth0Desktop] Starting Auth0 login with PKCE');
      
      // Generate PKCE values
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);
      
      // Store code verifier for later
      await _storage.write(key: _codeVerifierKey, value: _codeVerifier!);
      
      // Generate state parameter for CSRF protection
      final state = _generateRandomString();
      
      // Build authorization URL
      final authUrl = _buildAuthorizationUrl(codeChallenge, state);
      
      // Start listening for callback FIRST
      debugPrint('🔊 [Auth0Desktop] Starting callback server on localhost:8080');
      final callbackFuture = _waitForCallback();
      
      // Give server a moment to start
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('🌐 [Auth0Desktop] Opening browser for authentication');
      
      // Launch browser for authentication
      if (!await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication)) {
        throw Exception('Failed to launch authentication URL');
      }
      
      // Wait for callback
      final result = await callbackFuture;
      
      if (result['code'] != null && result['state'] != null) {
        await handleAuthorizationCode(result['code']!, result['state']!);
      } else if (result['error'] != null) {
        throw Exception('Auth0 error: ${result['error']} - ${result['error_description'] ?? ''}');
      }
      
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Login error: $e');
      rethrow;
    }
  }
  
  /// Wait for callback from Auth0
  Future<Map<String, String?>> _waitForCallback() async {
    final completer = Completer<Map<String, String?>>();
    HttpServer? server;
    
    try {
      // Start HTTP server on localhost:8080
      // Try to bind to IPv4 loopback, if that fails try any IPv4 interface
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
        debugPrint('✅ [Auth0Desktop] Callback server listening on 127.0.0.1:8080');
      } catch (e) {
        debugPrint('⚠️ [Auth0Desktop] Loopback bind failed, trying any IPv4: $e');
        server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
        debugPrint('✅ [Auth0Desktop] Callback server listening on 0.0.0.0:8080');
      }
      
      // Handle incoming requests
      server.listen((request) async {
        if (request.method == 'GET') {
          debugPrint('📥 [Auth0Desktop] Received callback: ${request.uri}');
          
          // Parse query parameters
          final params = request.uri.queryParameters;
          final code = params['code'];
          final state = params['state'];
          final error = params['error'];
          final errorDescription = params['error_description'];
          
          // Send success response
          final response = request.response;
          response.statusCode = 200;
          response.headers.contentType = ContentType.html;
          response.write('''
            <html>
              <head>
                <title>Authentication Complete</title>
                <style>
                  body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                  }
                  .card {
                    background: white;
                    padding: 2rem;
                    border-radius: 10px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.3);
                    text-align: center;
                  }
                  .success {
                    color: #4CAF50;
                    font-size: 3rem;
                    margin-bottom: 1rem;
                  }
                  h1 {
                    color: #333;
                    margin: 0 0 1rem 0;
                  }
                  p {
                    color: #666;
                    margin: 0;
                  }
                </style>
              </head>
              <body>
                <div class="card">
                  <div class="success">✓</div>
                  <h1>Authentication Complete!</h1>
                  <p>You can close this window and return to the app.</p>
                </div>
              </body>
            </html>
          ''');
          await response.close();
          
          // Complete the future with result
          if (!completer.isCompleted) {
            completer.complete({
              'code': code,
              'state': state,
              'error': error,
              'error_description': errorDescription,
            });
          }
        }
      });
      
      // Wait for callback with timeout
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Authentication timeout - no callback received');
        },
      );
      
      // Close server
      await server.close(force: true);
      debugPrint('✅ [Auth0Desktop] Callback received, server closed');
      
      return result;
      
    } catch (e) {
      if (server != null) {
        await server.close(force: true).catchError((_) {});
      }
      rethrow;
    }
  }

  /// Exchange authorization code for tokens
  Future<void> handleAuthorizationCode(String code, String state) async {
    try {
      debugPrint('🔄 [Auth0Desktop] Handling authorization code');
      
      // Retrieve stored code verifier
      final storedVerifier = await _storage.read(key: _codeVerifierKey);
      if (storedVerifier == null) {
        throw Exception('No code verifier found. Please restart the login flow.');
      }
      
      // Exchange code for tokens
      final tokenResponse = await _exchangeCodeForTokens(code, storedVerifier);
      
      // Extract tokens
      _accessToken = tokenResponse['access_token'] as String?;
      _refreshToken = tokenResponse['refresh_token'] as String?;
      
      if (_accessToken == null) {
        throw Exception('No access token received from Auth0');
      }
      
      // Get user info
      await _fetchUserInfo();
      
      // Store tokens
      await _storage.write(key: _accessTokenKey, value: _accessToken!);
      if (_refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
      }
      await _storage.write(key: _userKey, value: jsonEncode(_currentUser));
      
      // Clean up code verifier
      await _storage.delete(key: _codeVerifierKey);
      
      _isAuthenticated = true;
      _authStateController.add(true);
      
      debugPrint('✅ [Auth0Desktop] Authentication successful');
      
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Error handling authorization code: $e');
      await logout();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      debugPrint('🔐 [Auth0Desktop] Logging out');
      
      // Clear all stored data
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userKey);
      await _storage.delete(key: _codeVerifierKey);
      
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
      _refreshToken = null;
      
      _authStateController.add(false);
      
      debugPrint('✅ [Auth0Desktop] Logged out successfully');
      
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Logout error: $e');
    }
  }

  @override
  bool isCallbackUrl() {
    // Desktop doesn't use URL callbacks
    return false;
  }

  @override
  void dispose() {
    _authStateController.close();
  }

  // Private helper methods

  /// Build the authorization URL with PKCE parameters
  String _buildAuthorizationUrl(String codeChallenge, String state) {
    final redirectUri = 'http://localhost:8080'; // Match Auth0 configuration
    
    return Uri.https(AppConfig.auth0Domain, 'authorize', {
      'response_type': 'code',
      'client_id': AppConfig.auth0ClientId,
      'redirect_uri': redirectUri,
      'audience': AppConfig.auth0Audience,
      'scope': 'openid profile email offline_access',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
    }).toString();
  }

  /// Exchange authorization code for tokens
  Future<Map<String, dynamic>> _exchangeCodeForTokens(String code, String codeVerifier) async {
    final redirectUri = 'http://localhost:8080';
    
    // Build form-urlencoded body manually
    final bodyParams = {
      'grant_type': 'authorization_code',
      'client_id': AppConfig.auth0ClientId,
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': codeVerifier,
    };
    
    final bodyString = bodyParams.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    
    debugPrint('🔄 [Auth0Desktop] Exchanging code for tokens');
    
    final uri = Uri.https(AppConfig.auth0Domain, '/oauth/token');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: bodyString,
    );
    
    debugPrint('📥 [Auth0Desktop] Token response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      debugPrint('❌ [Auth0Desktop] Token exchange failed: ${response.body}');
      throw Exception('Token exchange failed: ${response.body}');
    }
    
    final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('✅ [Auth0Desktop] Token exchange successful');
    return tokenData;
  }

  /// Fetch user information from Auth0
  Future<void> _fetchUserInfo() async {
    final uri = Uri.https(AppConfig.auth0Domain, '/userinfo');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    
    if (response.statusCode == 200) {
      _currentUser = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('✅ [Auth0Desktop] User info fetched: ${_currentUser?['email']}');
    } else {
      throw Exception('Failed to fetch user info: ${response.body}');
    }
  }

  /// Refresh the access token using refresh token
  Future<void> _refreshAccessToken() async {
    try {
      debugPrint('🔄 [Auth0Desktop] Refreshing access token');
      
      // Build form-urlencoded body manually
      final bodyParams = {
        'grant_type': 'refresh_token',
        'client_id': AppConfig.auth0ClientId,
        'refresh_token': _refreshToken!,
      };
      
      final bodyString = bodyParams.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      
      final uri = Uri.https(AppConfig.auth0Domain, '/oauth/token');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyString,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
        
        await _storage.write(key: _accessTokenKey, value: _accessToken!);
        await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
        
        debugPrint('✅ [Auth0Desktop] Access token refreshed');
      } else {
        throw Exception('Token refresh failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Error refreshing token: $e');
      await logout();
      rethrow;
    }
  }

  /// Check if token is valid (not expired)
  Future<bool> _isTokenValid(String token) async {
    try {
      // Decode JWT to check expiration
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      final payload = parts[1];
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      
      final exp = claims['exp'] as int?;
      if (exp == null) return false;
      
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      
      // Token is valid if it hasn't expired (with 5 minute buffer)
      return now.isBefore(expirationTime.subtract(const Duration(minutes: 5)));
      
    } catch (e) {
      debugPrint('❌ [Auth0Desktop] Error validating token: $e');
      return false;
    }
  }

  /// Generate a random code verifier for PKCE
  String _generateCodeVerifier() {
    final encoded = base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256)));
    // Remove padding (=) as per PKCE spec
    return encoded.replaceAll('=', '');
  }

  /// Generate code challenge from verifier (SHA256)
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    final encoded = base64Url.encode(digest.bytes);
    // Remove padding (=) as per PKCE spec
    return encoded.replaceAll('=', '');
  }

  /// Generate random string for state parameter
  String _generateRandomString() {
    return base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256)));
  }

  static final Random _random = Random.secure();
}


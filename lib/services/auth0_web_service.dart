import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

class Auth0WebService implements Auth0Service {
  late Auth0Web _auth0Web;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  @override
  String? getAccessToken() => _accessToken;

  @override
  Future<void> initialize() async {
    debugPrint('[Auth0WebService] Initializing Auth0Web...');
    _auth0Web = Auth0Web(
      'dev-v2f2p008x3dr74ww.us.auth0.com',
      'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A',
    );

    // onLoad handles the callback if present
    await _auth0Web.onLoad(
      audience: 'https://api.cloudtolocalllm.online',
    );
    
    await checkAuthStatus();
    debugPrint('[Auth0WebService] Initialization complete.');
  }

  @override
  Future<void> login() async {
    debugPrint('[Auth0WebService] Logging in with redirect...');
    await _auth0Web.loginWithRedirect(
      audience: 'https://api.cloudtolocalllm.online',
      scopes: {'openid', 'profile', 'email', 'offline_access'},
      redirectUrl: Uri.base.origin,
    );
  }

  @override
  Future<void> logout() async {
    debugPrint('[Auth0WebService] Logging out...');
    await _auth0Web.logout(returnToUrl: Uri.base.origin);
    _isAuthenticated = false;
    _currentUser = null;
    _accessToken = null;
    _authStateController.add(false);
  }

  @override
  bool isCallbackUrl() {
    final url = Uri.base.toString();
    return url.contains('code=') && url.contains('state=');
  }

  @override
  Future<bool> handleRedirectCallback() async {
    // auth0_flutter handles callback automatically in onLoad()
    // We just need to check status
    await checkAuthStatus();
    return _isAuthenticated;
  }

  Future<void> checkAuthStatus() async {
    try {
      final hasSession = await _auth0Web.hasValidCredentials();
      if (hasSession) {
        final credentials = await _auth0Web.credentials();
        _accessToken = credentials.accessToken;
        _currentUser = credentials.user.toMap();
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
        _currentUser = null;
        _accessToken = null;
      }
      _authStateController.add(_isAuthenticated);
    } catch (e) {
      debugPrint('[Auth0WebService] Error checking auth status: $e');
      _isAuthenticated = false;
      _authStateController.add(false);
    }
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}

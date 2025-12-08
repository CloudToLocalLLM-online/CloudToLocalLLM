import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
// import 'dart:js_interop.unsafe';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/auth/auth_provider.dart';

/// JS Interop for MSAL
@JS('msal.PublicClientApplication')
extension type PublicClientApplication._(JSObject _) implements JSObject {
  external PublicClientApplication(JSObject config);
  external JSPromise initialize();
  external JSPromise loginPopup(JSObject? request);
  external JSPromise loginRedirect(JSObject? request);
  external JSPromise handleRedirectPromise();
  external JSPromise acquireTokenSilent(JSObject request);
  external JSObject getAllAccounts();
  external JSObject getAccountByHomeId(String homeId);
  external JSPromise logoutPopup();
  external JSPromise logoutRedirect();
}

@JS('msal.AccountInfo')
extension type AccountInfo._(JSObject _) implements JSObject {
  external String get homeAccountId;
  external String get environment;
  external String get tenantId;
  external String get username;
  external String get name;
  external String get idToken;
}

@JS('msal.AuthenticationResult')
extension type AuthenticationResult._(JSObject _) implements JSObject {
  external String get accessToken;
  external String get idToken;
  external AccountInfo get account;
}

/// Entra (Azure AD B2C) Authentication Provider using MSAL.js
class EntraAuthProvider implements AuthProvider {
  PublicClientApplication? _msalInstance;
  final _authStateController = StreamController<bool>.broadcast();
  UserModel? _currentUser;

  final String _clientId = '4829629c-4ae8-42a5-9def-bd28fbfd6992';
  final String _authority =
      'https://cloudtolocalllm.b2clogin.com/cloudtolocalllm.onmicrosoft.com/B2X_1_cloudtolocalllm';
  final List<String> _scopes = [
    'https://cloudtolocalllm.onmicrosoft.com/api/read'
  ];
  final String _redirectUri = kIsWeb ? Uri.base.origin : 'http://localhost';

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    if (!kIsWeb) {
      debugPrint(
          '[EntraAuthProvider] Not running on Web, skipping initialization');
      return;
    }

    try {
      debugPrint('[EntraAuthProvider] Initializing MSAL...');
      debugPrint('[EntraAuthProvider] Client ID: $_clientId');
      debugPrint('[EntraAuthProvider] Authority: $_authority');
      debugPrint('[EntraAuthProvider] Redirect URI: $_redirectUri');

      final msalConfig = {
        'auth': {
          'clientId': _clientId,
          'authority': _authority,
          'redirectUri': _redirectUri,
          'navigateToLoginRequestUrl': true,
          'knownAuthorities': ['cloudtolocalllm.b2clogin.com'],
        },
        'cache': {
          'cacheLocation': 'localStorage',
          'storeAuthStateInCookie': true,
        },
        'system': {
          'allowNativeBroker': false
        }
      }.jsify() as JSObject;

      _msalInstance = PublicClientApplication(msalConfig);
      await _msalInstance!.initialize().toDart;

      // Handle redirect promise if returning from redirect login
      await _handleRedirect();

      // Check if user is already signed in
      _checkCurrentAccount();

      debugPrint('[EntraAuthProvider] MSAL initialized successfully');
    } catch (e) {
      debugPrint('[EntraAuthProvider] Failed to initialize MSAL: $e');
    }
  }

  Future<void> _handleRedirect() async {
    try {
      final resultPromise = _msalInstance!.handleRedirectPromise();
      final result = await resultPromise.toDart;
      if (result != null) {
        final authResult = result as AuthenticationResult;
        _updateUserFromAccount(authResult.account);
      }
    } catch (e) {
      debugPrint('[EntraAuthProvider] Handle redirect error: $e');
    }
  }

  void _checkCurrentAccount() {
    if (_msalInstance == null) return;
    // Basic implementation: get first account
    final accounts = _msalInstance!.getAllAccounts();
    // This is a rough array check in JS interop
    final accountsList = (accounts as JSArray<AccountInfo>);

    if (accountsList.length > 0) {
      final account = accountsList.toDart[0];
      _updateUserFromAccount(account);
    }
  }

  void _updateUserFromAccount(AccountInfo account) {
    _currentUser = UserModel(
      id: account.homeAccountId,
      email: account.username,
      name: account.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
    debugPrint('[EntraAuthProvider] User signed in: ${account.username}');
  }

  @override
  Future<void> login() async {
    if (_msalInstance == null) return;

    final loginRequest = {
      'scopes': _scopes,
    }.jsify() as JSObject;

    try {
      await _msalInstance!.loginRedirect(loginRequest).toDart;
    } catch (e) {
      debugPrint('[EntraAuthProvider] Login failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    if (_msalInstance == null) return;
    try {
      await _msalInstance!.logoutRedirect().toDart;
      _currentUser = null;
      _authStateController.add(false);
    } catch (e) {
      debugPrint('[EntraAuthProvider] Logout failed: $e');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    if (_currentUser == null || _msalInstance == null) return null;

    try {
      // Need to find the account again
      final accounts = _msalInstance!.getAllAccounts();
      final accountsList = (accounts as JSArray<AccountInfo>);
      if (accountsList.length == 0) return null;
      final account = accountsList.toDart[0];

      final request =
          {'scopes': _scopes, 'account': account}.jsify() as JSObject;

      final response = await _msalInstance!.acquireTokenSilent(request).toDart;
      final authResult = response as AuthenticationResult;
      return authResult.accessToken;
    } catch (e) {
      debugPrint('[EntraAuthProvider] Failed to acquire token silent: $e');
      // Fallback to interaction needed? usually handled by caller or triggers login
      return null;
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    await _handleRedirect();
    return _currentUser != null;
  }
}

import 'dart:async';
import 'package:auth0_flutter/auth0_flutter.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';

/// Auth0 implementation of the authentication provider
class Auth0AuthProvider implements AuthProvider {
  final Auth0 _auth0;
  final String _audience;

  Auth0AuthProvider({
    String? domain,
    String? clientId,
    String? audience,
  }) : _auth0 = Auth0(domain ?? 'dev-v2f2p008x3dr74ww.us.auth0.com', clientId ?? 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A'),
        _audience = audience ?? 'https://dev-v2f2p008x3dr74ww.us.auth0.com/api/v2/';

  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  UserModel? _currentUser;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      if (credentials != null && credentials.accessToken.isNotEmpty) {
        _currentUser = _credentialsToUser(credentials);
        _authStateController.add(true);
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      _authStateController.add(false);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      return credentials?.accessToken;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> login() async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        audience: _audience,
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _currentUser = _credentialsToUser(credentials);
      await _auth0.credentialsManager.storeCredentials(credentials);
      _authStateController.add(true);
    } catch (e) {
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _auth0.webAuthentication().logout();
      await _auth0.credentialsManager.clearCredentials();
      _currentUser = null;
      _authStateController.add(false);
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

  UserModel _credentialsToUser(Credentials credentials) {
    final userInfo = credentials.user;
    final now = DateTime.now();
    return UserModel(
      id: userInfo.sub,
      email: userInfo.email ?? '',
      name: userInfo.name,
      picture: userInfo.name, // Using name as fallback since picture property doesn't exist
      createdAt: now,
      updatedAt: now,
      // Add other user properties as needed
    );
  }

  void dispose() {
    _authStateController.close();
  }
}
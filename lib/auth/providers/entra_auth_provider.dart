import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/token_storage_service.dart';
import '../../services/session_storage_service.dart';
import '../../di/locator.dart' as di;

/// Microsoft Entra ID (formerly Azure AD) implementation of the authentication provider
class EntraAuthProvider implements AuthProvider {
  late final TokenStorageService _tokenStorage;
  late final SessionStorageService _sessionStorage;

  // Entra configuration
  // ignore: unused_field
  final String _clientId;
  // ignore: unused_field
  final String _tenantId;
  // ignore: unused_field
  final String _issuerUrl;

  EntraAuthProvider({
    String? clientId,
    String? tenantId,
    String? issuerUrl,
  })  : _clientId = clientId ??
            const String.fromEnvironment('ENTRA_CLIENT_ID',
                defaultValue: '1a72fdf6-4e48-4cb8-943b-a4a4ac513148'),
        _tenantId = tenantId ??
            const String.fromEnvironment('ENTRA_TENANT_ID',
                defaultValue: '42eebf0f-1c60-4408-b681-21fe4a4b4dc1'),
        _issuerUrl = issuerUrl ??
            const String.fromEnvironment('ENTRA_ISSUER_URL',
                defaultValue:
                    'https://login.microsoftonline.com/42eebf0f-1c60-4408-b681-21fe4a4b4dc1/v2.0') {
    _tokenStorage = di.serviceLocator.get<TokenStorageService>();
    _sessionStorage = di.serviceLocator.get<SessionStorageService>();
  }

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<String?> getAccessToken() async {
    return await _tokenStorage.getToken('access_token');
  }

  @override
  Future<void> initialize() async {
    debugPrint('[EntraAuthProvider] Initializing...');
    try {
      final session = await _sessionStorage.getCurrentSession();
      if (session != null && session.isValid) {
        _currentUser = session.user;
        _authStateController.add(true);
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('[EntraAuthProvider] Initialization error: $e');
      _authStateController.add(false);
    }
  }

  @override
  Future<void> login() async {
    debugPrint('[EntraAuthProvider] Login not fully implemented yet.');
    throw UnimplementedError('Entra ID login is not yet implemented.');
  }

  @override
  Future<void> logout() async {
    debugPrint('[EntraAuthProvider] Logging out...');
    final session = _sessionStorage.currentSession;
    if (session != null) {
      await _sessionStorage.invalidateSession(session.token);
    }
    await _tokenStorage.clearAll();
    _currentUser = null;
    _authStateController.add(false);
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    return false;
  }
}

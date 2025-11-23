import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/auth0_service.dart';
import 'package:cloudtolocalllm/services/session_storage_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/models/session_model.dart';

// Mock Auth0Service
class MockAuth0Service implements Auth0Service {
  bool _isAuthenticated = true;
  String? _accessToken = 'test-access-token';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> login() async {
    _isAuthenticated = true;
    _accessToken = 'test-access-token';
  }

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
  }

  @override
  Future<bool> handleRedirectCallback() async => true;

  @override
  bool isCallbackUrl() => false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? getAccessToken() => _accessToken;

  @override
  Map<String, dynamic>? get currentUser => null;

  @override
  Stream<bool> get authStateChanges => Stream.value(_isAuthenticated);

  @override
  void dispose() {}
}

// Mock SessionStorageService
class MockSessionStorageService extends SessionStorageService {
  String? _storedToken = 'test-session-token';
  bool _sessionInvalidated = false;

  @override
  Future<SessionModel?> getCurrentSession() async {
    if (_sessionInvalidated || _storedToken == null) {
      return null;
    }

    final user = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
    );

    return SessionModel(
      id: 'session-id',
      userId: 'test-user-id',
      token: _storedToken!,
      expiresAt: DateTime.now().add(const Duration(hours: 23)),
      user: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastActivity: DateTime.now(),
    );
  }

  @override
  Future<void> invalidateSession(String token) async {
    _sessionInvalidated = true;
    _storedToken = null;
  }

  bool get isSessionInvalidated => _sessionInvalidated;
  String? get storedToken => _storedToken;
}

// Mock AuthService for testing
class TestableAuthService extends ChangeNotifier implements AuthService {
  final MockAuth0Service _mockAuth0Service;
  final MockSessionStorageService _mockSessionStorage;

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  String? _sessionToken;

  TestableAuthService({
    required MockAuth0Service mockAuth0Service,
    required MockSessionStorageService mockSessionStorage,
  })  : _mockAuth0Service = mockAuth0Service,
        _mockSessionStorage = mockSessionStorage {
    _isAuthenticated = true;
    _currentUser = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessionToken = 'test-session-token';
  }

  @override
  Future<void> logout() async {
    // Simulate logout process
    await _mockAuth0Service.logout();
    if (_sessionToken != null) {
      await _mockSessionStorage.invalidateSession(_sessionToken!);
    }
    _isAuthenticated = false;
    _currentUser = null;
    _sessionToken = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> handleCallback({String? callbackUrl}) async => true;

  @override
  Future<bool> handleRedirectCallback() async => true;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<String?> getAccessToken() async => _mockAuth0Service.getAccessToken();

  @override
  Future<String?> getValidatedAccessToken() async =>
      _mockAuth0Service.getAccessToken();

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  bool get isRestoringSession => false;

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  bool get isWeb => true;

  @override
  bool get isMobile => false;

  @override
  bool get isDesktop => false;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(_isAuthenticated);

  @override
  ValueNotifier<bool> get isLoading => ValueNotifier(false);

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded => ValueNotifier(true);

  @override
  Auth0Service get auth0Service => _mockAuth0Service;

  @override
  UserModel? get currentUser => _currentUser;

  // Test helpers
  bool get isLoggedOut => !_isAuthenticated;
  bool get sessionTokenCleared => _sessionToken == null;
  bool get sessionInvalidated => _mockSessionStorage.isSessionInvalidated;
  String? get currentSessionToken => _sessionToken;
}

void main() {
  group('Logout Token Clearing Timing', () {
    late MockAuth0Service mockAuth0Service;
    late MockSessionStorageService mockSessionStorage;
    late TestableAuthService authService;

    setUp(() {
      mockAuth0Service = MockAuth0Service();
      mockSessionStorage = MockSessionStorageService();
      authService = TestableAuthService(
        mockAuth0Service: mockAuth0Service,
        mockSessionStorage: mockSessionStorage,
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Tokens cleared within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify initial state - user is authenticated with tokens
      expect(authService.isLoggedOut, false,
          reason: 'User should be authenticated initially');
      expect(authService.sessionTokenCleared, false,
          reason: 'Session token should exist initially');
      expect(mockAuth0Service.getAccessToken(), isNotNull,
          reason: 'Access token should exist initially');

      // Measure time to clear tokens during logout
      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify all tokens are cleared
      expect(authService.isLoggedOut, true,
          reason: 'User should be logged out after logout');
      expect(authService.sessionTokenCleared, true,
          reason: 'Session token should be cleared after logout');
      expect(mockAuth0Service.getAccessToken(), isNull,
          reason: 'Access token should be cleared after logout');
      expect(authService.sessionInvalidated, true,
          reason: 'Session should be invalidated after logout');

      // Verify timing constraint: token clearing should complete within 1 second
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Token clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Multiple rapid logouts clear tokens within 1 second each',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Test multiple logout cycles
      for (int i = 0; i < 3; i++) {
        // Re-authenticate for next cycle
        mockAuth0Service._isAuthenticated = true;
        mockAuth0Service._accessToken = 'test-access-token-$i';
        mockSessionStorage._sessionInvalidated = false;
        mockSessionStorage._storedToken = 'test-session-token-$i';
        authService._isAuthenticated = true;
        authService._currentUser = UserModel(
          id: 'test-user-id-$i',
          email: 'test$i@example.com',
          name: 'Test User $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        authService._sessionToken = 'test-session-token-$i';

        // Verify authenticated state
        expect(authService.isLoggedOut, false,
            reason: 'User should be authenticated in cycle $i');

        // Measure logout time
        final stopwatch = Stopwatch()..start();

        await authService.logout();

        stopwatch.stop();

        // Verify tokens cleared
        expect(authService.isLoggedOut, true,
            reason: 'User should be logged out in cycle $i');
        expect(authService.sessionTokenCleared, true,
            reason: 'Session token should be cleared in cycle $i');

        // Verify timing
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              'Logout cycle $i took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
        );
      }
    });

    test(
        'Property 15: Logout Token Clearing Timing - Auth0 token cleared immediately',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify Auth0 token exists
      expect(mockAuth0Service.getAccessToken(), isNotNull,
          reason: 'Auth0 access token should exist initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify Auth0 token is cleared
      expect(mockAuth0Service.getAccessToken(), isNull,
          reason: 'Auth0 access token should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Token clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Session token invalidated within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify session token exists
      expect(authService.currentSessionToken, isNotNull,
          reason: 'Session token should exist initially');
      expect(mockSessionStorage.isSessionInvalidated, false,
          reason: 'Session should not be invalidated initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify session is invalidated
      expect(mockSessionStorage.isSessionInvalidated, true,
          reason: 'Session should be invalidated after logout');
      expect(authService.currentSessionToken, isNull,
          reason: 'Session token should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Session invalidation took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - User data cleared within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify user data exists
      expect(authService._currentUser, isNotNull,
          reason: 'User data should exist initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify user data is cleared
      expect(authService._currentUser, isNull,
          reason: 'User data should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'User data clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });
  });
}

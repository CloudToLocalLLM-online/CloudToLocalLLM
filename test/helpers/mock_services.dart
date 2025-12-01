/// Mock services for testing
///
/// Provides mock implementations of core services for use in property-based
/// and integration tests. These mocks allow tests to run in isolation without
/// requiring full service initialization.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';

/// Initialize mock plugins for testing
Future<void> initializeMockPlugins() async {
  // Set up SharedPreferences mock
  SharedPreferences.setMockInitialValues({});
}

/// Mock JWT Service for testing
class MockJWTService {
  bool isAuthenticated = false;
  String? accessToken;
  String? idToken;
  Map<String, dynamic>? userProfile;

  Future<void> login() async {
    isAuthenticated = true;
    accessToken = 'mock_access_token';
    idToken = 'mock_id_token';
    userProfile = {
      'sub': 'mock_user_id',
      'email': 'test@example.com',
      'name': 'Test User',
    };
  }

  Future<void> logout() async {
    isAuthenticated = false;
    accessToken = null;
    idToken = null;
    userProfile = null;
  }
}

/// Mock Session Storage for testing
class MockSessionStorage {
  final Map<String, String> _storage = {};

  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  Future<String?> read({required String key}) async {
    return _storage[key];
  }

  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  Future<void> deleteAll() async {
    _storage.clear();
  }
}

/// Mock AuthService for testing
class MockAuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _userId;
  Map<String, dynamic>? _userProfile;

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  Map<String, dynamic>? get userProfile => _userProfile;

  Future<void> login() async {
    _isAuthenticated = true;
    _accessToken = 'mock_access_token';
    _userId = 'mock_user_id';
    _userProfile = {
      'sub': 'mock_user_id',
      'email': 'test@example.com',
      'name': 'Test User',
    };
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
    _userId = null;
    _userProfile = null;
    notifyListeners();
  }

  Future<bool> checkSession() async {
    return _isAuthenticated;
  }
}

/// Mock AdminCenterService for testing
class MockAdminCenterService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => _users;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));

    _users = [
      {
        'id': 'user1',
        'email': 'user1@example.com',
        'name': 'User One',
      },
      {
        'id': 'user2',
        'email': 'user2@example.com',
        'name': 'User Two',
      },
    ];

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteUser(String userId) async {
    _users.removeWhere((user) => user['id'] == userId);
    notifyListeners();
  }
}

/// Creates a mock AuthService with optional authentication state
MockAuthService createMockAuthService({bool authenticated = false}) {
  final service = MockAuthService();
  if (authenticated) {
    service.login();
  }
  return service;
}

/// Creates a mock AdminCenterService
MockAdminCenterService createMockAdminCenterService() {
  return MockAdminCenterService();
}

/// Mock PlatformDetectionService for testing
class MockPlatformDetectionService extends PlatformDetectionService {
  bool _isWeb = false;
  bool _isAndroid = false;
  bool _isIOS = false;
  bool _isWindows = false;
  bool _isLinux = false;
  bool _isMacOS = false;

  @override
  bool get isWeb => _isWeb;
  @override
  bool get isWindows => _isWindows;
  @override
  bool get isLinux => _isLinux;
  @override
  bool get isMacOS => _isMacOS;
  @override
  bool get isMobile => _isAndroid || _isIOS;
  @override
  bool get isDesktop => _isWindows || _isLinux || _isMacOS;

  void setPlatform({
    bool isWeb = false,
    bool isAndroid = false,
    bool isIOS = false,
    bool isWindows = false,
    bool isLinux = false,
    bool isMacOS = false,
  }) {
    _isWeb = isWeb;
    _isAndroid = isAndroid;
    _isIOS = isIOS;
    _isWindows = isWindows;
    _isLinux = isLinux;
    _isMacOS = isMacOS;
    notifyListeners();
  }
}

/// Mock PlatformAdapter for testing
class MockPlatformAdapter extends PlatformAdapter {
  MockPlatformAdapter() : super(MockPlatformDetectionService());
}

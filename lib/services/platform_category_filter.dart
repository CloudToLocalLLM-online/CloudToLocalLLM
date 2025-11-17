/// Platform Category Filter Service
///
/// Determines which settings categories should be visible based on the current
/// platform and user role (admin status, subscription tier).
library;

import 'package:flutter/foundation.dart';
import '../models/settings_category.dart';
import 'auth_service.dart';
import 'admin_center_service.dart';
import 'enhanced_user_tier_service.dart';

/// Service for filtering settings categories based on platform and user role
class PlatformCategoryFilter extends ChangeNotifier {
  final AuthService _authService;
  final AdminCenterService? _adminCenterService;
  final EnhancedUserTierService? _tierService;

  // Platform detection
  late final bool _isWeb;
  late final bool _isWindows;
  late final bool _isLinux;
  late final bool _isAndroid;
  late final bool _isIOS;

  // Cached values
  bool? _cachedIsAdminUser;
  bool? _cachedIsPremiumUser;
  DateTime? _lastAdminCheckTime;
  DateTime? _lastPremiumCheckTime;

  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);

  PlatformCategoryFilter({
    required AuthService authService,
    AdminCenterService? adminCenterService,
    EnhancedUserTierService? tierService,
  })  : _authService = authService,
        _adminCenterService = adminCenterService,
        _tierService = tierService {
    _initializePlatformDetection();
    _authService.addListener(_onAuthStateChanged);
  }

  /// Initialize platform detection
  void _initializePlatformDetection() {
    _isWeb = kIsWeb;

    if (!_isWeb) {
      // For non-web platforms, use dart:io Platform
      try {
        // ignore: avoid_dynamic_calls
        final platform = (const bool.fromEnvironment('dart.library.io'))
            ? _detectNativePlatform()
            : _PlatformInfo();
        _isWindows = platform.isWindows;
        _isLinux = platform.isLinux;
        _isAndroid = platform.isAndroid;
        _isIOS = platform.isIOS;
      } catch (e) {
        debugPrint('[PlatformCategoryFilter] Error detecting platform: $e');
        _isWindows = false;
        _isLinux = false;
        _isAndroid = false;
        _isIOS = false;
      }
    } else {
      _isWindows = false;
      _isLinux = false;
      _isAndroid = false;
      _isIOS = false;
    }

    debugPrint(
      '[PlatformCategoryFilter] Platform detection: isWeb=$_isWeb, isWindows=$_isWindows, isLinux=$_isLinux, isAndroid=$_isAndroid, isIOS=$_isIOS',
    );
  }

  /// Detect native platform (non-web)
  _PlatformInfo _detectNativePlatform() {
    try {
      // ignore: avoid_dynamic_calls
      final platform = (const bool.fromEnvironment('dart.library.io'))
          ? _PlatformInfo()
          : _PlatformInfo();
      return platform;
    } catch (e) {
      debugPrint(
          '[PlatformCategoryFilter] Error detecting native platform: $e');
      return _PlatformInfo();
    }
  }

  /// Handle auth state changes
  void _onAuthStateChanged() {
    // Clear cached values when auth state changes
    _cachedIsAdminUser = null;
    _cachedIsPremiumUser = null;
    _lastAdminCheckTime = null;
    _lastPremiumCheckTime = null;
    notifyListeners();
  }

  /// Check if user is an admin (with caching)
  Future<bool> isAdminUser() async {
    // Return cached value if still valid
    if (_cachedIsAdminUser != null && _lastAdminCheckTime != null) {
      if (DateTime.now().difference(_lastAdminCheckTime!) < _cacheDuration) {
        return _cachedIsAdminUser ?? false;
      }
    }

    try {
      // Check if admin center service is available and initialized
      if (_adminCenterService != null && _adminCenterService.isInitialized) {
        final isAdmin =
            _adminCenterService.isSuperAdmin || _adminCenterService.isAdmin;
        _cachedIsAdminUser = isAdmin;
        _lastAdminCheckTime = DateTime.now();
        return isAdmin;
      }

      // Fallback: default to false
      _cachedIsAdminUser = false;
      _lastAdminCheckTime = DateTime.now();
      return false;
    } catch (e) {
      debugPrint('[PlatformCategoryFilter] Error checking admin status: $e');
      _cachedIsAdminUser = false;
      _lastAdminCheckTime = DateTime.now();
      return false;
    }
  }

  /// Check if user is a premium user (with caching)
  Future<bool> isPremiumUser() async {
    // Return cached value if still valid
    if (_cachedIsPremiumUser != null && _lastPremiumCheckTime != null) {
      if (DateTime.now().difference(_lastPremiumCheckTime!) < _cacheDuration) {
        return _cachedIsPremiumUser!;
      }
    }

    try {
      // Check if tier service is available and initialized
      final tierService = _tierService;
      if (tierService != null && tierService.isInitialized) {
        final isPremium = tierService.isPremiumTier;
        _cachedIsPremiumUser = isPremium;
        _lastPremiumCheckTime = DateTime.now();
        return isPremium;
      }

      // Fallback: default to false
      _cachedIsPremiumUser = false;
      _lastPremiumCheckTime = DateTime.now();
      return false;
    } catch (e) {
      debugPrint('[PlatformCategoryFilter] Error checking premium status: $e');
      _cachedIsPremiumUser = false;
      _lastPremiumCheckTime = DateTime.now();
      return false;
    }
  }

  /// Get visible categories for current platform and user
  Future<List<BaseSettingsCategory>> getVisibleCategories(
    List<BaseSettingsCategory> allCategories,
  ) async {
    final isAdmin = await isAdminUser();
    final isPremium = await isPremiumUser();

    final visibleCategories = allCategories.where((category) {
      // Check platform visibility
      if (!CategoryVisibilityRules.isVisibleOnPlatform(
        category.id,
        isWeb: _isWeb,
        isWindows: _isWindows,
        isLinux: _isLinux,
        isAndroid: _isAndroid,
        isIOS: _isIOS,
      )) {
        return false;
      }

      // Check user role visibility
      if (!CategoryVisibilityRules.isVisibleForUserRole(
        categoryId: category.id,
        isAdminUser: isAdmin,
        isPremiumUser: isPremium,
      )) {
        return false;
      }

      return true;
    }).toList();

    // Sort by priority
    visibleCategories.sort((a, b) => a.priority.compareTo(b.priority));

    return visibleCategories;
  }

  /// Check if a specific category is visible
  Future<bool> isCategoryVisible(String categoryId) async {
    final isAdmin = await isAdminUser();
    final isPremium = await isPremiumUser();

    // Check platform visibility
    if (!CategoryVisibilityRules.isVisibleOnPlatform(
      categoryId,
      isWeb: _isWeb,
      isWindows: _isWindows,
      isLinux: _isLinux,
      isAndroid: _isAndroid,
      isIOS: _isIOS,
    )) {
      return false;
    }

    // Check user role visibility
    if (!CategoryVisibilityRules.isVisibleForUserRole(
      categoryId: categoryId,
      isAdminUser: isAdmin,
      isPremiumUser: isPremium,
    )) {
      return false;
    }

    return true;
  }

  /// Get platform information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'isWeb': _isWeb,
      'isWindows': _isWindows,
      'isLinux': _isLinux,
      'isAndroid': _isAndroid,
      'isIOS': _isIOS,
      'isDesktop': _isWindows || _isLinux,
      'isMobile': _isAndroid || _isIOS,
    };
  }

  /// Get user role information for debugging
  Future<Map<String, dynamic>> getUserRoleInfo() async {
    final isAdmin = await isAdminUser();
    final isPremium = await isPremiumUser();

    return {
      'isAdmin': isAdmin,
      'isPremium': isPremium,
      'isAuthenticated': _authService.isAuthenticated.value,
    };
  }

  // Getters for platform detection
  bool get isWeb => _isWeb;
  bool get isWindows => _isWindows;
  bool get isLinux => _isLinux;
  bool get isAndroid => _isAndroid;
  bool get isIOS => _isIOS;
  bool get isDesktop => _isWindows || _isLinux;
  bool get isMobile => _isAndroid || _isIOS;

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}

/// Helper class for platform detection (stub for web)
class _PlatformInfo {
  bool get isWindows {
    try {
      // ignore: avoid_dynamic_calls
      return (const bool.fromEnvironment('dart.library.io'))
          ? _checkPlatform('windows')
          : false;
    } catch (e) {
      return false;
    }
  }

  bool get isLinux {
    try {
      // ignore: avoid_dynamic_calls
      return (const bool.fromEnvironment('dart.library.io'))
          ? _checkPlatform('linux')
          : false;
    } catch (e) {
      return false;
    }
  }

  bool get isAndroid {
    try {
      // ignore: avoid_dynamic_calls
      return (const bool.fromEnvironment('dart.library.io'))
          ? _checkPlatform('android')
          : false;
    } catch (e) {
      return false;
    }
  }

  bool get isIOS {
    try {
      // ignore: avoid_dynamic_calls
      return (const bool.fromEnvironment('dart.library.io'))
          ? _checkPlatform('ios')
          : false;
    } catch (e) {
      return false;
    }
  }

  bool _checkPlatform(String platform) {
    try {
      // This will be replaced by actual Platform checks at runtime
      // For now, return false as a safe default
      return false;
    } catch (e) {
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// User subscription tiers for CloudToLocalLLM
///
/// Defines the available subscription levels and their corresponding
/// feature access levels. Used throughout the application to control
/// feature availability and UI presentation.
enum UserTier {
  free('free'),
  premium('premium'),
  enterprise('enterprise');

  const UserTier(this.value);
  final String value;

  /// Convert string value to UserTier enum with validation
  ///
  /// @param value The string representation of the tier
  /// @returns UserTier enum value, defaults to free for invalid input
  static UserTier fromString(String? value) {
    if (value == null || value.isEmpty) {
      return UserTier.free;
    }

    switch (value.toLowerCase().trim()) {
      case 'premium':
        return UserTier.premium;
      case 'enterprise':
        return UserTier.enterprise;
      case 'free':
      default:
        return UserTier.free;
    }
  }
}

/// Feature flags and limits based on user tier
///
/// Defines what features and limits are available for each subscription tier.
/// Used to control UI elements, API access, and functionality throughout
/// the application.
class TierFeatures {
  final bool containerOrchestration;
  final bool teamFeatures;
  final bool apiAccess;
  final bool prioritySupport;
  final bool advancedNetworking;
  final bool multipleInstances;
  final int maxConnections;
  final int maxModels;

  const TierFeatures({
    required this.containerOrchestration,
    required this.teamFeatures,
    required this.apiAccess,
    required this.prioritySupport,
    required this.advancedNetworking,
    required this.multipleInstances,
    required this.maxConnections,
    required this.maxModels,
  });

  static const TierFeatures free = TierFeatures(
    containerOrchestration: false,
    teamFeatures: false,
    apiAccess: false,
    prioritySupport: false,
    advancedNetworking: false,
    multipleInstances: false,
    maxConnections: 1,
    maxModels: 5,
  );

  static const TierFeatures premium = TierFeatures(
    containerOrchestration: true,
    teamFeatures: true,
    apiAccess: true,
    prioritySupport: true,
    advancedNetworking: true,
    multipleInstances: true,
    maxConnections: 10,
    maxModels: 50,
  );

  static const TierFeatures enterprise = TierFeatures(
    containerOrchestration: true,
    teamFeatures: true,
    apiAccess: true,
    prioritySupport: true,
    advancedNetworking: true,
    multipleInstances: true,
    maxConnections: -1, // unlimited
    maxModels: -1, // unlimited
  );
}

/// Service to manage user tier detection and feature flags
class UserTierService extends ChangeNotifier {
  final AuthService _authService;
  
  UserTier _currentTier = UserTier.free;
  TierFeatures _currentFeatures = TierFeatures.free;
  bool _isLoading = false;
  String? _error;

  UserTierService({required AuthService authService}) : _authService = authService {
    // Listen to auth changes to update tier
    _authService.addListener(_onAuthChanged);
    _updateTierFromAuth();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  // Getters
  UserTier get currentTier => _currentTier;
  TierFeatures get currentFeatures => _currentFeatures;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Convenience getters for common feature checks
  bool get hasContainerOrchestration => _currentFeatures.containerOrchestration;
  bool get hasTeamFeatures => _currentFeatures.teamFeatures;
  bool get hasApiAccess => _currentFeatures.apiAccess;
  bool get hasPrioritySupport => _currentFeatures.prioritySupport;
  bool get hasAdvancedNetworking => _currentFeatures.advancedNetworking;
  bool get hasMultipleInstances => _currentFeatures.multipleInstances;

  bool get isFree => _currentTier == UserTier.free;
  bool get isPremium => _currentTier == UserTier.premium;
  bool get isEnterprise => _currentTier == UserTier.enterprise;

  /// Update tier when auth state changes
  void _onAuthChanged() {
    _updateTierFromAuth();
  }

  /// Extract tier from Auth0 user metadata with comprehensive error handling
  ///
  /// Attempts to determine user tier from multiple possible locations in
  /// Auth0 user metadata. Falls back to free tier on any error.
  Future<void> _updateTierFromAuth() async {
    if (!_authService.isAuthenticated.value) {
      if (kDebugMode) {
        debugPrint('🎯 [UserTier] User not authenticated, setting free tier');
      }
      _setTier(UserTier.free);
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      // For now, we'll use a simplified approach and get tier from access token
      // In a production environment, you would decode the JWT token or make an API call
      // to get the full user profile with metadata

      final accessToken = await _authService.getValidatedAccessToken();
      if (accessToken == null) {
        if (kDebugMode) {
          debugPrint('🎯 [UserTier] No access token available, defaulting to free tier');
        }
        _setTier(UserTier.free);
        return;
      }

      // For MVP implementation, we'll default to free tier
      // FUTURE ENHANCEMENT: Implement proper JWT decoding or API call to get user metadata
      // This should be replaced with actual tier detection from Auth0 metadata
      // See GitHub issue #XXX for implementation details
      String? tierValue = 'free'; // Default to free for now

      if (kDebugMode) {
        debugPrint('🎯 [UserTier] Using default tier detection (MVP implementation)');
      }

      // Convert to tier enum with validation
      final tier = UserTier.fromString(tierValue);
      _setTier(tier);

      if (kDebugMode) {
        debugPrint('🎯 [UserTier] Successfully detected tier: ${tier.value} for user: ${_authService.currentUser?.id ?? "unknown"}');
      }

    } catch (e) {
      _setError('Failed to determine user tier: $e');
      _setTier(UserTier.free); // Default to free on error

      if (kDebugMode) {
        debugPrint('❌ [UserTier] Error determining tier: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Set the current tier and update features
  void _setTier(UserTier tier) {
    if (_currentTier != tier) {
      _currentTier = tier;
      _currentFeatures = _getFeaturesForTier(tier);
      notifyListeners();
    }
  }

  /// Get features for a specific tier
  TierFeatures _getFeaturesForTier(UserTier tier) {
    switch (tier) {
      case UserTier.free:
        return TierFeatures.free;
      case UserTier.premium:
        return TierFeatures.premium;
      case UserTier.enterprise:
        return TierFeatures.enterprise;
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error state
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Force refresh tier from auth service
  Future<void> refreshTier() async {
    await _updateTierFromAuth();
  }

  /// Check if a specific feature is available
  bool hasFeature(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'containers':
      case 'container_orchestration':
        return hasContainerOrchestration;
      case 'teams':
      case 'team_features':
        return hasTeamFeatures;
      case 'api':
      case 'api_access':
        return hasApiAccess;
      case 'support':
      case 'priority_support':
        return hasPrioritySupport;
      case 'networking':
      case 'advanced_networking':
        return hasAdvancedNetworking;
      case 'multiple_instances':
        return hasMultipleInstances;
      default:
        return false;
    }
  }

  /// Get upgrade message for a specific feature
  String getUpgradeMessage(String featureName) {
    if (isFree) {
      return 'Upgrade to Premium to unlock $featureName and other advanced features.';
    } else if (isPremium) {
      return 'Upgrade to Enterprise for unlimited $featureName and priority support.';
    }
    return 'This feature is available in your current plan.';
  }
}

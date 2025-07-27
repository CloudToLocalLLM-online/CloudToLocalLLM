import 'package:flutter/foundation.dart';

/// Feature flags for the first-time setup wizard
///
/// This class manages feature flags that control the rollout and behavior
/// of the setup wizard. It integrates with remote configuration to allow
/// dynamic control without app updates.
class SetupWizardFeatureFlags {
  // Singleton pattern for global access
  static final SetupWizardFeatureFlags _instance =
      SetupWizardFeatureFlags._internal();
  factory SetupWizardFeatureFlags() => _instance;
  SetupWizardFeatureFlags._internal();

  // Default values for feature flags (used when remote config is unavailable)
  static const bool _defaultEnabled = false;
  static const int _defaultRolloutPercentage = 0;
  static const bool _defaultAllowSkip = true;
  static const int _defaultMaxRetries = 3;
  static const int _defaultStepTimeoutSeconds = 300; // 5 minutes
  static const bool _defaultAnalyticsEnabled = true;
  static const bool _defaultContainerCreationEnabled = true;
  static const bool _defaultPlatformDetectionEnabled = true;
  static const bool _defaultDownloadTrackingEnabled = true;

  // Remote configuration instance (to be injected)
  dynamic _remoteConfig;

  /// Initialize with remote configuration instance
  void initialize(dynamic remoteConfig) {
    _remoteConfig = remoteConfig;
  }

  /// Whether the setup wizard is enabled globally
  bool get isEnabled {
    try {
      return _remoteConfig?.getBool('setup_wizard_enabled') ?? _defaultEnabled;
    } catch (e) {
      debugPrint('Error reading setup_wizard_enabled flag: $e');
      return _defaultEnabled;
    }
  }

  /// Percentage of users who should see the setup wizard (0-100)
  int get rolloutPercentage {
    try {
      final percentage =
          _remoteConfig?.getInt('setup_wizard_rollout_percentage') ??
          _defaultRolloutPercentage;
      return percentage.clamp(0, 100);
    } catch (e) {
      debugPrint('Error reading setup_wizard_rollout_percentage flag: $e');
      return _defaultRolloutPercentage;
    }
  }

  /// Whether users can skip steps in the setup wizard
  bool get allowSkipping {
    try {
      return _remoteConfig?.getBool('setup_wizard_allow_skip') ??
          _defaultAllowSkip;
    } catch (e) {
      debugPrint('Error reading setup_wizard_allow_skip flag: $e');
      return _defaultAllowSkip;
    }
  }

  /// Maximum number of retries for failed operations
  int get maxRetries {
    try {
      final retries =
          _remoteConfig?.getInt('setup_wizard_max_retries') ??
          _defaultMaxRetries;
      return retries.clamp(1, 10);
    } catch (e) {
      debugPrint('Error reading setup_wizard_max_retries flag: $e');
      return _defaultMaxRetries;
    }
  }

  /// Timeout for each setup step in seconds
  Duration get stepTimeout {
    try {
      final seconds =
          _remoteConfig?.getInt('setup_wizard_step_timeout') ??
          _defaultStepTimeoutSeconds;
      return Duration(
        seconds: seconds.clamp(30, 1800),
      ); // 30 seconds to 30 minutes
    } catch (e) {
      debugPrint('Error reading setup_wizard_step_timeout flag: $e');
      return Duration(seconds: _defaultStepTimeoutSeconds);
    }
  }

  /// Whether analytics collection is enabled for the setup wizard
  bool get analyticsEnabled {
    try {
      return _remoteConfig?.getBool('setup_wizard_analytics_enabled') ??
          _defaultAnalyticsEnabled;
    } catch (e) {
      debugPrint('Error reading setup_wizard_analytics_enabled flag: $e');
      return _defaultAnalyticsEnabled;
    }
  }

  /// Whether container creation is enabled (can be disabled for maintenance)
  bool get containerCreationEnabled {
    try {
      return _remoteConfig?.getBool(
            'setup_wizard_container_creation_enabled',
          ) ??
          _defaultContainerCreationEnabled;
    } catch (e) {
      debugPrint(
        'Error reading setup_wizard_container_creation_enabled flag: $e',
      );
      return _defaultContainerCreationEnabled;
    }
  }

  /// Whether automatic platform detection is enabled
  bool get platformDetectionEnabled {
    try {
      return _remoteConfig?.getBool(
            'setup_wizard_platform_detection_enabled',
          ) ??
          _defaultPlatformDetectionEnabled;
    } catch (e) {
      debugPrint(
        'Error reading setup_wizard_platform_detection_enabled flag: $e',
      );
      return _defaultPlatformDetectionEnabled;
    }
  }

  /// Whether download tracking is enabled
  bool get downloadTrackingEnabled {
    try {
      return _remoteConfig?.getBool('setup_wizard_download_tracking_enabled') ??
          _defaultDownloadTrackingEnabled;
    } catch (e) {
      debugPrint(
        'Error reading setup_wizard_download_tracking_enabled flag: $e',
      );
      return _defaultDownloadTrackingEnabled;
    }
  }

  /// Get custom configuration value with fallback
  T getCustomConfig<T>(String key, T defaultValue) {
    try {
      if (T == bool) {
        return (_remoteConfig?.getBool(key) ?? defaultValue) as T;
      } else if (T == int) {
        return (_remoteConfig?.getInt(key) ?? defaultValue) as T;
      } else if (T == double) {
        return (_remoteConfig?.getDouble(key) ?? defaultValue) as T;
      } else if (T == String) {
        return (_remoteConfig?.getString(key) ?? defaultValue) as T;
      } else {
        return defaultValue;
      }
    } catch (e) {
      debugPrint('Error reading custom config $key: $e');
      return defaultValue;
    }
  }
}

/// Rollout strategy for gradual feature deployment
class SetupWizardRollout {
  static final SetupWizardFeatureFlags _flags = SetupWizardFeatureFlags();

  /// Determine if a user should see the setup wizard based on rollout strategy
  static bool shouldShowWizard(String userId) {
    // Check if feature is globally enabled
    if (!_flags.isEnabled) {
      return false;
    }

    // Check rollout percentage
    final rolloutPercentage = _flags.rolloutPercentage;
    if (rolloutPercentage == 0) {
      return false;
    }

    if (rolloutPercentage >= 100) {
      return true;
    }

    // Use consistent hash-based rollout
    final hash = _hashUserId(userId);
    return (hash % 100) < rolloutPercentage;
  }

  /// Generate consistent hash for user ID
  static int _hashUserId(String userId) {
    // Use a simple but consistent hash function
    int hash = 0;
    for (int i = 0; i < userId.length; i++) {
      hash = ((hash << 5) - hash + userId.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.abs();
  }

  /// Check if user is in a specific rollout group (for A/B testing)
  static bool isInRolloutGroup(
    String userId,
    String groupName,
    int percentage,
  ) {
    if (percentage <= 0) return false;
    if (percentage >= 100) return true;

    final combinedId = '$userId:$groupName';
    final hash = _hashUserId(combinedId);
    return (hash % 100) < percentage;
  }
}

/// Configuration for different deployment environments
class SetupWizardEnvironmentConfig {
  static final SetupWizardFeatureFlags _flags = SetupWizardFeatureFlags();

  /// Get environment-specific configuration
  static Map<String, dynamic> getEnvironmentConfig() {
    final env = _getEnvironment();

    switch (env) {
      case 'development':
        return {
          'enabled': true,
          'rollout_percentage': 100,
          'allow_skip': true,
          'max_retries': 5,
          'step_timeout': 600, // 10 minutes for debugging
          'analytics_enabled': false,
          'debug_mode': true,
        };

      case 'staging':
        return {
          'enabled': true,
          'rollout_percentage': 100,
          'allow_skip': true,
          'max_retries': 3,
          'step_timeout': 300,
          'analytics_enabled': true,
          'debug_mode': true,
        };

      case 'production':
        return {
          'enabled': _flags.isEnabled,
          'rollout_percentage': _flags.rolloutPercentage,
          'allow_skip': _flags.allowSkipping,
          'max_retries': _flags.maxRetries,
          'step_timeout': _flags.stepTimeout.inSeconds,
          'analytics_enabled': _flags.analyticsEnabled,
          'debug_mode': false,
        };

      default:
        return {
          'enabled': false,
          'rollout_percentage': 0,
          'allow_skip': true,
          'max_retries': 3,
          'step_timeout': 300,
          'analytics_enabled': false,
          'debug_mode': false,
        };
    }
  }

  /// Detect current environment
  static String _getEnvironment() {
    if (kDebugMode) {
      return 'development';
    }

    // Check for staging environment indicators
    const stagingIndicators = ['staging', 'test', 'dev'];
    final currentUrl = Uri.base.host.toLowerCase();

    for (final indicator in stagingIndicators) {
      if (currentUrl.contains(indicator)) {
        return 'staging';
      }
    }

    return 'production';
  }
}

/// Utility class for feature flag debugging and monitoring
class SetupWizardFeatureFlagDebug {
  static final SetupWizardFeatureFlags _flags = SetupWizardFeatureFlags();

  /// Get all current feature flag values for debugging
  static Map<String, dynamic> getAllFlags() {
    return {
      'enabled': _flags.isEnabled,
      'rollout_percentage': _flags.rolloutPercentage,
      'allow_skip': _flags.allowSkipping,
      'max_retries': _flags.maxRetries,
      'step_timeout_seconds': _flags.stepTimeout.inSeconds,
      'analytics_enabled': _flags.analyticsEnabled,
      'container_creation_enabled': _flags.containerCreationEnabled,
      'platform_detection_enabled': _flags.platformDetectionEnabled,
      'download_tracking_enabled': _flags.downloadTrackingEnabled,
    };
  }

  /// Log current feature flag configuration
  static void logCurrentConfiguration() {
    if (kDebugMode) {
      final flags = getAllFlags();
      debugPrint('Setup Wizard Feature Flags:');
      flags.forEach((key, value) {
        debugPrint('  $key: $value');
      });
    }
  }

  /// Validate feature flag configuration
  static List<String> validateConfiguration() {
    final issues = <String>[];

    if (_flags.rolloutPercentage < 0 || _flags.rolloutPercentage > 100) {
      issues.add('Rollout percentage must be between 0 and 100');
    }

    if (_flags.maxRetries < 1 || _flags.maxRetries > 10) {
      issues.add('Max retries must be between 1 and 10');
    }

    if (_flags.stepTimeout.inSeconds < 30 ||
        _flags.stepTimeout.inSeconds > 1800) {
      issues.add('Step timeout must be between 30 seconds and 30 minutes');
    }

    return issues;
  }
}

/// Remote configuration integration interface
abstract class RemoteConfigProvider {
  bool getBool(String key);
  int getInt(String key);
  double getDouble(String key);
  String getString(String key);
  Future<void> fetchAndActivate();
}

/// Mock remote configuration for testing
class MockRemoteConfig implements RemoteConfigProvider {
  final Map<String, dynamic> _values = {};

  void setValue(String key, dynamic value) {
    _values[key] = value;
  }

  @override
  bool getBool(String key) => _values[key] as bool? ?? false;

  @override
  int getInt(String key) => _values[key] as int? ?? 0;

  @override
  double getDouble(String key) => _values[key] as double? ?? 0.0;

  @override
  String getString(String key) => _values[key] as String? ?? '';

  @override
  Future<void> fetchAndActivate() async {
    // Mock implementation
  }
}

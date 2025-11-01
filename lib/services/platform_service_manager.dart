import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform service manager for graceful degradation of platform-specific features
///
/// Handles initialization and management of platform-specific services with
/// proper error handling and fallback mechanisms for unsupported platforms.
class PlatformServiceManager extends ChangeNotifier {
  // Platform detection
  bool _isWeb = kIsWeb;
  bool _isDesktop = false;
  bool _isMobile = false;
  String _platformName = 'unknown';

  // Service availability
  bool _nativeTrayAvailable = false;
  bool _windowManagerAvailable = false;
  bool _fileSystemAvailable = false;
  bool _localOllamaAvailable = false;

  // Initialization status
  bool _isInitialized = false;
  final List<String> _initializationErrors = [];
  final Map<String, bool> _serviceStatus = {};

  // Getters
  bool get isWeb => _isWeb;
  bool get isDesktop => _isDesktop;
  bool get isMobile => _isMobile;
  String get platformName => _platformName;
  bool get nativeTrayAvailable => _nativeTrayAvailable;
  bool get windowManagerAvailable => _windowManagerAvailable;
  bool get fileSystemAvailable => _fileSystemAvailable;
  bool get localOllamaAvailable => _localOllamaAvailable;
  bool get isInitialized => _isInitialized;
  List<String> get initializationErrors =>
      List.unmodifiable(_initializationErrors);
  Map<String, bool> get serviceStatus => Map.unmodifiable(_serviceStatus);

  /// Initialize platform detection and service availability
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint(' [PlatformService] Already initialized, skipping');
      return;
    }

    try {
      debugPrint(
        ' [PlatformService] Initializing platform service manager...',
      );

      await _detectPlatform();
      await _checkServiceAvailability();

      _isInitialized = true;
      debugPrint(' [PlatformService] Platform service manager initialized');
      debugPrint(' [PlatformService] Platform: $_platformName');
      debugPrint(
        ' [PlatformService] Available services: ${_getAvailableServices()}',
      );

      notifyListeners();
    } catch (e) {
      debugPrint(' [PlatformService] Failed to initialize: $e');
      _initializationErrors.add('Platform detection failed: $e');
      rethrow;
    }
  }

  /// Detect current platform
  Future<void> _detectPlatform() async {
    try {
      _isWeb = kIsWeb;

      if (_isWeb) {
        _platformName = 'web';
        _isDesktop = false;
        _isMobile = false;
        debugPrint(' [PlatformService] Detected web platform');
      } else {
        if (Platform.isWindows) {
          _platformName = 'windows';
          _isDesktop = true;
        } else if (Platform.isMacOS) {
          _platformName = 'macos';
          _isDesktop = true;
        } else if (Platform.isLinux) {
          _platformName = 'linux';
          _isDesktop = true;
        } else if (Platform.isAndroid) {
          _platformName = 'android';
          _isMobile = true;
        } else if (Platform.isIOS) {
          _platformName = 'ios';
          _isMobile = true;
        } else {
          _platformName = 'unknown';
        }

        debugPrint(' [PlatformService] Detected platform: $_platformName');
      }
    } catch (e) {
      debugPrint(' [PlatformService] Platform detection error: $e');
      _platformName = 'unknown';
      _initializationErrors.add('Platform detection error: $e');
    }
  }

  /// Check availability of platform-specific services
  Future<void> _checkServiceAvailability() async {
    // Native tray service
    _nativeTrayAvailable = await _checkNativeTrayAvailability();
    _serviceStatus['native_tray'] = _nativeTrayAvailable;

    // Window manager service
    _windowManagerAvailable = await _checkWindowManagerAvailability();
    _serviceStatus['window_manager'] = _windowManagerAvailable;

    // File system access
    _fileSystemAvailable = await _checkFileSystemAvailability();
    _serviceStatus['file_system'] = _fileSystemAvailable;

    // Local Ollama availability
    _localOllamaAvailable = await _checkLocalOllamaAvailability();
    _serviceStatus['local_ollama'] = _localOllamaAvailable;
  }

  /// Check if native tray service is available
  Future<bool> _checkNativeTrayAvailability() async {
    try {
      if (_isWeb) {
        debugPrint(
          ' [PlatformService] Native tray not available on web platform',
        );
        return false;
      }

      if (_isDesktop) {
        debugPrint(
          ' [PlatformService] Native tray available on desktop platform',
        );
        return true;
      }

      debugPrint(
        ' [PlatformService] Native tray not available on mobile platform',
      );
      return false;
    } catch (e) {
      debugPrint(
        ' [PlatformService] Error checking native tray availability: $e',
      );
      _initializationErrors.add('Native tray check failed: $e');
      return false;
    }
  }

  /// Check if window manager service is available
  Future<bool> _checkWindowManagerAvailability() async {
    try {
      if (_isWeb) {
        debugPrint(
          ' [PlatformService] Window manager not available on web platform',
        );
        return false;
      }

      if (_isDesktop) {
        debugPrint(
          ' [PlatformService] Window manager available on desktop platform',
        );
        return true;
      }

      debugPrint(
        ' [PlatformService] Window manager not available on mobile platform',
      );
      return false;
    } catch (e) {
      debugPrint(
        ' [PlatformService] Error checking window manager availability: $e',
      );
      _initializationErrors.add('Window manager check failed: $e');
      return false;
    }
  }

  /// Check if file system access is available
  Future<bool> _checkFileSystemAvailability() async {
    try {
      if (_isWeb) {
        debugPrint(
          ' [PlatformService] Limited file system access on web platform',
        );
        return false; // Limited access through browser APIs
      }

      debugPrint(' [PlatformService] Full file system access available');
      return true;
    } catch (e) {
      debugPrint(
        ' [PlatformService] Error checking file system availability: $e',
      );
      _initializationErrors.add('File system check failed: $e');
      return false;
    }
  }

  /// Check if local Ollama service is available
  Future<bool> _checkLocalOllamaAvailability() async {
    try {
      if (_isWeb) {
        debugPrint(
          ' [PlatformService] Local Ollama not available on web platform (CORS restrictions)',
        );
        return false;
      }

      if (_isDesktop) {
        debugPrint(
          ' [PlatformService] Local Ollama potentially available on desktop platform',
        );
        return true; // Actual availability depends on Ollama installation
      }

      debugPrint(
        ' [PlatformService] Local Ollama not typically available on mobile platform',
      );
      return false;
    } catch (e) {
      debugPrint(
        ' [PlatformService] Error checking local Ollama availability: $e',
      );
      _initializationErrors.add('Local Ollama check failed: $e');
      return false;
    }
  }

  /// Get list of available services
  List<String> _getAvailableServices() {
    final services = <String>[];

    if (_nativeTrayAvailable) services.add('native_tray');
    if (_windowManagerAvailable) services.add('window_manager');
    if (_fileSystemAvailable) services.add('file_system');
    if (_localOllamaAvailable) services.add('local_ollama');

    return services;
  }

  /// Initialize service with platform check
  Future<bool> initializeServiceSafely(
    String serviceName,
    Future<void> Function() initializer,
  ) async {
    try {
      debugPrint(
        ' [PlatformService] Attempting to initialize $serviceName...',
      );

      // Check if service is available on current platform
      switch (serviceName) {
        case 'native_tray':
          if (!_nativeTrayAvailable) {
            debugPrint(
              ' [PlatformService] Skipping $serviceName - not available on $_platformName',
            );
            return false;
          }
          break;
        case 'window_manager':
          if (!_windowManagerAvailable) {
            debugPrint(
              ' [PlatformService] Skipping $serviceName - not available on $_platformName',
            );
            return false;
          }
          break;
        case 'local_ollama':
          if (!_localOllamaAvailable) {
            debugPrint(
              ' [PlatformService] Skipping $serviceName - not available on $_platformName',
            );
            return false;
          }
          break;
      }

      // Attempt initialization
      await initializer();
      _serviceStatus[serviceName] = true;
      debugPrint(' [PlatformService] Successfully initialized $serviceName');
      return true;
    } catch (e) {
      debugPrint(' [PlatformService] Failed to initialize $serviceName: $e');
      _serviceStatus[serviceName] = false;
      _initializationErrors.add('$serviceName initialization failed: $e');
      return false;
    }
  }

  /// Get platform-specific feature availability
  Map<String, bool> get featureAvailability {
    return {
      'system_tray': _nativeTrayAvailable,
      'window_management': _windowManagerAvailable,
      'local_file_access': _fileSystemAvailable,
      'local_ollama': _localOllamaAvailable,
      'cloud_proxy': true, // Always available with internet
      'conversation_storage': true, // Always available (IndexedDB/SQLite)
      'authentication': true, // Always available
      'web_interface': true, // Always available
    };
  }

  /// Get platform-specific limitations
  List<String> get platformLimitations {
    final limitations = <String>[];

    if (_isWeb) {
      limitations.add('No system tray integration');
      limitations.add('No window management controls');
      limitations.add('Limited file system access');
      limitations.add('No local Ollama connection (CORS restrictions)');
      limitations.add('Cloud proxy required for LLM access');
    }

    if (_isMobile) {
      limitations.add('No system tray integration');
      limitations.add('Limited window management');
      limitations.add('No local Ollama support');
    }

    return limitations;
  }

  /// Get platform-specific recommendations
  List<String> get platformRecommendations {
    final recommendations = <String>[];

    if (_isWeb) {
      recommendations.add('Use desktop app for full feature access');
      recommendations.add('Enable cloud proxy for LLM connectivity');
      recommendations.add('Consider premium tier for enhanced features');
    }

    if (_isDesktop) {
      recommendations.add('Install Ollama locally for best performance');
      recommendations.add('Enable system tray for background operation');
    }

    return recommendations;
  }

  /// Check if a specific feature is supported
  bool isFeatureSupported(String feature) {
    return featureAvailability[feature] ?? false;
  }

  /// Get platform summary for debugging
  Map<String, dynamic> get platformSummary {
    return {
      'platform': _platformName,
      'is_web': _isWeb,
      'is_desktop': _isDesktop,
      'is_mobile': _isMobile,
      'available_services': _getAvailableServices(),
      'service_status': _serviceStatus,
      'initialization_errors': _initializationErrors,
      'feature_availability': featureAvailability,
      'limitations': platformLimitations,
      'recommendations': platformRecommendations,
    };
  }
}

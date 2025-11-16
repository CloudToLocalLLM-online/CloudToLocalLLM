import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Enhanced user tier service with container management and privacy controls
///
/// TIER-BASED ARCHITECTURE:
/// - Free Tier: Ephemeral containers, local storage only, web platform only
/// - Premium Tier: Persistent containers, optional cloud sync, all platforms
///
/// PRIVACY ENFORCEMENT:
/// - Free tier: No cloud data transmission except authentication
/// - Premium tier: Optional encrypted cloud sync with user control
class EnhancedUserTierService extends ChangeNotifier {
  final AuthService _authService;
  final Dio _dio = Dio();

  // User tier information
  String _currentTier = 'free';
  bool _isPremiumTier = false;
  DateTime? _tierExpiryDate;
  Map<String, dynamic> _tierFeatures = {};

  // Container management
  String? _containerStatus = 'none';
  String? _containerId;
  DateTime? _containerCreatedAt;
  bool _hasAlwaysOnContainer = false;

  // Connection management
  int _connectionPriority = 1; // 1=low, 5=high
  Duration _connectionTimeout = const Duration(seconds: 30);
  int _requestQueueLimit = 5;

  // Service status
  bool _isInitialized = false;
  String? _error;
  DateTime? _lastTierCheck;

  EnhancedUserTierService({required AuthService authService})
      : _authService = authService {
    _setupDio();
    _initializeTierFeatures();
  }

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  // Getters
  String get currentTier => _currentTier;
  bool get isPremiumTier => _isPremiumTier;
  DateTime? get tierExpiryDate => _tierExpiryDate;
  Map<String, dynamic> get tierFeatures => Map.unmodifiable(_tierFeatures);
  String? get containerStatus => _containerStatus;
  String? get containerId => _containerId;
  DateTime? get containerCreatedAt => _containerCreatedAt;
  bool get hasAlwaysOnContainer => _hasAlwaysOnContainer;
  int get connectionPriority => _connectionPriority;
  Duration get connectionTimeout => _connectionTimeout;
  int get requestQueueLimit => _requestQueueLimit;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  DateTime? get lastTierCheck => _lastTierCheck;

  // Compatibility getters for existing components
  bool get isFree => _currentTier == 'free';
  bool get isPremium => _currentTier == 'premium';
  bool get isEnterprise => _currentTier == 'enterprise';
  bool get isLoading => !_isInitialized;

  /// Initialize tier service and check user tier
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint(' [UserTier] Already initialized, skipping');
      return;
    }

    try {
      debugPrint(' [UserTier] Initializing enhanced user tier service...');

      if (_authService.isAuthenticated.value) {
        await checkUserTier();
      } else {
        _setFreeTierDefaults();
      }

      _isInitialized = true;
      debugPrint(' [UserTier] Enhanced user tier service initialized');
      debugPrint(' [UserTier] Current tier: $_currentTier');
      debugPrint(' [UserTier] Container status: $_containerStatus');

      notifyListeners();
    } catch (e) {
      debugPrint(' [UserTier] Failed to initialize: $e');
      _error = e.toString();
      _setFreeTierDefaults(); // Safe fallback
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Initialize tier-specific features
  void _initializeTierFeatures() {
    _tierFeatures = {
      'free': {
        'cloud_sync': false,
        'persistent_container': false,
        'priority_connections': false,
        'mobile_access': false,
        'connection_timeout': 30,
        'request_queue_limit': 5,
        'container_type': 'ephemeral',
        'storage_location': 'local_only',
        'platform_access': ['web'],
      },
      'premium': {
        'cloud_sync': true,
        'persistent_container': true,
        'priority_connections': true,
        'mobile_access': true,
        'connection_timeout': 60,
        'request_queue_limit': 20,
        'container_type': 'persistent',
        'storage_location': 'local_with_optional_cloud',
        'platform_access': ['web', 'desktop', 'mobile'],
      },
    };
  }

  /// Set free tier defaults
  void _setFreeTierDefaults() {
    _currentTier = 'free';
    _isPremiumTier = false;
    _tierExpiryDate = null;
    _containerStatus = 'ephemeral';
    _containerId = null;
    _containerCreatedAt = null;
    _hasAlwaysOnContainer = false;
    _connectionPriority = 1;
    _connectionTimeout = const Duration(seconds: 30);
    _requestQueueLimit = 5;
    _error = null;
  }

  /// Check user tier from backend
  Future<void> checkUserTier() async {
    if (!_authService.isAuthenticated.value) {
      _setFreeTierDefaults();
      notifyListeners();
      return;
    }

    try {
      debugPrint(' [UserTier] Checking user tier...');

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            ' [UserTier] No access token available, falling back to free tier');
        _setFreeTierDefaults();
        notifyListeners();
        return;
      }

      final response = await _dio.get(
        '/api/user/tier',
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _updateTierFromResponse(data);
        _lastTierCheck = DateTime.now();
        _error = null;

        debugPrint(' [UserTier] Tier check successful: $_currentTier');
      } else if (response.statusCode == 401) {
        debugPrint(' [UserTier] Authentication failed, setting free tier');
        _setFreeTierDefaults();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }

      notifyListeners();
    } catch (e) {
      debugPrint(' [UserTier] Error checking tier: $e');
      _error = e.toString();

      // Fallback to free tier on error
      if (_currentTier != 'free') {
        debugPrint(' [UserTier] Falling back to free tier due to error');
        _setFreeTierDefaults();
        notifyListeners();
      }
    }
  }

  /// Update tier information from API response
  Future<void> _updateTierFromResponse(Map<String, dynamic> data) async {
    _currentTier = data['tier'] ?? 'free';
    _isPremiumTier = _currentTier != 'free';

    if (data['expiry_date'] != null) {
      _tierExpiryDate = DateTime.parse(data['expiry_date']);
    }

    // Update container information
    final containerInfo = data['container'] as Map<String, dynamic>?;
    if (containerInfo != null) {
      _containerStatus = containerInfo['status'];
      _containerId = containerInfo['id'];
      _hasAlwaysOnContainer = containerInfo['always_on'] ?? false;

      if (containerInfo['created_at'] != null) {
        _containerCreatedAt = DateTime.parse(containerInfo['created_at']);
      }
    }

    // Update connection settings based on tier
    _updateConnectionSettings();
  }

  /// Update connection settings based on tier
  void _updateConnectionSettings() {
    final features = _tierFeatures[_currentTier] as Map<String, dynamic>?;
    if (features != null) {
      _connectionPriority = _isPremiumTier ? 5 : 1;
      _connectionTimeout = Duration(
        seconds: features['connection_timeout'] ?? 30,
      );
      _requestQueueLimit = features['request_queue_limit'] ?? 5;
    }
  }

  /// Request container allocation
  Future<bool> requestContainer() async {
    if (!_authService.isAuthenticated.value) {
      debugPrint(' [UserTier] Container request requires authentication');
      return false;
    }

    try {
      debugPrint(' [UserTier] Requesting container allocation...');

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            ' [UserTier] No access token available, cannot request container');
        return false;
      }

      final response = await _dio.post(
        '/api/container/allocate',
        data: {
          'tier': _currentTier,
          'container_type': _isPremiumTier ? 'persistent' : 'ephemeral',
        },
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        _containerStatus = data['status'];
        _containerId = data['container_id'];
        _hasAlwaysOnContainer = data['always_on'] ?? false;
        _containerCreatedAt = DateTime.now();

        debugPrint(' [UserTier] Container allocated: $_containerId');
        debugPrint(
          ' [UserTier] Container type: ${_isPremiumTier ? "persistent" : "ephemeral"}',
        );

        notifyListeners();
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      debugPrint(' [UserTier] Container allocation failed: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Release container
  Future<bool> releaseContainer() async {
    if (_containerId == null) {
      debugPrint(' [UserTier] No container to release');
      return true;
    }

    try {
      debugPrint(' [UserTier] Releasing container: $_containerId');

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            ' [UserTier] No access token available, cannot release container');
        return false;
      }

      final response = await _dio.post(
        '/api/container/release',
        data: {'container_id': _containerId},
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        _containerStatus = 'none';
        _containerId = null;
        _containerCreatedAt = null;
        _hasAlwaysOnContainer = false;

        debugPrint(' [UserTier] Container released successfully');
        notifyListeners();
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      debugPrint(' [UserTier] Container release failed: $e');
      _error = e.toString();
      return false;
    }
  }

  /// Check if feature is available for current tier
  bool isFeatureAvailable(String feature) {
    final features = _tierFeatures[_currentTier] as Map<String, dynamic>?;
    return features?[feature] ?? false;
  }

  /// Check if platform is accessible for current tier
  bool isPlatformAccessible(String platform) {
    final features = _tierFeatures[_currentTier] as Map<String, dynamic>?;
    final platformAccess = features?['platform_access'] as List<dynamic>?;
    return platformAccess?.contains(platform) ?? false;
  }

  /// Get tier-specific limitations
  List<String> get tierLimitations {
    if (_isPremiumTier) {
      return []; // No limitations for premium tier
    } else {
      return [
        'Web platform access only',
        'Ephemeral containers (no persistence)',
        'Standard connection priority',
        'Limited request queue (5 requests)',
        'Local storage only (no cloud sync)',
        'No mobile app access',
      ];
    }
  }

  /// Get tier-specific benefits
  List<String> get tierBenefits {
    if (_isPremiumTier) {
      return [
        'All platform access (web, desktop, mobile)',
        'Persistent always-on containers',
        'Priority connection handling',
        'Extended request queue (20 requests)',
        'Optional encrypted cloud sync',
        'Cross-device conversation sync',
        'Automated backup and restore',
      ];
    } else {
      return [
        'Web platform access',
        'Local conversation storage',
        'Basic LLM chat functionality',
        'Manual data export/import',
      ];
    }
  }

  /// Get container uptime
  Duration? get containerUptime {
    if (_containerCreatedAt == null) return null;
    return DateTime.now().difference(_containerCreatedAt!);
  }

  /// Get formatted container uptime
  String get formattedContainerUptime {
    final uptime = containerUptime;
    if (uptime == null) return 'N/A';

    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get tier status summary
  Map<String, dynamic> get tierStatusSummary {
    return {
      'tier': _currentTier,
      'is_premium': _isPremiumTier,
      'expiry_date': _tierExpiryDate?.toIso8601String(),
      'container_status': _containerStatus,
      'container_id': _containerId,
      'container_uptime': formattedContainerUptime,
      'has_always_on_container': _hasAlwaysOnContainer,
      'connection_priority': _connectionPriority,
      'connection_timeout': _connectionTimeout.inSeconds,
      'request_queue_limit': _requestQueueLimit,
      'last_check': _lastTierCheck?.toIso8601String(),
      'error': _error,
    };
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

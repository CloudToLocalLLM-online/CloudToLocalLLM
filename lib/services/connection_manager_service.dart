import 'dart:async';
import 'package:flutter/foundation.dart';

// Core connection services
import 'local_ollama_connection_service.dart';
import 'http_polling_tunnel_client.dart';
import 'streaming_service.dart';
import 'ollama_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';

// LLM provider management
import 'llm_provider_manager.dart';
import 'provider_discovery_service.dart';

// Models and error handling
import '../models/llm_communication_error.dart';

/// Connection types available in the system
enum ConnectionType {
  /// No connection available
  none,
  /// Local Ollama connection (desktop only)
  local,
  /// Cloud proxy via HTTP polling tunnel
  cloud,
  /// LLM provider connection (via provider manager)
  provider,
}

/// Provider health metrics for monitoring
class ProviderHealthMetrics {
  final String providerId;
  final bool isHealthy;
  final double successRate;
  final double responseTime;
  final int consecutiveFailures;
  final DateTime lastCheck;
  final Map<String, dynamic> additionalMetrics;

  const ProviderHealthMetrics({
    required this.providerId,
    required this.isHealthy,
    required this.successRate,
    required this.responseTime,
    required this.consecutiveFailures,
    required this.lastCheck,
    this.additionalMetrics = const {},
  });

  /// Create empty metrics for initialization
  factory ProviderHealthMetrics.empty(String providerId) {
    return ProviderHealthMetrics(
      providerId: providerId,
      isHealthy: false,
      successRate: 0.0,
      responseTime: 0.0,
      consecutiveFailures: 0,
      lastCheck: DateTime.now(),
    );
  }

  /// Create updated metrics
  ProviderHealthMetrics copyWith({
    bool? isHealthy,
    double? successRate,
    double? responseTime,
    int? consecutiveFailures,
    DateTime? lastCheck,
    Map<String, dynamic>? additionalMetrics,
  }) {
    return ProviderHealthMetrics(
      providerId: providerId,
      isHealthy: isHealthy ?? this.isHealthy,
      successRate: successRate ?? this.successRate,
      responseTime: responseTime ?? this.responseTime,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastCheck: lastCheck ?? this.lastCheck,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
    );
  }
}

/// Connection pool metrics for monitoring
class ConnectionPoolMetrics {
  final String poolId;
  final int connectionCount;
  final int activeConnections;
  final int idleConnections;
  final int activeRequests;
  final DateTime lastActivity;
  final double responseTime;
  final bool isHealthy;
  final Map<String, dynamic> additionalMetrics;

  const ConnectionPoolMetrics({
    required this.poolId,
    required this.connectionCount,
    required this.activeConnections,
    required this.idleConnections,
    required this.activeRequests,
    required this.lastActivity,
    required this.responseTime,
    required this.isHealthy,
    this.additionalMetrics = const {},
  });

  /// Create empty metrics for initialization
  factory ConnectionPoolMetrics.empty(String poolId) {
    return ConnectionPoolMetrics(
      poolId: poolId,
      connectionCount: 0,
      activeConnections: 0,
      idleConnections: 0,
      activeRequests: 0,
      lastActivity: DateTime.now(),
      responseTime: 0.0,
      isHealthy: false,
    );
  }

  /// Create updated metrics
  ConnectionPoolMetrics copyWith({
    int? connectionCount,
    int? activeConnections,
    int? idleConnections,
    int? activeRequests,
    DateTime? lastActivity,
    double? responseTime,
    bool? isHealthy,
    Map<String, dynamic>? additionalMetrics,
  }) {
    return ConnectionPoolMetrics(
      poolId: poolId,
      connectionCount: connectionCount ?? this.connectionCount,
      activeConnections: activeConnections ?? this.activeConnections,
      idleConnections: idleConnections ?? this.idleConnections,
      activeRequests: activeRequests ?? this.activeRequests,
      lastActivity: lastActivity ?? this.lastActivity,
      responseTime: responseTime ?? this.responseTime,
      isHealthy: isHealthy ?? this.isHealthy,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
    );
  }

  /// Get connection pool utilization percentage
  double get utilizationPercentage {
    if (connectionCount == 0) return 0.0;
    return (activeConnections / connectionCount) * 100.0;
  }

  /// Get pool status description
  String get statusDescription {
    if (activeConnections == 0) return 'idle';
    if (utilizationPercentage > 80) return 'high_load';
    if (utilizationPercentage > 50) return 'moderate_load';
    return 'low_load';
  }
}

/// Enhanced Connection Manager Service
///
/// Coordinates between local and cloud connections with integrated LLM provider management.
/// This service implements a sophisticated connection hierarchy with health monitoring,
/// intelligent failover, and performance-based prioritization.
///
/// ## Connection Hierarchy
/// The service implements a platform-aware connection hierarchy:
/// 
/// ### Desktop Platform:
/// 1. **High-Performance LLM Providers** (if not preferring local Ollama)
///    - Providers with >95% success rate and <2s response time
///    - Health-checked and performance-verified
/// 2. **Local Ollama Connection** (if preferred and healthy)
///    - Direct local connection with health verification
/// 3. **Cloud Proxy via HTTP Polling Tunnel**
///    - Tunnel connectivity health verified
/// 4. **Fallback Healthy Providers**
///    - Any available provider with basic health checks
/// 5. **Degraded Connections**
///    - Local Ollama or cloud proxy even if degraded
///
/// ### Web Platform:
/// 1. **Cloud Proxy via HTTP Polling Tunnel** (primary)
///    - Tunnel connectivity health verified
/// 2. **Provider Connections** (if available)
///    - Healthy providers as fallback
/// 3. **Degraded Cloud Proxy** (final fallback)
///
/// ## Key Features
/// - **Provider Health Monitoring**: Continuous health checks with metrics
/// - **Performance-Based Prioritization**: Intelligent provider selection
/// - **Connection Pool Management**: Automatic cleanup and monitoring
/// - **Tunnel Communication Patterns**: Optimized HTTP polling bridge
/// - **Error Handling & Recovery**: Comprehensive error classification and recovery
/// - **Platform-Aware Logic**: Different strategies for web vs desktop
///
/// ## Tunnel Communication Patterns
/// 
/// ### HTTP Polling Bridge Pattern
/// - **Polling Interval**: Adaptive based on activity and connection health
/// - **Request Batching**: Multiple requests processed in single poll cycle
/// - **Timeout Management**: Different timeouts for different operation types
/// - **Error Recovery**: Exponential backoff with circuit breaker pattern
/// - **Authentication Integration**: JWT token refresh and validation
///
/// ### Provider Communication Pattern
/// - **Discovery Phase**: Auto-detect available providers on startup
/// - **Health Monitoring**: Periodic connectivity and performance checks
/// - **Load Balancing**: Route requests to best-performing providers
/// - **Failover Logic**: Automatic switching on provider failures
/// - **Connection Pooling**: Efficient connection reuse and cleanup
///
/// ## Usage Example
/// ```dart
/// final connectionManager = ConnectionManagerService(
///   localOllama: localOllamaService,
///   httpPollingClient: httpPollingClient,
///   authService: authService,
///   providerManager: providerManager,
/// );
/// 
/// await connectionManager.initialize();
/// 
/// // Get best connection for request
/// final connectionType = connectionManager.getBestConnectionType();
/// 
/// // Send chat message through best connection
/// final response = await connectionManager.sendChatMessage(
///   model: 'llama2',
///   message: 'Hello, world!',
/// );
/// ```
class ConnectionManagerService extends ChangeNotifier {
  final LocalOllamaConnectionService _localOllama;
  final HttpPollingTunnelClient _httpPollingClient;
  final AuthService _authService;
  final LLMProviderManager? _providerManager;

  // Connection preferences and state
  bool _preferLocalOllama = true;
  String? _selectedModel;
  String? _preferredProviderId;
  
  // Connection state tracking
  ConnectionType _lastUsedConnectionType = ConnectionType.none;
  DateTime? _lastConnectionChange;
  int _connectionFailureCount = 0;
  static const int _maxConnectionFailures = 3;

  // Cloud streaming service (lazy initialized)
  CloudStreamingService? _cloudStreamingService;

  // Provider health monitoring
  Timer? _providerHealthTimer;
  final Map<String, ProviderHealthMetrics> _providerHealthMetrics = {};
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  // Connection pool monitoring and metrics
  Timer? _connectionPoolMonitorTimer;
  final Map<String, ConnectionPoolMetrics> _connectionPoolMetrics = {};
  final Map<String, List<DateTime>> _connectionHistory = {};
  static const Duration _poolMonitorInterval = Duration(seconds: 15);
  static const Duration _connectionHistoryRetention = Duration(hours: 1);
  static const int _maxConnectionHistoryEntries = 100;

  ConnectionManagerService({
    required LocalOllamaConnectionService localOllama,
    required HttpPollingTunnelClient httpPollingClient,
    required AuthService authService,
    LLMProviderManager? providerManager,
  }) : _localOllama = localOllama,
       _httpPollingClient = httpPollingClient,
       _authService = authService,
       _providerManager = providerManager {
    // Listen to connection changes
    _localOllama.addListener(_onConnectionChanged);
    _httpPollingClient.addListener(_onConnectionChanged);

    // Listen to auth changes to start/stop HTTP polling
    _authService.addListener(_onAuthChanged);

    if (kIsWeb) {
      debugPrint(
        '🔗 [ConnectionManager] Web platform detected - will use cloud proxy only',
      );
      debugPrint(
        '🔗 [ConnectionManager] Local Ollama connections disabled to prevent CORS errors',
      );
    } else {
      debugPrint(
        '🔗 [ConnectionManager] Desktop platform detected - full connection hierarchy available',
      );
    }

    debugPrint('🔗 [ConnectionManager] Service initialized');

    // Initialize provider health monitoring if provider manager is available
    if (_providerManager != null) {
      _startProviderHealthMonitoring();
      debugPrint('🔗 [ConnectionManager] Provider health monitoring enabled');
    }

    // Initialize connection pool monitoring
    _startConnectionPoolMonitoring();
    debugPrint('🔗 [ConnectionManager] Connection pool monitoring enabled');
  }

  // Getters
  bool get hasLocalConnection => _localOllama.isConnected;
  bool get hasCloudConnection => _httpPollingClient.isConnected;
  bool get hasProviderConnection => _providerManager?.availableProviders.isNotEmpty ?? false;
  bool get hasAnyConnection => hasLocalConnection || hasCloudConnection || hasProviderConnection;
  String? get selectedModel => _selectedModel;
  String? get preferredProviderId => _preferredProviderId;
  List<String> get availableModels => _getAvailableModels();
  Map<String, ProviderHealthMetrics> get providerHealthMetrics => 
      Map.unmodifiable(_providerHealthMetrics);
  Map<String, ConnectionPoolMetrics> get connectionPoolMetrics =>
      Map.unmodifiable(_connectionPoolMetrics);

  /// Get the best available connection type with enhanced provider intelligence
  /// 
  /// This method implements a sophisticated connection selection algorithm that considers:
  /// - Platform constraints (web vs desktop)
  /// - Provider health and performance metrics
  /// - User preferences and connection history
  /// - Failure counts and circuit breaker patterns
  /// 
  /// ## Connection Selection Algorithm:
  /// 
  /// ### Desktop Platform:
  /// 1. **High-Performance LLM Providers** (if not preferring local Ollama)
  ///    - Success rate ≥ 95%, response time < 2s, no consecutive failures
  /// 2. **Preferred Local Ollama** (if preferred and healthy)
  ///    - Recent successful check within 5 minutes
  /// 3. **Cloud Proxy** (with tunnel health verification)
  ///    - HTTP polling healthy, auth valid, recent activity
  /// 4. **Fallback Healthy Providers** (any available provider)
  /// 5. **Degraded Connections** (local Ollama or cloud proxy)
  /// 
  /// ### Web Platform:
  /// 1. **Cloud Proxy** (primary, with tunnel health verification)
  /// 2. **Provider Connections** (if available as fallback)
  /// 3. **Degraded Cloud Proxy** (final fallback)
  /// 
  /// @returns ConnectionType The best available connection type
  ConnectionType getBestConnectionType() {
    if (kIsWeb) {
      // Web platform: Enhanced prioritization with tunnel connectivity verification
      debugPrint('🔗 [ConnectionManager] Web platform detected');
      
      // Verify tunnel connectivity quality before using cloud connection
      if (hasCloudConnection && _isTunnelConnectivityHealthy()) {
        debugPrint('🔗 [ConnectionManager] Using cloud proxy connection (web preferred, tunnel healthy)');
        return ConnectionType.cloud;
      } else if (hasProviderConnection) {
        final healthyProvider = _getBestHealthyProvider();
        if (healthyProvider != null) {
          debugPrint('🔗 [ConnectionManager] Using healthy provider: ${healthyProvider.info.id} (cloud tunnel degraded)');
          return ConnectionType.provider;
        }
      } else if (hasCloudConnection) {
        // Use cloud even if tunnel is degraded, as it's the only option on web
        debugPrint('🔗 [ConnectionManager] Using cloud proxy connection (degraded tunnel, no alternatives)');
        return ConnectionType.cloud;
      }
      
      debugPrint('🔗 [ConnectionManager] No connections available on web platform');
      return ConnectionType.none;
    }

    // Desktop platform: Enhanced hierarchy with intelligent provider prioritization
    
    // 1. Check for high-performance providers first (if not preferring local Ollama)
    if (!_preferLocalOllama && hasProviderConnection) {
      final bestProvider = _getBestHealthyProvider();
      if (bestProvider != null && _isProviderHighPerformance(bestProvider)) {
        debugPrint('🔗 [ConnectionManager] Using high-performance provider: ${bestProvider.info.id}');
        return ConnectionType.provider;
      }
    }
    
    // 2. Preferred local Ollama connection (with health verification)
    if (_preferLocalOllama && hasLocalConnection && _isLocalOllamaHealthy()) {
      debugPrint('🔗 [ConnectionManager] Using preferred local Ollama connection (healthy)');
      return ConnectionType.local;
    }
    
    // 3. Cloud proxy connection (with tunnel health verification)
    if (hasCloudConnection && _isTunnelConnectivityHealthy()) {
      debugPrint('🔗 [ConnectionManager] Using cloud proxy connection (tunnel healthy)');
      return ConnectionType.cloud;
    }
    
    // 4. Fallback to any healthy provider (even if not high-performance)
    if (hasProviderConnection) {
      final healthyProvider = _getBestHealthyProvider();
      if (healthyProvider != null) {
        debugPrint('🔗 [ConnectionManager] Using fallback healthy provider: ${healthyProvider.info.id}');
        return ConnectionType.provider;
      }
    }
    
    // 5. Fallback to local Ollama (even if not preferred or degraded)
    if (hasLocalConnection) {
      debugPrint('🔗 [ConnectionManager] Using fallback local Ollama connection');
      return ConnectionType.local;
    }
    
    // 6. Final fallback to cloud proxy (even if tunnel is degraded)
    if (hasCloudConnection) {
      debugPrint('🔗 [ConnectionManager] Using fallback cloud proxy connection (degraded tunnel)');
      return ConnectionType.cloud;
    }

    debugPrint('🔗 [ConnectionManager] No connections available');
    
    // Track connection type change
    _trackConnectionTypeChange(ConnectionType.none);
    
    return ConnectionType.none;
  }

  /// Track connection type changes for monitoring
  void _trackConnectionTypeChange(ConnectionType newType) {
    if (_lastUsedConnectionType != newType) {
      debugPrint('🔗 [ConnectionManager] Connection type changed: ${_lastUsedConnectionType.name} → ${newType.name}');
      _lastUsedConnectionType = newType;
      _lastConnectionChange = DateTime.now();
      
      // Reset failure count on successful connection change
      if (newType != ConnectionType.none) {
        _connectionFailureCount = 0;
      }
    }
  }







  /// Get connection prioritization details for debugging
  Map<String, dynamic> _getConnectionPrioritization() {
    return {
      'platform': kIsWeb ? 'web' : 'desktop',
      'prefer_local_ollama': _preferLocalOllama,
      'preferred_provider_id': _preferredProviderId,
      'last_used_connection': _lastUsedConnectionType.name,
      'last_connection_change': _lastConnectionChange?.toIso8601String(),
      'connection_failure_count': _connectionFailureCount,
      'max_connection_failures': _maxConnectionFailures,
      'connection_selection_criteria': {
        'high_performance_threshold': {
          'success_rate': 0.95,
          'response_time_ms': 2000,
          'consecutive_failures': 0,
        },
        'health_check_intervals': {
          'provider_health': '${_healthCheckInterval.inSeconds}s',
          'pool_monitoring': '${_poolMonitorInterval.inSeconds}s',
        },
      },
    };
  }

  /// Check if tunnel connectivity is healthy
  bool _isTunnelConnectivityHealthy() {
    if (!hasCloudConnection) return false;
    
    // Check HTTP polling client health
    final pollingHealthy = _httpPollingClient.isConnected && 
                          _httpPollingClient.errorsCount < 5 &&
                          (_httpPollingClient.lastSeen?.isAfter(
                              DateTime.now().subtract(const Duration(minutes: 2))) ?? false);
    
    // Check authentication health
    final authHealthy = _authService.isAuthenticated.value && 
                       _authService.currentUser != null;
    
    return pollingHealthy && authHealthy;
  }

  /// Check if local Ollama is healthy
  bool _isLocalOllamaHealthy() {
    if (!hasLocalConnection) return false;
    
    // Check if local Ollama has recent successful communication
    final recentCheck = _localOllama.lastCheck?.isAfter(
        DateTime.now().subtract(const Duration(minutes: 5))) ?? false;
    
    return _localOllama.isConnected && 
           _localOllama.error == null && 
           recentCheck;
  }

  /// Check if provider is high-performance based on metrics
  bool _isProviderHighPerformance(RegisteredProvider provider) {
    final metrics = _providerHealthMetrics[provider.info.id];
    if (metrics == null) return false;
    
    // High performance criteria:
    // - Success rate >= 95%
    // - Response time < 2 seconds
    // - No consecutive failures
    // - Recent successful check
    return metrics.isHealthy &&
           metrics.successRate >= 0.95 &&
           metrics.responseTime < 2000 &&
           metrics.consecutiveFailures == 0 &&
           metrics.lastCheck.isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
  }

  /// Get streaming service for the best available connection
  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();

    switch (connectionType) {
      case ConnectionType.local:
        final streamingService = _localOllama.streamingService;
        if (streamingService != null && streamingService.connection.isActive) {
          debugPrint('🔗 [ConnectionManager] Using local Ollama streaming');
          return streamingService;
        }
        break;

      case ConnectionType.cloud:
        // Initialize cloud streaming service if needed
        _cloudStreamingService ??= CloudStreamingService(
          authService: _authService,
        );

        if (_cloudStreamingService!.connection.isActive) {
          debugPrint('🔗 [ConnectionManager] Using cloud streaming');
          return _cloudStreamingService;
        } else {
          // Try to establish connection
          _cloudStreamingService!.establishConnection().catchError((e) {
            debugPrint(
              '🔗 [ConnectionManager] Cloud streaming connection failed: $e',
            );
          });
          return _cloudStreamingService;
        }

      case ConnectionType.provider:
        // For provider connections, we'll need to implement streaming through the provider manager
        debugPrint('🔗 [ConnectionManager] Provider streaming not yet implemented');
        break;

      case ConnectionType.none:
        debugPrint('🔗 [ConnectionManager] No streaming service available');
        break;
    }

    return null;
  }

  /// Get chat service for the best available connection
  Future<String?> sendChatMessage({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final connectionType = getBestConnectionType();

    switch (connectionType) {
      case ConnectionType.local:
        debugPrint('🔗 [ConnectionManager] Using local Ollama for chat');
        return await _localOllama.chat(
          model: model,
          message: message,
          history: history,
        );

      case ConnectionType.cloud:
        debugPrint('🔗 [ConnectionManager] Using cloud proxy for chat');
        // Create OllamaService configured for cloud proxy
        final ollamaService = OllamaService();
        return await ollamaService.chat(
          model: model,
          message: message,
          history: history,
        );

      case ConnectionType.provider:
        debugPrint('🔗 [ConnectionManager] Using provider for chat');
        final bestProvider = _getBestHealthyProvider();
        if (bestProvider?.langchainWrapper != null && _providerManager != null) {
          // Use provider's LangChain wrapper for chat
          try {
            // For now, we'll use a simple completion method
            // This will be enhanced when we integrate the full LangChain service
            debugPrint('🔗 [ConnectionManager] Provider chat integration pending full LangChain service');
            throw LLMCommunicationError.fromException(
              Exception('Provider chat integration not yet complete'),
              type: LLMCommunicationErrorType.systemError,
              providerId: bestProvider?.info.id,
            );
          } catch (error) {
            debugPrint('🔗 [ConnectionManager] Provider chat failed: $error');
            throw LLMCommunicationError.fromException(
              error is Exception ? error : Exception(error.toString()),
              type: LLMCommunicationErrorType.providerUnavailable,
              providerId: bestProvider?.info.id,
            );
          }
        } else {
          throw LLMCommunicationError.providerNotFound();
        }

      case ConnectionType.none:
        throw LLMCommunicationError.providerNotFound();
    }
  }

  /// Initialize all connections
  Future<void> initialize() async {
    debugPrint('🔗 [ConnectionManager] Initializing connections...');

    // Initialize local Ollama (independent of tunnel)
    try {
      await _localOllama.initialize();
    } catch (e) {
      debugPrint(
        '🔗 [ConnectionManager] Local Ollama initialization failed: $e',
      );
      // Don't fail overall initialization if local Ollama fails
    }

    // Skip WebSocket tunnel initialization (removed due to protocol issues)
    debugPrint(
      '🔗 [ConnectionManager] Skipping WebSocket tunnel (using HTTP polling only)',
    );

    // Initialize HTTP polling client as primary cloud connection method
    if (_authService.isAuthenticated.value &&
        _authService.currentUser != null) {
      try {
        debugPrint('🔗 [ConnectionManager] Starting HTTP polling client...');
        await _httpPollingClient.connect();
        debugPrint('🔗 [ConnectionManager] ✅ HTTP polling client connected');
      } catch (e) {
        debugPrint('🔗 [ConnectionManager] ❌ HTTP polling client failed: $e');
        // Don't fail overall initialization if polling fails
      }
    } else {
      debugPrint(
        '🔗 [ConnectionManager] HTTP polling client ready (will connect after auth)',
      );
    }

    // Auto-select first available model
    _autoSelectModel();

    debugPrint('🔗 [ConnectionManager] Initialization complete');
    notifyListeners();
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;
    debugPrint('🔗 [ConnectionManager] Selected model: $model');
    notifyListeners();
  }

  /// Set connection preference
  void setPreferLocalOllama(bool prefer) {
    _preferLocalOllama = prefer;
    debugPrint('🔗 [ConnectionManager] Prefer local Ollama: $prefer');
    notifyListeners();
  }

  /// Force reconnection of all services
  Future<void> reconnectAll() async {
    debugPrint('🔗 [ConnectionManager] Reconnecting all services...');

    // Reconnect local Ollama
    try {
      await _localOllama.reconnect();
    } catch (e) {
      debugPrint('🔗 [ConnectionManager] Local Ollama reconnect failed: $e');
    }

    // Reconnect HTTP polling client
    try {
      await _httpPollingClient.disconnect();
      await _httpPollingClient.connect();
    } catch (e) {
      debugPrint(
        '🔗 [ConnectionManager] HTTP polling client reconnect failed: $e',
      );
    }

    notifyListeners();
  }

  /// Get enhanced connection status summary with provider information
  Map<String, dynamic> getConnectionStatus() {
    final bestConnectionType = getBestConnectionType();
    final bestProvider = _getBestHealthyProvider();
    
    return {
      'local': {
        'connected': hasLocalConnection,
        'version': _localOllama.version,
        'models': _localOllama.models,
        'error': _localOllama.error,
        'lastCheck': _localOllama.lastCheck?.toIso8601String(),
      },
      'cloud': {
        'connected': hasCloudConnection,
        'error': _httpPollingClient.lastError,
        'status': 'http-polling',
        'tunnel_connectivity': _getTunnelConnectivityStatus(),
      },
      'providers': {
        'available': _providerManager?.availableProviders.length ?? 0,
        'healthy': _providerHealthMetrics.values.where((m) => m.isHealthy).length,
        'best_provider': bestProvider != null ? {
          'id': bestProvider.info.id,
          'name': bestProvider.info.name,
          'type': bestProvider.info.type.toString(),
          'health_metrics': _providerHealthMetrics[bestProvider.info.id] != null ? {
            'healthy': _providerHealthMetrics[bestProvider.info.id]?.isHealthy,
            'response_time': _providerHealthMetrics[bestProvider.info.id]?.responseTime,
            'success_rate': _providerHealthMetrics[bestProvider.info.id]?.successRate,
            'consecutive_failures': _providerHealthMetrics[bestProvider.info.id]?.consecutiveFailures,
          } : null,
        } : null,
        'preferred_provider': _preferredProviderId,
        'health_monitoring': _providerHealthTimer != null,
        'provider_performance_ranking': _getProviderPerformanceRanking(),
      },
      'connection_pools': {
        'total_pools': _connectionPoolMetrics.length,
        'active_pools': _connectionPoolMetrics.values.where((m) => m.activeConnections > 0).length,
        'healthy_pools': _connectionPoolMetrics.values.where((m) => m.isHealthy).length,
        'pool_monitoring': _connectionPoolMonitorTimer != null,
        'pool_details': _getConnectionPoolSummary(),
      },
      'active': bestConnectionType.name,
      'selectedModel': _selectedModel,
      'connection_hierarchy': _getConnectionHierarchy(),
      'connection_prioritization': _getConnectionPrioritization(),
    };
  }

  /// Get connection hierarchy for debugging
  List<Map<String, dynamic>> _getConnectionHierarchy() {
    final hierarchy = <Map<String, dynamic>>[];
    
    if (!kIsWeb) {
      // Desktop hierarchy
      if (hasProviderConnection) {
        hierarchy.add({
          'type': 'provider',
          'available': true,
          'priority': _preferLocalOllama ? 2 : 1,
          'description': 'LLM Providers (health-based)',
        });
      }
      
      if (hasLocalConnection) {
        hierarchy.add({
          'type': 'local',
          'available': true,
          'priority': _preferLocalOllama ? 1 : 3,
          'description': 'Local Ollama',
        });
      }
    }
    
    if (hasCloudConnection) {
      hierarchy.add({
        'type': 'cloud',
        'available': true,
        'priority': kIsWeb ? 1 : 2,
        'description': 'Cloud Proxy (HTTP Polling)',
      });
    }
    
    return hierarchy..sort((a, b) => a['priority'].compareTo(b['priority']));
  }

  /// Get all available models from all connections
  List<String> _getAvailableModels() {
    final models = <String>[];

    // Add local models
    if (hasLocalConnection) {
      models.addAll(_localOllama.models);
    }

    // Add cloud models (if available)
    if (hasCloudConnection) {
      // HTTP polling client doesn't provide model list directly
      // Models are fetched through the cloud service when needed
      debugPrint(
        '🔗 [ConnectionManager] Cloud connection available for model queries',
      );
    }

    // Remove duplicates and sort
    return models.toSet().toList()..sort();
  }

  /// Auto-select the first available model
  void _autoSelectModel() {
    if (_selectedModel != null) return;

    final models = availableModels;
    if (models.isNotEmpty) {
      setSelectedModel(models.first);
    }
  }

  /// Handle connection changes
  void _onConnectionChanged() {
    // Auto-select model if none selected
    _autoSelectModel();

    // Notify listeners of connection changes
    notifyListeners();

    // Log connection status
    final status = getConnectionStatus();
    debugPrint('🔗 [ConnectionManager] Connection status: $status');
  }

  /// Handle authentication state changes
  void _onAuthChanged() {
    debugPrint('🔗 [ConnectionManager] Auth state changed');

    if (_authService.isAuthenticated.value &&
        _authService.currentUser != null) {
      // User logged in - start HTTP polling with a small delay to ensure token is available
      debugPrint(
        '🔗 [ConnectionManager] User authenticated - starting HTTP polling',
      );

      // Add a small delay to ensure the access token is fully available
      debugPrint('🔗 [ConnectionManager] Scheduling HTTP polling start with 100ms delay...');
      Future.delayed(const Duration(milliseconds: 100), () {
        debugPrint('🔗 [ConnectionManager] Delay complete, starting HTTP polling...');
        startHttpPolling().catchError((e) {
          debugPrint(
            '🔗 [ConnectionManager] Failed to start HTTP polling after auth: $e',
          );
          return false;
        });
      });
    } else {
      // User logged out - stop HTTP polling
      debugPrint(
        '🔗 [ConnectionManager] User logged out - stopping HTTP polling',
      );
      stopHttpPolling().catchError((e) {
        debugPrint(
          '🔗 [ConnectionManager] Failed to stop HTTP polling after logout: $e',
        );
      });
    }

    notifyListeners();
  }

  /// Start HTTP polling connection (primary cloud method)
  Future<bool> startHttpPolling() async {
    if (_authService.currentUser == null) {
      debugPrint(
        '🌉 [ConnectionManager] Cannot start HTTP polling - not authenticated',
      );
      return false;
    }

    if (_httpPollingClient.isConnected) {
      debugPrint('🌉 [ConnectionManager] HTTP polling already connected');
      return true;
    }

    try {
      debugPrint('🌉 [ConnectionManager] Starting HTTP polling connection...');
      await _httpPollingClient.connect();

      if (_httpPollingClient.isConnected) {
        debugPrint(
          '🌉 [ConnectionManager] ✅ HTTP polling connected successfully',
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('🌉 [ConnectionManager] ❌ HTTP polling connection failed: $e');
    }

    return false;
  }

  /// Stop HTTP polling connection
  Future<void> stopHttpPolling() async {
    if (_httpPollingClient.isConnected) {
      debugPrint('🌉 [ConnectionManager] Stopping HTTP polling connection...');
      await _httpPollingClient.disconnect();
      notifyListeners();
    }
  }

  /// Check if HTTP polling is available and connected
  bool get isHttpPollingConnected => _httpPollingClient.isConnected;

  /// Get HTTP polling client statistics
  Map<String, dynamic> get httpPollingStats => {
    'connected': _httpPollingClient.isConnected,
    'bridgeId': _httpPollingClient.bridgeId,
    'requestsProcessed': _httpPollingClient.requestsProcessed,
    'errorsCount': _httpPollingClient.errorsCount,
    'lastSeen': _httpPollingClient.lastSeen?.toIso8601String(),
    'connectedAt': _httpPollingClient.connectedAt?.toIso8601String(),
  };

  /// Start provider health monitoring
  void _startProviderHealthMonitoring() {
    _providerHealthTimer?.cancel();
    _providerHealthTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performProviderHealthChecks();
    });
    
    // Perform initial health check
    _performProviderHealthChecks();
  }

  /// Stop provider health monitoring
  void _stopProviderHealthMonitoring() {
    _providerHealthTimer?.cancel();
    _providerHealthTimer = null;
  }

  /// Start connection pool monitoring and automatic cleanup
  void _startConnectionPoolMonitoring() {
    _connectionPoolMonitorTimer?.cancel();
    _connectionPoolMonitorTimer = Timer.periodic(_poolMonitorInterval, (_) {
      _performConnectionPoolMonitoring();
    });
    
    // Perform initial monitoring
    _performConnectionPoolMonitoring();
  }

  /// Stop connection pool monitoring
  void _stopConnectionPoolMonitoring() {
    _connectionPoolMonitorTimer?.cancel();
    _connectionPoolMonitorTimer = null;
  }

  /// Perform connection pool monitoring and automatic cleanup
  Future<void> _performConnectionPoolMonitoring() async {
    final now = DateTime.now();
    
    // Monitor local Ollama connection pool
    await _monitorLocalOllamaPool(now);
    
    // Monitor HTTP polling tunnel connection pool
    await _monitorHttpPollingPool(now);
    
    // Monitor provider-specific connection pools
    await _monitorProviderConnectionPools(now);
    
    // Perform automatic cleanup of stale connections and metrics
    _performAutomaticCleanup(now);
    
    // Update connection history
    _updateConnectionHistory(now);
    
    debugPrint('🔗 [ConnectionManager] Connection pool monitoring completed');
  }

  /// Monitor local Ollama connection pool
  Future<void> _monitorLocalOllamaPool(DateTime now) async {
    if (kIsWeb) return; // Skip on web platform
    
    final poolId = 'local_ollama';
    final isConnected = hasLocalConnection;
    final connectionCount = isConnected ? 1 : 0;
    final activeRequests = 0; // TODO: Get from local Ollama service if available
    
    final currentMetrics = _connectionPoolMetrics[poolId] ?? 
        ConnectionPoolMetrics.empty(poolId);
    
    final responseTime = _localOllama.lastCheck != null 
        ? now.difference(_localOllama.lastCheck!).inMilliseconds.toDouble()
        : 0.0;
    
    _connectionPoolMetrics[poolId] = currentMetrics.copyWith(
      connectionCount: connectionCount,
      activeConnections: connectionCount,
      idleConnections: 0,
      activeRequests: activeRequests,
      lastActivity: isConnected ? now : currentMetrics.lastActivity,
      responseTime: responseTime,
      additionalMetrics: {
        'provider_type': 'local_ollama',
        'version': _localOllama.version,
        'models_count': _localOllama.models.length,
        'error_status': _localOllama.error,
        'healthy': _isLocalOllamaHealthy(),
      },
    );
  }

  /// Monitor HTTP polling tunnel connection pool
  Future<void> _monitorHttpPollingPool(DateTime now) async {
    final poolId = 'http_polling_tunnel';
    final isConnected = hasCloudConnection;
    final connectionCount = isConnected ? 1 : 0;
    
    final currentMetrics = _connectionPoolMetrics[poolId] ?? 
        ConnectionPoolMetrics.empty(poolId);
    
    final responseTime = _httpPollingClient.lastSeen != null 
        ? now.difference(_httpPollingClient.lastSeen!).inMilliseconds.toDouble()
        : 0.0;
    
    _connectionPoolMetrics[poolId] = currentMetrics.copyWith(
      connectionCount: connectionCount,
      activeConnections: connectionCount,
      idleConnections: 0,
      activeRequests: 0, // HTTP polling doesn't track active requests directly
      lastActivity: isConnected ? now : currentMetrics.lastActivity,
      responseTime: responseTime,
      additionalMetrics: {
        'provider_type': 'http_polling_tunnel',
        'bridge_id': _httpPollingClient.bridgeId,
        'requests_processed': _httpPollingClient.requestsProcessed,
        'errors_count': _httpPollingClient.errorsCount,
        'connected_at': _httpPollingClient.connectedAt?.toIso8601String(),
        'healthy': _isTunnelConnectivityHealthy(),
        'auth_status': _authService.isAuthenticated.value,
      },
    );
  }

  /// Monitor provider-specific connection pools
  Future<void> _monitorProviderConnectionPools(DateTime now) async {
    if (_providerManager == null) return;
    
    for (final provider in _providerManager.registeredProviders) {
      final poolId = 'provider_${provider.info.id}';
      final isAvailable = provider.isAvailable;
      final connectionCount = isAvailable ? 1 : 0;
      
      final currentMetrics = _connectionPoolMetrics[poolId] ?? 
          ConnectionPoolMetrics.empty(poolId);
      
      final healthMetrics = _providerHealthMetrics[provider.info.id];
      final responseTime = healthMetrics?.responseTime ?? 0.0;
      
      _connectionPoolMetrics[poolId] = currentMetrics.copyWith(
        connectionCount: connectionCount,
        activeConnections: connectionCount,
        idleConnections: 0,
        activeRequests: 0, // TODO: Get from provider if available
        lastActivity: isAvailable ? now : currentMetrics.lastActivity,
        responseTime: responseTime,
        additionalMetrics: {
          'provider_type': provider.info.type.toString(),
          'provider_name': provider.info.name,
          'base_url': provider.info.baseUrl,
          'port': provider.info.port,
          'enabled': provider.isEnabled,
          'health_status': provider.healthStatus.toString(),
          'langchain_available': provider.langchainWrapper != null,
          'models_count': provider.info.availableModels.length,
          'capabilities': provider.info.capabilities,
        },
      );
    }
  }

  /// Perform automatic cleanup of stale connections and metrics
  void _performAutomaticCleanup(DateTime now) {
    final staleThreshold = now.subtract(const Duration(minutes: 10));
    final metricsToRemove = <String>[];
    
    // Identify stale connection pool metrics
    for (final entry in _connectionPoolMetrics.entries) {
      final metrics = entry.value;
      
      // Mark for removal if no activity for 10 minutes and no active connections
      if (metrics.lastActivity.isBefore(staleThreshold) && 
          metrics.activeConnections == 0) {
        metricsToRemove.add(entry.key);
      }
    }
    
    // Remove stale metrics
    for (final poolId in metricsToRemove) {
      _connectionPoolMetrics.remove(poolId);
      debugPrint('🔗 [ConnectionManager] Cleaned up stale connection pool: $poolId');
    }
    
    // Clean up connection history
    _cleanupConnectionHistory(now);
    
    // Clean up provider health metrics for removed providers
    _cleanupProviderHealthMetrics();
  }

  /// Update connection history for trend analysis
  void _updateConnectionHistory(DateTime now) {
    // Add current connection count to history
    _connectionHistory.putIfAbsent('total_connections', () => <DateTime>[])
        .add(now);
    
    // Add provider-specific connection history
    for (final entry in _connectionPoolMetrics.entries) {
      final poolId = entry.key;
      final metrics = entry.value;
      
      if (metrics.activeConnections > 0) {
        _connectionHistory.putIfAbsent(poolId, () => <DateTime>[])
            .add(now);
      }
    }
  }

  /// Clean up old connection history entries
  void _cleanupConnectionHistory(DateTime now) {
    final cutoffTime = now.subtract(_connectionHistoryRetention);
    
    for (final entry in _connectionHistory.entries) {
      final history = entry.value;
      
      // Remove entries older than retention period
      history.removeWhere((timestamp) => timestamp.isBefore(cutoffTime));
      
      // Limit total entries to prevent memory growth
      if (history.length > _maxConnectionHistoryEntries) {
        final excessCount = history.length - _maxConnectionHistoryEntries;
        history.removeRange(0, excessCount);
      }
    }
    
    // Remove empty history entries
    _connectionHistory.removeWhere((key, history) => history.isEmpty);
  }

  /// Clean up provider health metrics for providers that no longer exist
  void _cleanupProviderHealthMetrics() {
    if (_providerManager == null) return;
    
    final currentProviderIds = _providerManager.registeredProviders
        .map((p) => p.info.id)
        .toSet();
    
    final metricsToRemove = _providerHealthMetrics.keys
        .where((id) => !currentProviderIds.contains(id))
        .toList();
    
    for (final providerId in metricsToRemove) {
      _providerHealthMetrics.remove(providerId);
      debugPrint('🔗 [ConnectionManager] Cleaned up metrics for removed provider: $providerId');
    }
  }

  /// Perform health checks on all providers with enhanced monitoring
  Future<void> _performProviderHealthChecks() async {
    if (_providerManager == null) return;

    final providers = _providerManager.registeredProviders;
    final healthCheckTasks = <Future<void>>[];
    
    // Perform health checks concurrently for better performance
    for (final provider in providers) {
      if (provider.isEnabled) {
        healthCheckTasks.add(_checkProviderHealth(provider));
      }
    }
    
    // Wait for all health checks to complete
    await Future.wait(healthCheckTasks, eagerError: false);
    
    // Update connection prioritization based on new health data
    _updateConnectionPrioritization();
    
    // Notify listeners of health changes
    notifyListeners();
  }

  /// Check health of a specific provider with enhanced monitoring
  Future<void> _checkProviderHealth(RegisteredProvider provider) async {
    if (_providerManager == null) return;

    final stopwatch = Stopwatch()..start();
    bool isHealthy = false;
    String? errorDetails;
    
    try {
      // Use provider manager's test method which integrates with LangChain
      isHealthy = await _providerManager.testProviderConnection(provider.info.id);
      stopwatch.stop();
      
      final responseTime = stopwatch.elapsedMilliseconds.toDouble();
      final currentMetrics = _providerHealthMetrics[provider.info.id] ?? 
          ProviderHealthMetrics.empty(provider.info.id);
      
      // Enhanced success rate calculation with weighted moving average
      final alpha = 0.3; // Weight for new measurement (higher = more responsive)
      final newSuccessRate = isHealthy 
          ? (currentMetrics.successRate * (1 - alpha)) + (1.0 * alpha)
          : (currentMetrics.successRate * (1 - alpha)) + (0.0 * alpha);
      
      final consecutiveFailures = isHealthy ? 0 : currentMetrics.consecutiveFailures + 1;
      
      // Enhanced metrics with provider-specific data
      final enhancedMetrics = {
        'provider_type': provider.info.type.toString(),
        'provider_name': provider.info.name,
        'base_url': provider.info.baseUrl,
        'port': provider.info.port,
        'capabilities': provider.info.capabilities,
        'langchain_available': provider.langchainWrapper != null,
        'health_trend': _calculateHealthTrend(currentMetrics, isHealthy),
        'performance_category': _categorizePerformance(responseTime, newSuccessRate),
      };
      
      _providerHealthMetrics[provider.info.id] = currentMetrics.copyWith(
        isHealthy: isHealthy,
        responseTime: responseTime,
        successRate: newSuccessRate,
        lastCheck: DateTime.now(),
        consecutiveFailures: consecutiveFailures,
        additionalMetrics: enhancedMetrics,
      );

      // Log significant health changes
      if (currentMetrics.isHealthy != isHealthy) {
        debugPrint('🔗 [ConnectionManager] Provider ${provider.info.name} health changed: '
            '${currentMetrics.isHealthy ? 'healthy' : 'unhealthy'} → ${isHealthy ? 'healthy' : 'unhealthy'}');
      }
      
    } catch (error) {
      stopwatch.stop();
      errorDetails = error.toString();
      debugPrint('🔗 [ConnectionManager] Provider health check failed for ${provider.info.name}: $error');
      
      final currentMetrics = _providerHealthMetrics[provider.info.id] ?? 
          ProviderHealthMetrics.empty(provider.info.id);
      
      final enhancedMetrics = {
        'provider_type': provider.info.type.toString(),
        'provider_name': provider.info.name,
        'base_url': provider.info.baseUrl,
        'error_details': errorDetails,
        'health_trend': _calculateHealthTrend(currentMetrics, false),
        'performance_category': 'error',
      };
      
      _providerHealthMetrics[provider.info.id] = currentMetrics.copyWith(
        isHealthy: false,
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        lastCheck: DateTime.now(),
        consecutiveFailures: currentMetrics.consecutiveFailures + 1,
        additionalMetrics: enhancedMetrics,
      );
    }
  }

  /// Calculate health trend for provider monitoring
  String _calculateHealthTrend(ProviderHealthMetrics currentMetrics, bool newHealthStatus) {
    if (currentMetrics.consecutiveFailures == 0 && newHealthStatus) {
      return 'stable';
    } else if (currentMetrics.consecutiveFailures == 0 && !newHealthStatus) {
      return 'declining';
    } else if (currentMetrics.consecutiveFailures > 0 && newHealthStatus) {
      return 'recovering';
    } else if (currentMetrics.consecutiveFailures > 3) {
      return 'critical';
    } else {
      return 'unstable';
    }
  }

  /// Categorize provider performance for monitoring
  String _categorizePerformance(double responseTime, double successRate) {
    if (successRate >= 0.95 && responseTime < 1000) {
      return 'excellent';
    } else if (successRate >= 0.9 && responseTime < 2000) {
      return 'good';
    } else if (successRate >= 0.8 && responseTime < 5000) {
      return 'fair';
    } else if (successRate >= 0.5) {
      return 'poor';
    } else {
      return 'critical';
    }
  }

  /// Update connection prioritization based on current health data
  void _updateConnectionPrioritization() {
    if (_providerManager == null) return;

    // Get current best provider
    final currentBest = _getBestHealthyProvider();
    
    // If no healthy providers and we have a preferred provider that's failing,
    // consider switching preferences
    if (currentBest == null && _preferredProviderId != null) {
      final preferredMetrics = _providerHealthMetrics[_preferredProviderId!];
      if (preferredMetrics != null && preferredMetrics.consecutiveFailures > 5) {
        debugPrint('🔗 [ConnectionManager] Preferred provider $_preferredProviderId has too many failures, '
            'considering automatic failover');
        
        // Find the best alternative provider
        final alternatives = _providerManager.availableProviders
            .where((p) => p.info.id != _preferredProviderId)
            .toList();
        
        if (alternatives.isNotEmpty) {
          // Sort by performance score
          alternatives.sort((a, b) {
            final scoreA = _calculateProviderPerformanceScore(a, _providerHealthMetrics[a.info.id]);
            final scoreB = _calculateProviderPerformanceScore(b, _providerHealthMetrics[b.info.id]);
            return scoreB.compareTo(scoreA);
          });
          
          final bestAlternative = alternatives.first;
          debugPrint('🔗 [ConnectionManager] Suggesting failover to ${bestAlternative.info.name}');
          
          // Note: We don't automatically change the preferred provider here,
          // but we log the suggestion for potential UI notification
        }
      }
    }
  }

  /// Get the best healthy provider based on enhanced performance metrics and intelligent prioritization
  RegisteredProvider? _getBestHealthyProvider() {
    if (_providerManager == null) return null;

    final availableProviders = _providerManager.availableProviders;
    if (availableProviders.isEmpty) return null;

    // First, try to get the preferred provider if it's healthy
    if (_preferredProviderId != null) {
      final preferredProvider = availableProviders.firstWhere(
        (p) => p.info.id == _preferredProviderId,
        orElse: () => availableProviders.first,
      );
      
      if (preferredProvider.info.id == _preferredProviderId) {
        final metrics = _providerHealthMetrics[_preferredProviderId!];
        if (metrics?.isHealthy == true && (metrics?.consecutiveFailures ?? 0) < 3) {
          debugPrint('🔗 [ConnectionManager] Using preferred provider: ${preferredProvider.info.name}');
          return preferredProvider;
        }
      }
    }

    // Filter providers by health status with enhanced criteria
    final healthyProviders = availableProviders.where((provider) {
      final metrics = _providerHealthMetrics[provider.info.id];
      return metrics?.isHealthy == true && 
             (metrics?.consecutiveFailures ?? 0) < 3 &&
             metrics!.successRate > 0.7; // Minimum 70% success rate
    }).toList();

    // If no strictly healthy providers, get the best available ones with some tolerance
    if (healthyProviders.isEmpty) {
      final tolerantProviders = availableProviders.where((provider) {
        final metrics = _providerHealthMetrics[provider.info.id];
        return (metrics?.consecutiveFailures ?? 0) < 5 && // Allow up to 5 consecutive failures
               (metrics?.successRate ?? 0.0) > 0.5; // Minimum 50% success rate
      }).toList();
      
      if (tolerantProviders.isNotEmpty) {
        debugPrint('🔗 [ConnectionManager] No strictly healthy providers, using tolerant selection');
        return _selectBestProviderByPerformance(tolerantProviders);
      }
      
      // Last resort: return the first available provider
      debugPrint('🔗 [ConnectionManager] No healthy providers, returning first available');
      return availableProviders.first;
    }

    return _selectBestProviderByPerformance(healthyProviders);
  }

  /// Select the best provider from a list based on comprehensive performance metrics
  RegisteredProvider _selectBestProviderByPerformance(List<RegisteredProvider> providers) {
    if (providers.length == 1) return providers.first;

    // Sort by comprehensive performance score
    providers.sort((a, b) {
      final scoreA = _calculateProviderPerformanceScore(a, _providerHealthMetrics[a.info.id]);
      final scoreB = _calculateProviderPerformanceScore(b, _providerHealthMetrics[b.info.id]);
      
      // Primary sort: performance score (higher is better)
      final scoreComparison = scoreB.compareTo(scoreA);
      if (scoreComparison != 0) return scoreComparison;
      
      // Secondary sort: provider type preference
      final typeComparison = _getProviderTypePriority(b.info.type)
          .compareTo(_getProviderTypePriority(a.info.type));
      if (typeComparison != 0) return typeComparison;
      
      // Tertiary sort: registration time (newer providers first, in case of ties)
      return b.registeredAt.compareTo(a.registeredAt);
    });

    final bestProvider = providers.first;
    final bestScore = _calculateProviderPerformanceScore(bestProvider, _providerHealthMetrics[bestProvider.info.id]);
    
    debugPrint('🔗 [ConnectionManager] Selected best provider: ${bestProvider.info.name} '
        '(score: ${bestScore.toStringAsFixed(1)})');
    
    return bestProvider;
  }

  /// Get provider type priority for sorting
  int _getProviderTypePriority(ProviderType type) {
    switch (type) {
      case ProviderType.ollama:
        return 4; // Highest priority
      case ProviderType.lmStudio:
        return 3;
      case ProviderType.openAICompatible:
        return 2;
      case ProviderType.custom:
        return 1; // Lowest priority
    }
  }

  /// Set preferred provider ID
  void setPreferredProvider(String providerId) {
    _preferredProviderId = providerId;
    debugPrint('🔗 [ConnectionManager] Preferred provider set to: $providerId');
    notifyListeners();
  }

  /// Get provider health status
  Map<String, dynamic> getProviderHealthStatus() {
    final healthStatus = <String, dynamic>{};
    
    for (final entry in _providerHealthMetrics.entries) {
      final metrics = entry.value;
      healthStatus[entry.key] = {
        'healthy': metrics.isHealthy,
        'response_time': metrics.responseTime,
        'success_rate': metrics.successRate,
        'consecutive_failures': metrics.consecutiveFailures,
        'last_check': metrics.lastCheck.toIso8601String(),
        'additional_metrics': metrics.additionalMetrics,
      };
    }
    
    return healthStatus;
  }

  /// Get connection pool status for external monitoring
  Map<String, dynamic> getConnectionPoolStatus() {
    final poolStatus = <String, dynamic>{
      'monitoring_active': _connectionPoolMonitorTimer != null,
      'total_pools': _connectionPoolMetrics.length,
      'healthy_pools': _connectionPoolMetrics.values.where((m) => m.isHealthy).length,
      'pools': _getConnectionPoolSummary(),
    };
    
    return poolStatus;
  }

  /// Get performance metrics for different provider types
  Map<String, dynamic> getProviderTypePerformanceMetrics() {
    final typeMetrics = <String, Map<String, dynamic>>{};
    
    // Group metrics by provider type
    for (final entry in _providerHealthMetrics.entries) {
      final providerId = entry.key;
      final metrics = entry.value;
      final providerType = metrics.additionalMetrics['provider_type'] as String? ?? 'unknown';
      
      if (!typeMetrics.containsKey(providerType)) {
        typeMetrics[providerType] = {
          'provider_count': 0,
          'healthy_count': 0,
          'total_response_time': 0.0,
          'total_success_rate': 0.0,
          'providers': <String>[],
        };
      }
      
      final typeData = typeMetrics[providerType]!;
      typeData['provider_count'] = (typeData['provider_count'] as int) + 1;
      if (metrics.isHealthy) {
        typeData['healthy_count'] = (typeData['healthy_count'] as int) + 1;
      }
      typeData['total_response_time'] = (typeData['total_response_time'] as double) + metrics.responseTime;
      typeData['total_success_rate'] = (typeData['total_success_rate'] as double) + metrics.successRate;
      (typeData['providers'] as List<String>).add(providerId);
    }
    
    // Calculate averages
    final result = <String, dynamic>{};
    for (final entry in typeMetrics.entries) {
      final providerType = entry.key;
      final data = entry.value;
      final count = data['provider_count'] as int;
      
      result[providerType] = {
        'provider_count': count,
        'healthy_count': data['healthy_count'],
        'health_percentage': count > 0 ? ((data['healthy_count'] as int) / count * 100).toStringAsFixed(1) : '0.0',
        'average_response_time': count > 0 ? ((data['total_response_time'] as double) / count).toStringAsFixed(1) : '0.0',
        'average_success_rate': count > 0 ? ((data['total_success_rate'] as double) / count).toStringAsFixed(3) : '0.000',
        'providers': data['providers'],
      };
    }
    
    return result;
  }

  /// Force connection pool cleanup (for testing or manual maintenance)
  void forceConnectionPoolCleanup() {
    debugPrint('🔗 [ConnectionManager] Forcing connection pool cleanup...');
    _performAutomaticCleanup(DateTime.now());
    notifyListeners();
  }

  /// Get connection pool utilization summary
  Map<String, dynamic> getConnectionPoolUtilization() {
    final utilization = <String, dynamic>{};
    
    for (final entry in _connectionPoolMetrics.entries) {
      final poolId = entry.key;
      final metrics = entry.value;
      
      utilization[poolId] = {
        'utilization_percentage': metrics.utilizationPercentage,
        'status': metrics.statusDescription,
        'active_connections': metrics.activeConnections,
        'total_connections': metrics.connectionCount,
        'healthy': metrics.isHealthy,
      };
    }
    
    return utilization;
  }

  /// Get tunnel connectivity status for enhanced monitoring
  Map<String, dynamic> _getTunnelConnectivityStatus() {
    return {
      'http_polling': {
        'connected': _httpPollingClient.isConnected,
        'bridge_id': _httpPollingClient.bridgeId,
        'requests_processed': _httpPollingClient.requestsProcessed,
        'errors_count': _httpPollingClient.errorsCount,
        'last_seen': _httpPollingClient.lastSeen?.toIso8601String(),
        'connected_at': _httpPollingClient.connectedAt?.toIso8601String(),
        'last_error': _httpPollingClient.lastError,
      },
      'authentication': {
        'authenticated': _authService.isAuthenticated.value,
        'user_id': _authService.currentUser?.id,
        'token_valid': _authService.currentUser != null,
      },
    };
  }

  /// Get provider performance ranking for intelligent prioritization
  List<Map<String, dynamic>> _getProviderPerformanceRanking() {
    if (_providerManager == null) return [];

    final providers = _providerManager.availableProviders;
    final rankedProviders = <Map<String, dynamic>>[];

    for (final provider in providers) {
      final metrics = _providerHealthMetrics[provider.info.id];
      final performanceScore = _calculateProviderPerformanceScore(provider, metrics);
      
      rankedProviders.add({
        'provider_id': provider.info.id,
        'provider_name': provider.info.name,
        'provider_type': provider.info.type.toString(),
        'performance_score': performanceScore,
        'health_status': metrics?.isHealthy ?? false,
        'response_time': metrics?.responseTime ?? 0.0,
        'success_rate': metrics?.successRate ?? 0.0,
        'priority_rank': rankedProviders.length + 1,
      });
    }

    // Sort by performance score (higher is better)
    rankedProviders.sort((a, b) => 
        (b['performance_score'] as double).compareTo(a['performance_score'] as double));

    // Update priority ranks
    for (int i = 0; i < rankedProviders.length; i++) {
      rankedProviders[i]['priority_rank'] = i + 1;
    }

    return rankedProviders;
  }

  /// Calculate provider performance score for intelligent prioritization
  double _calculateProviderPerformanceScore(RegisteredProvider provider, ProviderHealthMetrics? metrics) {
    if (metrics == null) return 0.0;

    // Base score from success rate (0-100)
    double score = metrics.successRate * 100;

    // Penalty for high response times (response time in ms, penalty starts at 1000ms)
    if (metrics.responseTime > 1000) {
      final responseTimePenalty = (metrics.responseTime - 1000) / 100; // 1 point per 100ms over 1s
      score -= responseTimePenalty;
    }

    // Penalty for consecutive failures
    score -= metrics.consecutiveFailures * 10;

    // Bonus for provider type preference (Ollama gets highest bonus)
    switch (provider.info.type) {
      case ProviderType.ollama:
        score += 20;
        break;
      case ProviderType.lmStudio:
        score += 15;
        break;
      case ProviderType.openAICompatible:
        score += 10;
        break;
      case ProviderType.custom:
        score += 5;
        break;
    }

    // Bonus for being the preferred provider
    if (provider.info.id == _preferredProviderId) {
      score += 25;
    }

    // Ensure score is not negative
    return score.clamp(0.0, double.infinity);
  }



  /// Attempt automatic reconnection with exponential backoff for failed connections
  Future<void> attemptAutomaticReconnection() async {
    debugPrint('🔗 [ConnectionManager] Starting automatic reconnection sequence...');
    
    // Reconnect local Ollama if needed
    if (!hasLocalConnection && !kIsWeb) {
      await _reconnectWithBackoff(
        'Local Ollama',
        () => _localOllama.reconnect(),
        maxAttempts: 3,
      );
    }
    
    // Reconnect HTTP polling if needed and authenticated
    if (!hasCloudConnection && _authService.isAuthenticated.value) {
      await _reconnectWithBackoff(
        'HTTP Polling',
        () async {
          await _httpPollingClient.disconnect();
          await _httpPollingClient.connect();
        },
        maxAttempts: 5,
      );
    }
    
    // Trigger provider health checks to update their status
    if (_providerManager != null) {
      await _performProviderHealthChecks();
    }
    
    debugPrint('🔗 [ConnectionManager] Automatic reconnection sequence completed');
    notifyListeners();
  }

  /// Reconnect a service with exponential backoff
  Future<bool> _reconnectWithBackoff(
    String serviceName,
    Future<void> Function() reconnectFunction, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    Duration currentDelay = initialDelay;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('🔗 [ConnectionManager] Reconnecting $serviceName (attempt $attempt/$maxAttempts)');
        
        await reconnectFunction();
        
        debugPrint('🔗 [ConnectionManager] ✅ $serviceName reconnected successfully');
        return true;
        
      } catch (error) {
        debugPrint('🔗 [ConnectionManager] ❌ $serviceName reconnection failed (attempt $attempt): $error');
        
        if (attempt < maxAttempts) {
          debugPrint('🔗 [ConnectionManager] Waiting ${currentDelay.inSeconds}s before next attempt...');
          await Future.delayed(currentDelay);
          currentDelay = Duration(
            milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
          );
        }
      }
    }
    
    debugPrint('🔗 [ConnectionManager] ❌ $serviceName reconnection failed after $maxAttempts attempts');
    return false;
  }

  /// Get comprehensive connection diagnostics for troubleshooting
  Map<String, dynamic> getConnectionDiagnostics() {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'platform': kIsWeb ? 'web' : 'desktop',
      'overall_status': {
        'has_any_connection': hasAnyConnection,
        'best_connection_type': getBestConnectionType().name,
        'connection_count': [
          if (hasLocalConnection) 'local',
          if (hasCloudConnection) 'cloud', 
          if (hasProviderConnection) 'provider',
        ].length,
      },
      'local_connection': {
        'available': hasLocalConnection,
        'healthy': !kIsWeb && _isLocalOllamaHealthy(),
        'version': _localOllama.version,
        'models_count': _localOllama.models.length,
        'error': _localOllama.error,
        'last_check': _localOllama.lastCheck?.toIso8601String(),
      },
      'cloud_connection': {
        'available': hasCloudConnection,
        'healthy': _isTunnelConnectivityHealthy(),
        'tunnel_status': _getTunnelConnectivityStatus(),
      },
      'provider_connections': {
        'total_registered': _providerManager?.registeredProviders.length ?? 0,
        'available_count': _providerManager?.availableProviders.length ?? 0,
        'healthy_count': _providerHealthMetrics.values.where((m) => m.isHealthy).length,
        'provider_details': _getProviderDiagnostics(),
      },
      'health_monitoring': {
        'active': _providerHealthTimer != null,
        'check_interval_seconds': _healthCheckInterval.inSeconds,
        'last_check': _providerHealthMetrics.values
            .map((m) => m.lastCheck)
            .fold<DateTime?>(null, (latest, current) => 
                latest == null || current.isAfter(latest) ? current : latest)
            ?.toIso8601String(),
      },
      'performance_metrics': _getPerformanceMetrics(),
      'connection_pool_monitoring': {
        'active': _connectionPoolMonitorTimer != null,
        'monitor_interval_seconds': _poolMonitorInterval.inSeconds,
        'total_pools': _connectionPoolMetrics.length,
        'pool_metrics': _getDetailedConnectionPoolMetrics(),
        'connection_history': _getConnectionHistorySummary(),
        'automatic_cleanup': {
          'enabled': true,
          'history_retention_hours': _connectionHistoryRetention.inHours,
          'max_history_entries': _maxConnectionHistoryEntries,
        },
      },
    };
    
    return diagnostics;
  }

  /// Get provider-specific diagnostics
  Map<String, dynamic> _getProviderDiagnostics() {
    final providerDiagnostics = <String, dynamic>{};
    
    if (_providerManager != null) {
      for (final provider in _providerManager.registeredProviders) {
        final metrics = _providerHealthMetrics[provider.info.id];
        
        providerDiagnostics[provider.info.id] = {
          'name': provider.info.name,
          'type': provider.info.type.toString(),
          'enabled': provider.isEnabled,
          'available': provider.isAvailable,
          'base_url': provider.info.baseUrl,
          'port': provider.info.port,
          'health_status': provider.healthStatus.toString(),
          'langchain_wrapper': provider.langchainWrapper != null,
          'metrics': metrics != null ? {
            'healthy': metrics.isHealthy,
            'response_time_ms': metrics.responseTime,
            'success_rate': metrics.successRate,
            'consecutive_failures': metrics.consecutiveFailures,
            'last_check': metrics.lastCheck.toIso8601String(),
            'performance_category': metrics.additionalMetrics['performance_category'],
            'health_trend': metrics.additionalMetrics['health_trend'],
          } : null,
        };
      }
    }
    
    return providerDiagnostics;
  }

  /// Get overall performance metrics
  Map<String, dynamic> _getPerformanceMetrics() {
    final allMetrics = _providerHealthMetrics.values.toList();
    
    if (allMetrics.isEmpty) {
      return {
        'average_response_time': 0.0,
        'overall_success_rate': 0.0,
        'total_providers': 0,
      };
    }
    
    final avgResponseTime = allMetrics
        .map((m) => m.responseTime)
        .reduce((a, b) => a + b) / allMetrics.length;
    
    final avgSuccessRate = allMetrics
        .map((m) => m.successRate)
        .reduce((a, b) => a + b) / allMetrics.length;
    
    return {
      'average_response_time': avgResponseTime,
      'overall_success_rate': avgSuccessRate,
      'total_providers': allMetrics.length,
      'healthy_providers': allMetrics.where((m) => m.isHealthy).length,
    };
  }

  /// Get connection pool summary for status reporting
  Map<String, dynamic> _getConnectionPoolSummary() {
    final poolSummary = <String, dynamic>{};
    
    for (final entry in _connectionPoolMetrics.entries) {
      final poolId = entry.key;
      final metrics = entry.value;
      
      poolSummary[poolId] = {
        'connection_count': metrics.connectionCount,
        'active_connections': metrics.activeConnections,
        'idle_connections': metrics.idleConnections,
        'active_requests': metrics.activeRequests,
        'utilization_percentage': metrics.utilizationPercentage,
        'response_time': metrics.responseTime,
        'last_activity': metrics.lastActivity.toIso8601String(),
        'healthy': metrics.isHealthy,
        'status': metrics.statusDescription,
        'provider_info': metrics.additionalMetrics,
      };
    }
    
    return poolSummary;
  }

  /// Get detailed connection pool metrics for diagnostics
  Map<String, dynamic> _getDetailedConnectionPoolMetrics() {
    final detailedMetrics = <String, dynamic>{};
    
    for (final entry in _connectionPoolMetrics.entries) {
      final poolId = entry.key;
      final metrics = entry.value;
      
      detailedMetrics[poolId] = {
        'pool_id': poolId,
        'connection_count': metrics.connectionCount,
        'active_connections': metrics.activeConnections,
        'idle_connections': metrics.idleConnections,
        'active_requests': metrics.activeRequests,
        'utilization_percentage': metrics.utilizationPercentage.toStringAsFixed(1),
        'response_time_ms': metrics.responseTime,
        'last_activity': metrics.lastActivity.toIso8601String(),
        'time_since_activity_minutes': DateTime.now().difference(metrics.lastActivity).inMinutes,
        'healthy': metrics.isHealthy,
        'status': metrics.statusDescription,
        'provider_type': metrics.additionalMetrics['provider_type'],
        'additional_metrics': metrics.additionalMetrics,
      };
    }
    
    return detailedMetrics;
  }

  /// Get connection history summary for trend analysis
  Map<String, dynamic> _getConnectionHistorySummary() {
    final historySummary = <String, dynamic>{};
    
    for (final entry in _connectionHistory.entries) {
      final poolId = entry.key;
      final history = entry.value;
      
      if (history.isNotEmpty) {
        final now = DateTime.now();
        final recentHistory = history.where((timestamp) => 
            now.difference(timestamp).inMinutes <= 60).toList();
        
        historySummary[poolId] = {
          'total_entries': history.length,
          'recent_entries_1h': recentHistory.length,
          'oldest_entry': history.first.toIso8601String(),
          'newest_entry': history.last.toIso8601String(),
          'connection_frequency_per_hour': recentHistory.length,
        };
      }
    }
    
    return historySummary;
  }

  @override
  void dispose() {
    debugPrint('🔗 [ConnectionManager] Disposing service');
    _localOllama.removeListener(_onConnectionChanged);
    _httpPollingClient.removeListener(_onConnectionChanged);
    _authService.removeListener(_onAuthChanged);
    _cloudStreamingService?.dispose();
    _stopProviderHealthMonitoring();
    _stopConnectionPoolMonitoring();
    super.dispose();
  }
}



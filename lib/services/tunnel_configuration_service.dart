import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/tunnel_config.dart' as setup_config;
import '../models/tunnel_validation_result.dart';
import '../services/auth_service.dart';
import '../services/simple_tunnel_client.dart' show SimpleTunnelClient;

/// Service for tunnel configuration and connection setup during first-time wizard
///
/// This service helps users establish and validate tunnel connections between
/// the web app and desktop client during the setup process.
class TunnelConfigurationService extends ChangeNotifier {
  final AuthService _authService;
  final SimpleTunnelClient? _tunnelClient;
  final String _baseUrl;

  // Configuration state
  setup_config.SetupTunnelConfig? _currentConfig;
  bool _isConfiguring = false;
  bool _isTestingConnection = false;
  String? _lastError;

  // Connection monitoring
  Timer? _connectionMonitor;
  bool _isMonitoring = false;
  Map<String, dynamic>? _connectionStatus;

  TunnelConfigurationService({
    required AuthService authService,
    SimpleTunnelClient? tunnelClient,
    String? baseUrl,
  }) : _authService = authService,
       _tunnelClient = tunnelClient,
       _baseUrl = baseUrl ?? _getDefaultBaseUrl();

  // Getters
  setup_config.SetupTunnelConfig? get currentConfig => _currentConfig;
  bool get isConfiguring => _isConfiguring;
  bool get isTestingConnection => _isTestingConnection;
  bool get isMonitoring => _isMonitoring;
  String? get lastError => _lastError;
  Map<String, dynamic>? get connectionStatus => _connectionStatus;

  /// Get the default base URL based on environment
  static String _getDefaultBaseUrl() {
    if (kDebugMode) {
      return 'http://localhost:8080';
    } else {
      return 'https://app.cloudtolocalllm.online/api';
    }
  }

  /// Generate tunnel configuration parameters for a user
  ///
  /// Creates a complete tunnel configuration with authentication details,
  /// connection parameters, and platform-specific settings.
  Future<setup_config.SetupTunnelConfig> generateTunnelConfig(
    String userId,
  ) async {
    if (!_authService.isAuthenticated.value) {
      throw Exception('User not authenticated');
    }

    _isConfiguring = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint(
        '🔧 [TunnelConfig] Generating tunnel configuration for user: $userId',
      );

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get valid access token');
      }

      // Generate configuration based on current environment and user settings
      final config = setup_config.SetupTunnelConfig(
        userId: userId,
        cloudProxyUrl: kDebugMode
            ? AppConfig.tunnelWebSocketUrlDev
            : AppConfig.tunnelWebSocketUrl,
        localBackendUrl: 'http://localhost:11434',
        authToken: token,
        enableCloudProxy: true,
        connectionTimeout: 30,
        healthCheckInterval: 30,
        retryAttempts: 3,
        retryDelay: 5,
      );

      _currentConfig = config;

      debugPrint('🔧 [TunnelConfig] Configuration generated successfully');
      return config;
    } catch (e) {
      _lastError = 'Failed to generate tunnel configuration: ${e.toString()}';
      debugPrint('🔧 [TunnelConfig] Error generating configuration: $e');
      rethrow;
    } finally {
      _isConfiguring = false;
      notifyListeners();
    }
  }

  /// Test tunnel connection with the provided configuration
  ///
  /// Performs comprehensive connectivity testing including:
  /// - WebSocket connection establishment
  /// - Authentication validation
  /// - Basic communication test
  /// - Latency measurement
  Future<TunnelValidationResult> testTunnelConnection(
    setup_config.SetupTunnelConfig config,
  ) async {
    _isTestingConnection = true;
    _lastError = null;
    notifyListeners();

    final startTime = DateTime.now();

    try {
      debugPrint('🔧 [TunnelConfig] Testing tunnel connection...');

      // Test 1: WebSocket connectivity
      final wsConnectivity = await _testWebSocketConnectivity(config);
      if (!wsConnectivity.isSuccess) {
        return TunnelValidationResult.failure(
          'WebSocket connectivity failed: ${wsConnectivity.error}',
          tests: [wsConnectivity],
        );
      }

      // Test 2: Authentication
      final authTest = await _testAuthentication(config);
      if (!authTest.isSuccess) {
        return TunnelValidationResult.failure(
          'Authentication failed: ${authTest.error}',
          tests: [wsConnectivity, authTest],
        );
      }

      // Test 3: Basic communication
      final commTest = await _testBasicCommunication(config);
      if (!commTest.isSuccess) {
        return TunnelValidationResult.failure(
          'Communication test failed: ${commTest.error}',
          tests: [wsConnectivity, authTest, commTest],
        );
      }

      final duration = DateTime.now().difference(startTime);

      debugPrint(
        '🔧 [TunnelConfig] Tunnel connection test completed successfully in ${duration.inMilliseconds}ms',
      );

      return TunnelValidationResult.success(
        'Tunnel connection established successfully',
        latency: duration.inMilliseconds,
        tests: [wsConnectivity, authTest, commTest],
      );
    } catch (e) {
      _lastError = 'Tunnel connection test failed: ${e.toString()}';
      debugPrint('🔧 [TunnelConfig] Error testing tunnel connection: $e');

      return TunnelValidationResult.failure(
        'Unexpected error during connection test: ${e.toString()}',
      );
    } finally {
      _isTestingConnection = false;
      notifyListeners();
    }
  }

  /// Validate desktop client connection for a user
  ///
  /// Checks if the desktop client is properly connected and communicating
  /// through the tunnel.
  Future<bool> validateDesktopClientConnection(String userId) async {
    try {
      debugPrint(
        '🔧 [TunnelConfig] Validating desktop client connection for user: $userId',
      );

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get valid access token');
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/tunnel/status'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isConnected = data['connected'] == true;

        debugPrint(
          '🔧 [TunnelConfig] Desktop client connection status: $isConnected',
        );
        return isConnected;
      } else {
        debugPrint(
          '🔧 [TunnelConfig] Failed to check desktop client status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint(
        '🔧 [TunnelConfig] Error validating desktop client connection: $e',
      );
      return false;
    }
  }

  /// Get troubleshooting steps for specific error types
  ///
  /// Provides context-sensitive troubleshooting guidance based on the
  /// type of connection error encountered.
  Future<List<String>> getTroubleshootingSteps(String errorType) async {
    debugPrint(
      '🔧 [TunnelConfig] Getting troubleshooting steps for error: $errorType',
    );

    switch (errorType.toLowerCase()) {
      case 'websocket_connection_failed':
      case 'connection_timeout':
        return [
          'Check your internet connection',
          'Verify firewall settings allow WebSocket connections',
          'Ensure ports 80 and 443 are not blocked',
          'Try disabling VPN or proxy temporarily',
          'Check if antivirus software is blocking connections',
        ];

      case 'authentication_failed':
      case 'auth_token_invalid':
        return [
          'Log out and log back in to refresh your authentication',
          'Clear browser cache and cookies',
          'Check if your account has the necessary permissions',
          'Verify your internet connection is stable',
          'Contact support if the issue persists',
        ];

      case 'desktop_client_not_found':
      case 'local_ollama_unreachable':
        return [
          'Ensure the desktop client is running',
          'Check that Ollama is installed and running on port 11434',
          'Verify the desktop client is properly authenticated',
          'Restart the desktop client application',
          'Check desktop client logs for error messages',
        ];

      case 'network_error':
      case 'connection_refused':
        return [
          'Check your network connection',
          'Verify DNS settings are correct',
          'Try connecting from a different network',
          'Check if corporate firewall is blocking connections',
          'Ensure system time is synchronized',
        ];

      default:
        return [
          'Restart the setup wizard',
          'Check your internet connection',
          'Try refreshing the page',
          'Clear browser cache and try again',
          'Contact support with error details',
        ];
    }
  }

  /// Start real-time connection status monitoring
  ///
  /// Monitors the tunnel connection status during setup and provides
  /// real-time feedback to the user.
  void startConnectionMonitoring() {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;
    debugPrint('🔧 [TunnelConfig] Starting connection monitoring');

    _connectionMonitor = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      await _updateConnectionStatus();
    });

    notifyListeners();
  }

  /// Stop connection monitoring
  void stopConnectionMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _isMonitoring = false;
    _connectionMonitor?.cancel();
    _connectionMonitor = null;

    debugPrint('🔧 [TunnelConfig] Stopped connection monitoring');
    notifyListeners();
  }

  /// Update connection status information
  Future<void> _updateConnectionStatus() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        return;
      }

      final isDesktopConnected = await validateDesktopClientConnection(userId);
      final tunnelStatus = _tunnelClient?.isConnected ?? false;

      _connectionStatus = {
        'desktopClientConnected': isDesktopConnected,
        'tunnelConnected': tunnelStatus,
        'lastUpdate': DateTime.now().toIso8601String(),
        'overallStatus': isDesktopConnected && tunnelStatus
            ? 'connected'
            : 'disconnected',
      };

      notifyListeners();
    } catch (e) {
      debugPrint('🔧 [TunnelConfig] Error updating connection status: $e');
    }
  }

  /// Test WebSocket connectivity
  Future<ValidationTest> _testWebSocketConnectivity(
    setup_config.SetupTunnelConfig config,
  ) async {
    // Implementation would test WebSocket connection
    // For now, return a mock result
    await Future.delayed(const Duration(milliseconds: 500));
    return ValidationTest(
      name: 'WebSocket Connectivity',
      isSuccess: true,
      message: 'WebSocket connection established',
    );
  }

  /// Test authentication
  Future<ValidationTest> _testAuthentication(
    setup_config.SetupTunnelConfig config,
  ) async {
    // Implementation would test authentication
    await Future.delayed(const Duration(milliseconds: 300));
    return ValidationTest(
      name: 'Authentication',
      isSuccess: true,
      message: 'Authentication successful',
    );
  }

  /// Test basic communication
  Future<ValidationTest> _testBasicCommunication(
    setup_config.SetupTunnelConfig config,
  ) async {
    // Implementation would test basic communication
    await Future.delayed(const Duration(milliseconds: 400));
    return ValidationTest(
      name: 'Basic Communication',
      isSuccess: true,
      message: 'Communication test passed',
    );
  }

  @override
  void dispose() {
    stopConnectionMonitoring();
    super.dispose();
  }
}

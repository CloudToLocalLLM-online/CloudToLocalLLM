import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/tunnel_config.dart';
import '../models/tunnel_validation_result.dart';
import '../services/auth_service.dart';
import 'chisel_tunnel_client.dart';

/// Service for tunnel configuration and connection management.
class TunnelConfigurationService extends ChangeNotifier {
  final AuthService _authService;
  ChiselTunnelClient? _tunnelClient;
  final String _baseUrl;

  TunnelConfig? _currentConfig;
  bool _isConfiguring = false;
  bool _isTestingConnection = false;
  String? _lastError;
  Timer? _connectionMonitor;
  bool _isMonitoring = false;
  Map<String, dynamic>? _connectionStatus;

  TunnelConfigurationService({
    required AuthService authService,
    String? baseUrl,
  })  : _authService = authService,
        _baseUrl = baseUrl ?? _getDefaultBaseUrl();

  TunnelConfig? get currentConfig => _currentConfig;
  bool get isConfiguring => _isConfiguring;
  bool get isTestingConnection => _isTestingConnection;
  bool get isMonitoring => _isMonitoring;
  String? get lastError => _lastError;
  Map<String, dynamic>? get connectionStatus => _connectionStatus;
  ChiselTunnelClient? get tunnelClient => _tunnelClient;

  static String _getDefaultBaseUrl() {
    return kDebugMode ? 'http://localhost:8080' : 'https://app.cloudtolocalllm.online/api';
  }

  Future<TunnelConfig> generateTunnelConfig(String userId) async {
    if (!_authService.isAuthenticated.value) {
      throw Exception('User not authenticated');
    }
    _isConfiguring = true;
    _lastError = null;
    notifyListeners();

    try {
      final token = await _authService.getValidatedAccessToken();
      if (token == null) throw Exception('Failed to get valid access token');

      final config = TunnelConfig(
        userId: userId,
        cloudProxyUrl: kDebugMode ? AppConfig.tunnelWebSocketUrlDev : AppConfig.tunnelWebSocketUrl,
        localBackendUrl: 'http://localhost:11434',
        authToken: token,
        enableCloudProxy: true,
      );
      _currentConfig = config;
      _initializeTunnelClient(config);
      return config;
    } catch (e) {
      _lastError = 'Failed to generate tunnel configuration: $e';
      rethrow;
    } finally {
      _isConfiguring = false;
      notifyListeners();
    }
  }

  void _initializeTunnelClient(TunnelConfig config) {
    _tunnelClient?.dispose();
    _tunnelClient = ChiselTunnelClient(config);
    _tunnelClient!.addListener(_onTunnelStatusChanged);
    _tunnelClient!.connect();
  }

  void _onTunnelStatusChanged() {
    _updateConnectionStatus();
    notifyListeners();
  }

  Future<TunnelValidationResult> testTunnelConnection() async {
    if (_tunnelClient == null) {
      return TunnelValidationResult.failure('Tunnel client not initialized.');
    }
    _isTestingConnection = true;
    _lastError = null;
    notifyListeners();

    try {
      if (!_tunnelClient!.isConnected) {
        await _tunnelClient!.connect();
        // Give it a moment to establish connection
        await Future.delayed(const Duration(seconds: 2));
      }

      if (_tunnelClient!.isConnected) {
        return TunnelValidationResult.success('Tunnel connection is active.');
      } else {
        return TunnelValidationResult.failure('Failed to establish WebSocket connection.');
      }
    } catch (e) {
      return TunnelValidationResult.failure('Connection test failed: $e');
    } finally {
      _isTestingConnection = false;
      notifyListeners();
    }
  }

  Future<bool> validateDesktopClientConnection(String userId) async {
    try {
      final token = await _authService.getValidatedAccessToken();
      if (token == null) throw Exception('Failed to get valid access token');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/tunnel/health/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['connected'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error validating desktop client connection: $e');
      return false;
    }
  }

  void startConnectionMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _connectionMonitor = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateConnectionStatus();
    });
    notifyListeners();
  }

  void stopConnectionMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    _connectionMonitor?.cancel();
    _connectionMonitor = null;
    notifyListeners();
  }

  Future<void> _updateConnectionStatus() async {
    final isDesktopConnected = _tunnelClient?.isConnected ?? false;
    _connectionStatus = {
      'desktopClientConnected': isDesktopConnected,
      'tunnelConnected': isDesktopConnected,
      'lastUpdate': DateTime.now().toIso8601String(),
      'overallStatus': isDesktopConnected ? 'connected' : 'disconnected',
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _tunnelClient?.removeListener(_onTunnelStatusChanged);
    _tunnelClient?.dispose();
    stopConnectionMonitoring();
    super.dispose();
  }
}

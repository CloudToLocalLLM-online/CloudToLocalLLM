import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

import '../utils/tunnel_logger.dart';
import 'auth_service.dart';

class HttpPollingTunnelClient extends ChangeNotifier {
  final AuthService _authService;
  final TunnelLogger _logger;
  final http.Client _httpClient;

  // Connection state
  bool _isConnected = false;
  bool _isPolling = false;
  String? _bridgeId;
  String? _lastError;
  DateTime? _lastSeen;

  // Polling configuration
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  int _pollingInterval = 5000; // 5 seconds
  int _heartbeatInterval = 30000; // 30 seconds
  int _requestTimeout = 60000; // 60 seconds

  // Statistics
  int _requestsProcessed = 0;
  int _errorsCount = 0;
  DateTime? _connectedAt;

  HttpPollingTunnelClient({
    required AuthService authService,
    required TunnelLogger logger,
    http.Client? httpClient,
  }) : _authService = authService,
       _logger = logger,
       _httpClient = httpClient ?? http.Client();

  // Getters
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String? get bridgeId => _bridgeId;
  String? get lastError => _lastError;
  DateTime? get lastSeen => _lastSeen;
  int get requestsProcessed => _requestsProcessed;
  int get errorsCount => _errorsCount;
  DateTime? get connectedAt => _connectedAt;

  /// Start HTTP polling connection
  Future<void> connect() async {
    if (_isConnected || _isPolling) {
      debugPrint('🌉 [HttpPolling] Already connected or connecting');
      return;
    }

    try {
      debugPrint('🌉 [HttpPolling] Starting HTTP polling connection...');

      // Register bridge
      await _registerBridge();

      // Start polling and heartbeat
      _startPolling();
      _startHeartbeat();

      _isConnected = true;
      _connectedAt = DateTime.now();
      _lastError = null;

      debugPrint(
        '🌉 [HttpPolling] ✅ Connected successfully with bridge ID: $_bridgeId',
      );

      _logger.logConnection(
        'http_polling_connected',
        _bridgeId!,
        userId: _authService.currentUser?.id,
        context: {
          'pollingInterval': _pollingInterval,
          'heartbeatInterval': _heartbeatInterval,
        },
      );

      notifyListeners();
    } catch (e) {
      _lastError = 'Connection failed: $e';
      debugPrint('🌉 [HttpPolling] ❌ Connection failed: $e');

      _logger.logTunnelError(
        TunnelErrorCodes.connectionFailed,
        'HTTP polling connection failed',
        context: {'error': e.toString()},
        error: e,
      );

      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('🌉 [HttpPolling] Disconnecting...');

    _isConnected = false;
    _isPolling = false;

    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_bridgeId != null) {
      _logger.logConnection(
        'http_polling_disconnected',
        _bridgeId!,
        userId: _authService.currentUser?.id,
        context: {
          'requestsProcessed': _requestsProcessed,
          'errorsCount': _errorsCount,
          'uptime': _connectedAt != null
              ? DateTime.now().difference(_connectedAt!).inSeconds
              : 0,
        },
      );
    }

    _bridgeId = null;
    _connectedAt = null;

    notifyListeners();
  }

  /// Register bridge with server
  Future<void> _registerBridge() async {
    print('🌉 [DEBUG] Attempting to get access token...');
    final accessToken = _authService.getAccessToken();
    print(
      '🌉 [DEBUG] Access token retrieved: ${accessToken != null ? "YES (${accessToken.substring(0, 20)}...)" : "NO"}',
    );

    if (accessToken == null) {
      print('🌉 [DEBUG] No access token available - throwing exception');
      throw Exception('No authentication token available');
    }

    print('🌉 [DEBUG] Making bridge registration request...');

    final response = await _httpClient
        .post(
          Uri.parse(AppConfig.bridgeRegisterUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'clientId': 'flutter-desktop-${_getPlatformName()}',
            'platform': _getPlatformName(),
            'version': '4.0.0',
            'capabilities': ['ollama', 'streaming', 'http-polling'],
          }),
        )
        .timeout(Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Bridge registration failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = json.decode(response.body);
    if (!data['success']) {
      throw Exception('Bridge registration failed: ${data['message']}');
    }

    _bridgeId = data['bridgeId'];

    // Update configuration from server
    final config = data['config'];
    if (config != null) {
      _pollingInterval = config['pollingInterval'] ?? _pollingInterval;
      _heartbeatInterval = config['heartbeatInterval'] ?? _heartbeatInterval;
      _requestTimeout = config['requestTimeout'] ?? _requestTimeout;
    }

    debugPrint('🌉 [HttpPolling] Bridge registered: $_bridgeId');
  }

  /// Start polling for requests
  void _startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _pollForRequests();
  }

  /// Poll for pending requests
  Future<void> _pollForRequests() async {
    if (!_isPolling || _bridgeId == null) return;

    try {
      final accessToken = _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await _httpClient
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/bridge/$_bridgeId/poll?timeout=30000',
            ),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            Duration(seconds: 35),
          ); // Slightly longer than server timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] && data['requests'] != null) {
          final requests = List<Map<String, dynamic>>.from(data['requests']);

          if (requests.isNotEmpty) {
            debugPrint('🌉 [HttpPolling] Received ${requests.length} requests');

            // Process requests
            for (final request in requests) {
              await _processRequest(request);
            }
          }
        }

        _lastSeen = DateTime.now();
        _lastError = null;
      } else {
        throw Exception('Polling failed: ${response.statusCode}');
      }
    } catch (e) {
      _errorsCount++;
      _lastError = 'Polling error: $e';
      debugPrint('🌉 [HttpPolling] Polling error: $e');

      // Don't log every timeout as an error
      if (!e.toString().contains('timeout')) {
        _logger.logTunnelError(
          TunnelErrorCodes.pollingFailed,
          'HTTP polling failed',
          context: {'error': e.toString()},
          error: e,
        );
      }
    }

    // Schedule next poll
    if (_isPolling) {
      _pollingTimer = Timer(
        Duration(milliseconds: _pollingInterval),
        _pollForRequests,
      );
    }
  }

  /// Process a request from the server
  Future<void> _processRequest(Map<String, dynamic> requestData) async {
    final requestId = requestData['id'];

    try {
      debugPrint('🌉 [HttpPolling] Processing request: $requestId');

      // Extract HTTP request details
      final method = requestData['data']['method'] ?? 'GET';
      final path = requestData['data']['path'] ?? '/';
      final headers = Map<String, String>.from(
        requestData['data']['headers'] ?? {},
      );
      final body = requestData['data']['body'];

      // Forward to local Ollama
      final ollamaResponse = await _forwardToOllama(
        method,
        path,
        headers,
        body,
      );

      // Send response back to server
      await _sendResponse(requestId, ollamaResponse);

      _requestsProcessed++;

      debugPrint('🌉 [HttpPolling] ✅ Request processed: $requestId');
    } catch (e) {
      _errorsCount++;
      debugPrint(
        '🌉 [HttpPolling] ❌ Request processing failed: $requestId - $e',
      );

      // Send error response
      await _sendResponse(requestId, {
        'status': 500,
        'headers': {'content-type': 'application/json'},
        'body': json.encode({
          'error': 'Request processing failed',
          'message': e.toString(),
        }),
        'error': e.toString(),
      });

      _logger.logTunnelError(
        TunnelErrorCodes.requestProcessingFailed,
        'Request processing failed',
        context: {'requestId': requestId, 'error': e.toString()},
        error: e,
      );
    }
  }

  /// Forward request to local Ollama
  Future<Map<String, dynamic>> _forwardToOllama(
    String method,
    String path,
    Map<String, String> headers,
    String? body,
  ) async {
    final ollamaUrl = 'http://localhost:11434$path';

    final request = http.Request(method, Uri.parse(ollamaUrl));
    request.headers.addAll(headers);

    if (body != null && body.isNotEmpty) {
      request.body = body;
    }

    final streamedResponse = await _httpClient.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();

    return {
      'status': streamedResponse.statusCode,
      'headers': streamedResponse.headers,
      'body': responseBody,
    };
  }

  /// Send response back to server
  Future<void> _sendResponse(
    String requestId,
    Map<String, dynamic> responseData,
  ) async {
    final accessToken = _authService.getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/bridge/$_bridgeId/response'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'requestId': requestId, ...responseData}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Response submission failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🌉 [HttpPolling] Failed to send response: $e');
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: _heartbeatInterval),
      (_) {
        _sendHeartbeat();
      },
    );
  }

  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    if (_bridgeId == null) return;

    final accessToken = _authService.getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/bridge/$_bridgeId/heartbeat'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        _lastSeen = DateTime.now();
      }
    } catch (e) {
      debugPrint('🌉 [HttpPolling] Heartbeat failed: $e');
    }
  }

  /// Get platform name safely (web-compatible)
  String _getPlatformName() {
    if (kIsWeb) {
      return 'web';
    }

    try {
      return Platform.operatingSystem;
    } catch (e) {
      debugPrint('🌉 [HttpPolling] Platform detection failed: $e');
      return 'unknown';
    }
  }

  @override
  void dispose() {
    disconnect();
    _httpClient.close();
    super.dispose();
  }
}

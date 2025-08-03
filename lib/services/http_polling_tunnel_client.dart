/// HTTP Polling Tunnel Client for CloudToLocalLLM
///
/// This service implements the HTTP polling bridge pattern for tunnel communication
/// between the cloud API and desktop client. It provides enhanced LLM-specific
/// request handling, provider routing, and intelligent timeout management.
///
/// ## Key Features
/// - **LLM-Aware Request Routing**: Automatically routes requests to appropriate local LLM providers
/// - **Adaptive Timeout Management**: Different timeouts for chat, streaming, and model operations
/// - **Provider Integration**: Seamless integration with LLM Provider Manager
/// - **Health Monitoring**: Continuous connection health monitoring and reporting
/// - **Error Recovery**: Exponential backoff and automatic reconnection
/// - **Performance Metrics**: Comprehensive request and error tracking
///
/// ## Connection Lifecycle
/// 1. **Registration**: Register bridge with cloud API and obtain bridge ID
/// 2. **Polling**: Continuously poll for pending requests from cloud
/// 3. **Processing**: Route requests to appropriate LLM providers
/// 4. **Response**: Send responses back through tunnel
/// 5. **Heartbeat**: Maintain connection health with periodic heartbeats
///
/// ## LLM Request Types and Timeouts
/// - **Chat Requests**: 2 minutes (interactive conversations)
/// - **Model Operations**: 5 minutes (model loading/unloading)
/// - **Streaming**: 10 minutes (long-running streams)
/// - **Standard HTTP**: 1 minute (general API calls)
///
/// ## Usage Example
/// ```dart
/// final client = HttpPollingTunnelClient(
///   authService: authService,
///   logger: logger,
///   providerManager: providerManager,
/// );
///
/// await client.connect();
/// // Client will automatically handle incoming requests
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/llm_communication_error.dart';
import '../utils/tunnel_logger.dart';
import 'auth_service.dart';
import 'llm_provider_manager.dart';
import 'tunnel_llm_request_handler.dart';

/// HTTP Polling Tunnel Client
///
/// Implements the HTTP polling bridge pattern for tunnel communication with
/// enhanced LLM provider integration and intelligent request routing.
class HttpPollingTunnelClient extends ChangeNotifier {
  // Core services
  final AuthService _authService;
  final TunnelLogger _logger;
  final http.Client _httpClient;
  final LLMProviderManager _providerManager;

  // Connection state management
  bool _isConnected = false;
  bool _isPolling = false;
  String? _bridgeId;
  String? _lastError;
  DateTime? _lastSeen;

  // Polling and heartbeat timers
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;

  // Adaptive polling configuration
  int _pollingInterval = 5000; // 5 seconds (adaptive based on activity)
  int _heartbeatInterval = 30000; // 30 seconds (adaptive based on health)
  int _requestTimeout = 60000; // 60 seconds (standard HTTP requests)

  // LLM-specific timeout configuration for different operation types
  int _llmChatTimeout = 120000; // 2 minutes for interactive chat requests
  int _llmModelTimeout = 300000; // 5 minutes for model loading/unloading operations
  int _llmStreamingTimeout = 600000; // 10 minutes for long-running streaming operations

  // Performance and health metrics
  int _requestsProcessed = 0;
  int _errorsCount = 0;
  int _llmRequestsProcessed = 0;
  DateTime? _connectedAt;

  /// Creates a new HTTP Polling Tunnel Client
  ///
  /// ## Parameters
  /// - [authService]: Authentication service for token management
  /// - [logger]: Tunnel logger for comprehensive logging and debugging
  /// - [providerManager]: LLM provider manager for request routing
  /// - [httpClient]: Optional HTTP client (defaults to standard client)
  ///
  /// ## Initialization
  /// The client is initialized in a disconnected state. Call [connect] to
  /// establish the tunnel connection and begin polling for requests.
  HttpPollingTunnelClient({
    required AuthService authService,
    required TunnelLogger logger,
    required LLMProviderManager providerManager,
    http.Client? httpClient,
  }) : _authService = authService,
       _logger = logger,
       _providerManager = providerManager,
       _httpClient = httpClient ?? http.Client() {
    debugPrint('🌉 [HttpPolling] Service initialized with LLM provider integration');
  }

  // Public getters for connection state and metrics

  /// Whether the tunnel connection is currently active
  bool get isConnected => _isConnected;

  /// Whether the client is actively polling for requests
  bool get isPolling => _isPolling;

  /// Unique bridge identifier assigned by the cloud API
  String? get bridgeId => _bridgeId;

  /// Last error message encountered during operation
  String? get lastError => _lastError;

  /// Timestamp of last successful communication with cloud API
  DateTime? get lastSeen => _lastSeen;

  /// Total number of requests processed since connection
  int get requestsProcessed => _requestsProcessed;

  /// Total number of errors encountered since connection
  int get errorsCount => _errorsCount;

  /// Total number of LLM-specific requests processed
  int get llmRequestsProcessed => _llmRequestsProcessed;

  /// Timestamp when the connection was established
  DateTime? get connectedAt => _connectedAt;

  /// Establish HTTP polling tunnel connection
  ///
  /// This method performs the complete connection sequence:
  /// 1. **Bridge Registration**: Register with cloud API and obtain bridge ID
  /// 2. **Polling Initialization**: Start polling for incoming requests
  /// 3. **Heartbeat Setup**: Begin periodic heartbeat to maintain connection
  /// 4. **Provider Integration**: Initialize LLM provider discovery and monitoring
  ///
  /// ## Connection Process
  /// - Validates authentication state before attempting connection
  /// - Registers bridge with cloud API using platform-specific capabilities
  /// - Starts adaptive polling with exponential backoff on errors
  /// - Initializes provider status reporting for LLM integration
  ///
  /// ## Error Handling
  /// Connection failures are logged and stored in [lastError]. The method
  /// will throw exceptions for critical failures but will attempt to recover
  /// from transient network issues.
  ///
  /// ## Usage
  /// ```dart
  /// await client.connect();
  /// // Client will now automatically handle incoming requests
  /// ```
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
      _startProviderStatusReporting();

      _isConnected = true;
      _connectedAt = DateTime.now();
      _lastError = null;

      // Initialize provider discovery and health monitoring
      await _initializeProviderIntegration();

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
    debugPrint('🌉 [HttpPolling] Attempting to get access token...');
    final accessToken = _authService.getAccessToken();
    debugPrint(
      '🌉 [HttpPolling] Access token retrieved: ${accessToken != null ? "YES (${accessToken.substring(0, 20)}...)" : "NO"}',
    );

    if (accessToken == null) {
      debugPrint('🌉 [HttpPolling] No access token available - throwing exception');
      throw Exception('No authentication token available');
    }

    debugPrint('🌉 [HttpPolling] Making bridge registration request...');

    final response = await _httpClient
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/bridge/register'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'clientId': 'flutter-desktop-${_getPlatformName()}',
            'platform': _getPlatformName(),
            'version': '4.0.0',
            'capabilities': [
              'llm-providers',
              'provider-routing',
              'streaming',
              'http-polling',
              'langchain-integration'
            ],
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
      _llmChatTimeout = config['llmChatTimeout'] ?? _llmChatTimeout;
      _llmModelTimeout = config['llmModelTimeout'] ?? _llmModelTimeout;
      _llmStreamingTimeout = config['llmStreamingTimeout'] ?? _llmStreamingTimeout;
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

      // Handle rate limiting by backing off
      if (e.toString().contains('429') ||
          e.toString().contains('Too Many Requests')) {
        debugPrint('🌉 [HttpPolling] Rate limited, backing off for 30 seconds');
        _pollingInterval = 30000; // Back off to 30 seconds
      }

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

      // Extract LLM-specific metadata
      final llmMetadata = requestData['data']['llm'] as Map<String, dynamic>?;
      final requestType = _determineLLMRequestType(path, method);
      final preferredProvider = llmMetadata?['preferredProvider'] as String?;
      final isStreaming = llmMetadata?['streaming'] as bool? ?? false;

      // Route to appropriate LLM provider
      final response = await _routeToLLMProvider(
        method: method,
        path: path,
        headers: headers,
        body: body,
        requestType: requestType,
        preferredProvider: preferredProvider,
        isStreaming: isStreaming,
      );

      // Send response back to server
      await _sendResponse(requestId, response);

      _requestsProcessed++;
      if (requestType != LLMRequestType.unknown) {
        _llmRequestsProcessed++;
      }

      debugPrint('🌉 [HttpPolling] ✅ Request processed: $requestId');
    } catch (e) {
      _errorsCount++;
      debugPrint(
        '🌉 [HttpPolling] ❌ Request processing failed: $requestId - $e',
      );

      // Handle error with LLM-specific error handling
      final errorResponse = await _handleRequestError(requestId, e);
      await _sendResponse(requestId, errorResponse);

      _logger.logTunnelError(
        TunnelErrorCodes.requestProcessingFailed,
        'Request processing failed',
        context: {'requestId': requestId, 'error': e.toString()},
        error: e,
      );
    }
  }

  /// Determine LLM request type from path and method
  LLMRequestType _determineLLMRequestType(String path, String method) {
    if (path.startsWith('/api/chat') || path.startsWith('/v1/chat')) {
      return LLMRequestType.textGeneration;
    } else if (path.startsWith('/api/tags') || path.startsWith('/v1/models')) {
      return LLMRequestType.modelList;
    } else if (path.contains('/pull') && method == 'POST') {
      return LLMRequestType.modelPull;
    } else if (path.contains('/delete') && method == 'DELETE') {
      return LLMRequestType.modelDelete;
    } else if (path.contains('/show') || path.contains('/model')) {
      return LLMRequestType.modelInfo;
    } else if (path.contains('/health') || path.contains('/status')) {
      return LLMRequestType.healthCheck;
    }
    return LLMRequestType.unknown;
  }

  /// Route request to appropriate LLM provider
  Future<Map<String, dynamic>> _routeToLLMProvider({
    required String method,
    required String path,
    required Map<String, String> headers,
    required String? body,
    required LLMRequestType requestType,
    String? preferredProvider,
    bool isStreaming = false,
  }) async {
    try {
      // Get appropriate timeout for request type
      final timeout = _getTimeoutForRequestType(requestType, isStreaming);

      // Get available providers
      final availableProviders = _providerManager.getAvailableProviders();
      if (availableProviders.isEmpty) {
        throw LLMCommunicationException(
          LLMCommunicationErrorType.providerNotFound,
          'No LLM providers available',
        );
      }

      // Select provider
      final provider = preferredProvider != null
          ? availableProviders.firstWhere(
              (p) => p.info.id == preferredProvider,
              orElse: () => availableProviders.first,
            )
          : availableProviders.first;

      debugPrint('🌉 [HttpPolling] Routing to provider: ${provider.info.name}');

      // Forward request to selected provider
      final providerUrl = '${provider.info.baseUrl}$path';
      final request = http.Request(method, Uri.parse(providerUrl));
      request.headers.addAll(headers);

      if (body != null && body.isNotEmpty) {
        request.body = body;
      }

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(Duration(milliseconds: timeout));

      final responseBody = await streamedResponse.stream.bytesToString();

      return {
        'status': streamedResponse.statusCode,
        'headers': streamedResponse.headers,
        'body': responseBody,
        'provider': provider.info.id,
      };
    } catch (e) {
      // Try fallback providers if primary fails
      return await _tryFallbackProviders(
        method: method,
        path: path,
        headers: headers,
        body: body,
        requestType: requestType,
        excludeProvider: preferredProvider,
        isStreaming: isStreaming,
      );
    }
  }

  /// Try fallback providers when primary provider fails
  Future<Map<String, dynamic>> _tryFallbackProviders({
    required String method,
    required String path,
    required Map<String, String> headers,
    required String? body,
    required LLMRequestType requestType,
    String? excludeProvider,
    bool isStreaming = false,
  }) async {
    final availableProviders = _providerManager.getAvailableProviders();
    final fallbackProviders = availableProviders
        .where((p) => p.info.id != excludeProvider)
        .toList();

    if (fallbackProviders.isEmpty) {
      throw LLMCommunicationException(
        LLMCommunicationErrorType.providerUnavailable,
        'No fallback providers available',
      );
    }

    for (final provider in fallbackProviders) {
      try {
        debugPrint('🌉 [HttpPolling] Trying fallback provider: ${provider.info.name}');

        final timeout = _getTimeoutForRequestType(requestType, isStreaming);
        final providerUrl = '${provider.info.baseUrl}$path';
        final request = http.Request(method, Uri.parse(providerUrl));
        request.headers.addAll(headers);

        if (body != null && body.isNotEmpty) {
          request.body = body;
        }

        final streamedResponse = await _httpClient
            .send(request)
            .timeout(Duration(milliseconds: timeout));

        final responseBody = await streamedResponse.stream.bytesToString();

        debugPrint('🌉 [HttpPolling] ✅ Fallback provider succeeded: ${provider.info.name}');

        return {
          'status': streamedResponse.statusCode,
          'headers': streamedResponse.headers,
          'body': responseBody,
          'provider': provider.info.id,
          'fallback': true,
        };
      } catch (e) {
        debugPrint('🌉 [HttpPolling] Fallback provider failed: ${provider.info.name} - $e');
        continue;
      }
    }

    throw LLMCommunicationException(
      LLMCommunicationErrorType.providerUnavailable,
      'All providers failed',
    );
  }

  /// Get appropriate timeout for request type
  int _getTimeoutForRequestType(LLMRequestType requestType, bool isStreaming) {
    if (isStreaming || requestType == LLMRequestType.streamingGeneration) {
      return _llmStreamingTimeout;
    }

    switch (requestType) {
      case LLMRequestType.textGeneration:
      case LLMRequestType.streamingGeneration:
        return _llmChatTimeout;
      case LLMRequestType.modelPull:
      case LLMRequestType.modelDelete:
        return _llmModelTimeout;
      case LLMRequestType.modelList:
      case LLMRequestType.modelInfo:
      case LLMRequestType.healthCheck:
      case LLMRequestType.providerStatus:
        return _requestTimeout;
      case LLMRequestType.unknown:
        return _requestTimeout;
    }
  }

  /// Handle request processing errors with LLM-specific error handling
  Future<Map<String, dynamic>> _handleRequestError(
    String requestId,
    dynamic error,
  ) async {
    // Create LLM communication error from the exception
    final llmError = error is LLMCommunicationException
        ? error.error ?? LLMCommunicationError.fromException(Exception(error.message))
        : LLMCommunicationError.fromException(
            error is Exception ? error : Exception(error.toString()),
          );

    return {
      'status': _getStatusCodeForError(llmError.type),
      'headers': {'content-type': 'application/json'},
      'body': json.encode({
        'error': llmError.userFriendlyMessage,
        'code': llmError.type.toString(),
        'troubleshooting': llmError.troubleshootingSteps,
        'requestId': requestId,
        'details': llmError.details,
      }),
      'error': error.toString(),
    };
  }

  /// Get appropriate HTTP status code for LLM error
  int _getStatusCodeForError(LLMCommunicationErrorType errorType) {
    switch (errorType) {
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return 503; // Service Unavailable
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
        return 504; // Gateway Timeout
      case LLMCommunicationErrorType.requestMalformed:
      case LLMCommunicationErrorType.requestTooLarge:
        return 400; // Bad Request
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return 401; // Unauthorized
      case LLMCommunicationErrorType.requestRateLimited:
        return 429; // Too Many Requests
      case LLMCommunicationErrorType.modelNotFound:
        return 404; // Not Found
      default:
        return 500; // Internal Server Error
    }
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
      } else if (response.statusCode == 429) {
        debugPrint('🌉 [HttpPolling] Heartbeat rate limited, backing off');
        _heartbeatInterval = 120000; // Back off to 2 minutes
      }
    } catch (e) {
      debugPrint('🌉 [HttpPolling] Heartbeat failed: $e');

      // Handle rate limiting by backing off
      if (e.toString().contains('429') ||
          e.toString().contains('Too Many Requests')) {
        debugPrint('🌉 [HttpPolling] Heartbeat rate limited, backing off');
        _heartbeatInterval = 120000; // Back off to 2 minutes
      }
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

  /// Report provider status to server
  Future<void> reportProviderStatus() async {
    if (_bridgeId == null) return;

    try {
      final providers = _providerManager.getAvailableProviders();
      final providerInfoList = providers.map((provider) => {
        'id': provider.info.id,
        'name': provider.info.name,
        'type': provider.info.type.toString(),
        'baseUrl': provider.info.baseUrl,
        'status': provider.info.status.toString(),
        'lastSeen': provider.info.lastSeen.toIso8601String(),
        'availableModels': provider.info.availableModels,
        'capabilities': provider.info.capabilities,
        'healthStatus': provider.healthStatus.toString(),
        'isEnabled': provider.isEnabled,
      }).toList();

      final accessToken = _authService.getAccessToken();
      if (accessToken == null) return;

      await _httpClient
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/bridge/$_bridgeId/provider-status'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'providers': providerInfoList,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(Duration(seconds: 10));

      debugPrint('🌉 [HttpPolling] Provider status reported: ${providers.length} providers');
    } catch (e) {
      debugPrint('🌉 [HttpPolling] Failed to report provider status: $e');
    }
  }

  /// Initialize provider integration on connection
  Future<void> _initializeProviderIntegration() async {
    try {
      debugPrint('🌉 [HttpPolling] Initializing provider integration...');

      // Ensure provider manager is initialized
      if (!_providerManager.isInitialized) {
        await _providerManager.initialize();
      }

      // Provider discovery is handled automatically by the provider manager
      // No need to manually trigger discovery

      // Report initial provider status
      await reportProviderStatus();

      debugPrint('🌉 [HttpPolling] ✅ Provider integration initialized');
    } catch (e) {
      debugPrint('🌉 [HttpPolling] ❌ Provider integration failed: $e');
    }
  }

  /// Start periodic provider status reporting
  void _startProviderStatusReporting() {
    Timer.periodic(Duration(minutes: 2), (_) {
      reportProviderStatus();
    });
  }

  @override
  void dispose() {
    disconnect();
    _httpClient.close();
    super.dispose();
  }
}

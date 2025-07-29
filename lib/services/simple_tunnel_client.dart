/// Simple tunnel client for desktop platform
///
/// Replaces the complex EncryptedTunnelClient with a streamlined implementation
/// using a single WebSocket connection and standard HTTP proxy patterns.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/tunnel_message.dart';
import '../services/tunnel_message_protocol.dart';
import '../utils/tunnel_logger.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Queued message for efficient message processing
class _QueuedMessage {
  final TunnelMessage message;
  final DateTime queuedAt;
  // Completer is used in some implementations but not all
  final Completer<void>? completer;
  final int priority;

  _QueuedMessage({
    required this.message,
    required this.queuedAt,
    // ignore: unused_element_parameter
    this.completer,
    this.priority = 0,
  });
}

/// Configuration class for tunnel client (for compatibility)
class TunnelConfig {
  final String cloudProxyUrl;
  final String localOllamaUrl;
  final bool enableCloudProxy;
  final int connectionTimeout;
  final int healthCheckInterval;

  const TunnelConfig({
    required this.cloudProxyUrl,
    required this.localOllamaUrl,
    this.enableCloudProxy = true,
    this.connectionTimeout = 10,
    this.healthCheckInterval = 30,
  });

  /// Create default configuration
  factory TunnelConfig.defaultConfig() {
    return TunnelConfig(
      cloudProxyUrl: AppConfig.tunnelWebSocketUrl,
      localOllamaUrl: 'http://localhost:11434',
      enableCloudProxy: true,
      connectionTimeout: 10,
      healthCheckInterval: 30,
    );
  }
}

/// Simple tunnel client for desktop platformo-cloud communication
///
/// Features:
/// - Single WebSocket connection with JWT authentication
/// - Automatic reconnection with exponential backoff
/// - HTTP request forwarding to localhost:11434
/// - Ping/pong health check mechanism
/// - Structured error handling and logging
class SimpleTunnelClient extends ChangeNotifier {
  final AuthService _authService;
  final http.Client _httpClient = http.Client();
  final TunnelLogger _logger = TunnelLogger('SimpleTunnelClient');
  final TunnelMetrics _metrics = TunnelMetrics();

  // WebSocket connection
  WebSocketChannel? _webSocket;
  StreamSubscription? _webSocketSubscription;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _lastError;
  String? _correlationId;
  String? _userId;

  // Reconnection logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const List<int> _reconnectDelays = [1, 2, 4, 8, 16, 30]; // seconds

  // Health monitoring
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  String? _lastPingId;

  // Request handling with enhanced queuing
  final Map<String, Completer<HttpResponse>> _pendingRequests = {};
  final List<_QueuedMessage> _messageQueue = [];
  // Keeping this for future metrics implementation
  // ignore: unused_field
  final Map<String, DateTime> _requestStartTimes = {};
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _maxQueueSize = 1000;

  // Connection pooling
  final List<WebSocketChannel> _connectionPool = [];
  static const int _maxPoolSize = 5;
  bool _isProcessingQueue = false;

  // Disposal tracking
  bool _isDisposed = false;

  // UI update debouncing
  Timer? _notifyTimer;
  static const Duration _notifyDebounceDelay = Duration(milliseconds: 500);

  // Configuration
  static const String _localOllamaUrl = 'http://localhost:11434';
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _pongTimeout = Duration(seconds: 10);

  SimpleTunnelClient({required AuthService authService})
    : _authService = authService {
    _correlationId = _logger.generateCorrelationId();
    _userId = _authService.currentUser?.id;

    // Listen for authentication state changes
    _authService.addListener(_onAuthenticationChanged);
  }

  /// Debounced notify listeners to prevent excessive UI updates
  void _debouncedNotifyListeners() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(_notifyDebounceDelay, () {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  /// Whether the tunnel is connected
  bool get isConnected => _isConnected;

  /// Whether the tunnel is connecting
  bool get isConnecting => _isConnecting;

  /// Last error message
  String? get lastError => _lastError;

  /// Current reconnection attempt count
  int get reconnectAttempts => _reconnectAttempts;

  /// Last error (for compatibility with TunnelManagerService interface)
  String? get error => _lastError;

  /// Connection status (for compatibility with TunnelManagerService interface)
  Map<String, dynamic> get connectionStatus => {
    'connected': _isConnected,
    'connecting': _isConnecting,
    'error': _lastError,
    'reconnectAttempts': _reconnectAttempts,
    'lastPing': _lastPingId,
  };

  /// Configuration (for compatibility with TunnelManagerService interface)
  TunnelConfig get config => TunnelConfig(
    cloudProxyUrl: AppConfig.apiBaseUrl,
    localOllamaUrl: _localOllamaUrl,
  );

  /// Initialize the tunnel client (for compatibility with TunnelManagerService interface)
  Future<void> initialize() async {
    if (!kIsWeb) {
      // Only attempt to connect if user is authenticated
      if (_shouldAttemptConnection()) {
        _logger.debug(
          'User is authenticated, attempting to connect',
          correlationId: _correlationId,
          userId: _userId,
        );
        await connect();
      } else {
        _logger.debug(
          'User not authenticated, waiting for authentication',
          correlationId: _correlationId,
          userId: _userId,
        );
      }
    }
  }

  /// Reconnect the tunnel (for compatibility with TunnelManagerService interface)
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  /// Retry connection with token refresh
  /// Useful when connection fails due to authentication issues
  Future<void> retryWithTokenRefresh() async {
    _logger.debug(
      'Retrying connection with token refresh',
      correlationId: _correlationId,
      userId: _userId,
    );

    await disconnect();
    await connect(forceTokenRefresh: true);
  }

  /// Connect to the tunnel WebSocket
  Future<void> connect({bool forceTokenRefresh = false}) async {
    if (_isConnecting || _isConnected) {
      _logger.debug(
        'Already connecting or connected',
        correlationId: _correlationId,
        userId: _userId,
      );
      return;
    }

    final startTime = DateTime.now();

    try {
      _isConnecting = true;
      _lastError = null;
      notifyListeners();

      _logger.logConnection(
        'connecting',
        null,
        correlationId: _correlationId,
        userId: _userId,
        context: {'attempt': _reconnectAttempts + 1},
      );

      // Get and validate authentication token
      final accessToken = await _authService.getValidatedAccessToken(
        forceRefresh: forceTokenRefresh,
      );
      if (accessToken == null) {
        // Provide more specific error message based on authentication state
        final isAuthenticated = _authService.isAuthenticated.value;
        final hasToken = _authService.getAccessToken() != null;

        String errorMessage;
        if (!isAuthenticated) {
          errorMessage =
              'User not authenticated. Please log in to establish tunnel connection.';
        } else if (!hasToken) {
          errorMessage =
              'Authentication token not available. Please try logging out and back in.';
        } else {
          errorMessage =
              'Authentication token expired. Please refresh your session.';
        }

        _lastError = errorMessage;
        _isConnecting = false;

        _logger.logTunnelError(
          TunnelErrorCodes.authTokenMissing,
          'Authentication token validation failed',
          correlationId: _correlationId,
          userId: _userId,
          context: {
            'isAuthenticated': isAuthenticated,
            'hasToken': hasToken,
            'reason': errorMessage,
          },
        );

        _debouncedNotifyListeners();
        return; // Return gracefully instead of throwing
      }

      // Build WebSocket URL
      final wsUrl = kDebugMode
          ? AppConfig.tunnelWebSocketUrlDev
          : AppConfig.tunnelWebSocketUrl;

      // Build URI with token parameter - avoid using replace() which can add :0 port
      final uri = Uri.parse('$wsUrl?token=${Uri.encodeComponent(accessToken)}');

      // Extract user ID from current user for session tracking
      _userId = _authService.currentUser?.id;
      _correlationId = _generateCorrelationId();

      _logger.debug(
        'Connecting to WebSocket',
        correlationId: _correlationId,
        userId: _userId,
        context: {'url': wsUrl},
      );

      // Connect to WebSocket
      _webSocket = WebSocketChannel.connect(uri);

      // Set up message handling with enhanced error handling
      _webSocketSubscription = _webSocket!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );

      // Wait for connection to be established
      await _waitForConnection();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      // Start health monitoring
      _startHealthMonitoring();

      // Process any queued messages
      _processMessageQueue();

      // Update connection metrics
      _metrics.updateActiveConnections(1);
      _updateMemoryUsage();

      final connectionTime = DateTime.now().difference(startTime);
      _logger.logConnection(
        'connected',
        null,
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'connectionTime': connectionTime.inMilliseconds,
          'totalAttempts': _reconnectAttempts + 1,
          'queuedMessages': _messageQueue.length,
        },
      );

      notifyListeners();
    } catch (e, stackTrace) {
      final connectionTime = DateTime.now().difference(startTime);
      _lastError = 'Connection failed: $e';
      _isConnecting = false;

      _logger.logTunnelError(
        e is TunnelException ? e.code : TunnelErrorCodes.connectionFailed,
        'Failed to connect to tunnel WebSocket',
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'connectionTime': connectionTime.inMilliseconds,
          'attempt': _reconnectAttempts + 1,
          'wsUrl': AppConfig.apiBaseUrl,
        },
        error: e,
        stackTrace: stackTrace,
      );

      _debouncedNotifyListeners();

      // Schedule reconnection
      _scheduleReconnection();
      rethrow;
    }
  }

  /// Wait for connection to be established (simple timeout-based approach)
  Future<void> _waitForConnection() async {
    // Simple approach: wait a short time for the connection to establish
    // In a real implementation, you might wait for a specific handshake message
    await Future.delayed(const Duration(milliseconds: 500));

    if (_webSocket?.closeCode != null) {
      throw Exception('WebSocket connection failed');
    }
  }

  /// Disconnect from the tunnel
  Future<void> disconnect() async {
    debugPrint('🚇 [SimpleTunnel] Disconnecting...');

    _stopHealthMonitoring();
    _reconnectTimer?.cancel();
    _webSocketSubscription?.cancel();
    await _webSocket?.sink.close();

    _webSocket = null;
    _webSocketSubscription = null;
    _isConnected = false;
    _isConnecting = false;

    // Complete pending requests with error
    _completePendingRequestsWithError('Tunnel disconnected');

    debugPrint('🚇 [SimpleTunnel] Disconnected');

    // Only notify listeners if not disposed
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Handle incoming WebSocket messages
  // ignore: unused_element
  void _handleWebSocketMessage(dynamic data) {
    try {
      if (data == null || data.toString().isEmpty) {
        _logger.logTunnelError(
          TunnelErrorCodes.invalidMessageFormat,
          'Received empty or null message',
          correlationId: _correlationId,
          userId: _userId,
        );
        return;
      }

      _logger.debug(
        'Message received',
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'messageLength': data.toString().length,
          'messagePreview': data.toString().substring(
            0,
            min(100, data.toString().length),
          ),
        },
      );

      final message = TunnelMessageProtocol.deserialize(data);

      switch (message.type) {
        case TunnelMessageTypes.httpRequest:
          _handleHttpRequest(message as TunnelRequestMessage);
          break;
        case TunnelMessageTypes.httpResponse:
          _handleHttpResponse(message as TunnelResponseMessage);
          break;
        case TunnelMessageTypes.ping:
          _handlePing(message as PingMessage);
          break;
        case TunnelMessageTypes.pong:
          _handlePong(message as PongMessage);
          break;
        case TunnelMessageTypes.error:
          _handleError(message as ErrorMessage);
          break;
        default:
          _logger.logTunnelError(
            TunnelErrorCodes.invalidMessageFormat,
            'Unknown message type received',
            correlationId: _correlationId,
            userId: _userId,
            context: {'messageType': message.type, 'messageId': message.id},
          );
      }
    } catch (e, stackTrace) {
      _logger.logTunnelError(
        TunnelErrorCodes.messageDeserializationFailed,
        'Failed to parse WebSocket message',
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'dataLength': data?.toString().length ?? 0,
          'dataType': data.runtimeType.toString(),
        },
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle HTTP request from cloud
  Future<void> _handleHttpRequest(TunnelRequestMessage request) async {
    final startTime = DateTime.now();

    try {
      _logger.logRequest(
        'started',
        request.id,
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'method': request.method,
          'path': request.path,
          'hasBody': request.body?.isNotEmpty ?? false,
        },
      );

      // Forward request to local Ollama
      final httpRequest = request.toHttpRequest();
      final httpResponse = await _forwardToLocalOllama(httpRequest);

      // Send response back through tunnel
      final responseMessage = TunnelResponseMessage.fromHttpResponse(
        request.id,
        httpResponse,
      );
      await _sendMessage(responseMessage);

      final responseTime = DateTime.now().difference(startTime);
      _metrics.recordSuccess(responseTime);

      _logger.logRequest(
        'completed',
        request.id,
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'method': request.method,
          'path': request.path,
          'statusCode': httpResponse.status,
          'responseTime': responseTime.inMilliseconds,
        },
      );
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime);
      _metrics.recordFailure();

      _logger.logRequest(
        'failed',
        request.id,
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'method': request.method,
          'path': request.path,
          'responseTime': responseTime.inMilliseconds,
          'error': e.toString(),
        },
      );

      // Send error response
      final errorResponse = TunnelResponseMessage(
        id: request.id,
        status: 500,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'error': 'Internal server error',
          'message': e.toString(),
          'code': TunnelErrorCodes.requestFailed,
        }),
      );

      try {
        await _sendMessage(errorResponse);
      } catch (sendError) {
        _logger.logTunnelError(
          TunnelErrorCodes.messageSerializationFailed,
          'Failed to send error response',
          correlationId: _correlationId,
          userId: _userId,
          context: {
            'originalError': e.toString(),
            'sendError': sendError.toString(),
            'requestId': request.id,
          },
          error: sendError,
        );
      }
    }
  }

  /// Handle HTTP response (for client-initiated requests)
  // ignore: unused_element
  void _handleHttpResponse(TunnelResponseMessage response) {
    final completer = _pendingRequests.remove(response.id);
    if (completer != null && !completer.isCompleted) {
      final httpResponse = response.toHttpResponse();
      completer.complete(httpResponse);
      debugPrint('🚇 [SimpleTunnel] HTTP response completed: ${response.id}');
    } else {
      debugPrint(
        '🚇 [SimpleTunnel] Received response for unknown request: ${response.id}',
      );
    }
  }

  /// Handle ping message
  Future<void> _handlePing(PingMessage ping) async {
    try {
      final pong = PongMessage.fromPing(ping);
      await _sendMessage(pong);
      debugPrint('🚇 [SimpleTunnel] Pong sent for ping: ${ping.id}');
    } catch (e) {
      debugPrint('🚇 [SimpleTunnel] Error sending pong: $e');
    }
  }

  /// Handle pong message
  void _handlePong(PongMessage pong) {
    if (pong.id == _lastPingId) {
      _pongTimeoutTimer?.cancel();
      debugPrint('🚇 [SimpleTunnel] Pong received: ${pong.id}');
    } else {
      debugPrint('🚇 [SimpleTunnel] Received unexpected pong: ${pong.id}');
    }
  }

  /// Handle error message
  void _handleError(ErrorMessage error) {
    _lastError = error.error;
    debugPrint('🚇 [SimpleTunnel] Error received: ${error.error}');
    notifyListeners();
  }

  /// Forward HTTP request to local Ollama
  Future<HttpResponse> _forwardToLocalOllama(HttpRequest request) async {
    final url = '$_localOllamaUrl${request.path}';
    final uri = Uri.parse(url);

    debugPrint(
      '🚇 [SimpleTunnel] Forwarding to Ollama: ${request.method} $url',
    );

    late http.Response response;

    try {
      switch (request.method.toUpperCase()) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: request.headers)
              .timeout(_requestTimeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: request.headers, body: request.body)
              .timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await _httpClient
              .put(uri, headers: request.headers, body: request.body)
              .timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: request.headers)
              .timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await _httpClient
              .patch(uri, headers: request.headers, body: request.body)
              .timeout(_requestTimeout);
          break;
        case 'HEAD':
          response = await _httpClient
              .head(uri, headers: request.headers)
              .timeout(_requestTimeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: ${request.method}');
      }

      return HttpResponse(
        status: response.statusCode,
        headers: response.headers.map((key, value) => MapEntry(key, value)),
        body: response.body,
      );
    } catch (e) {
      debugPrint('🚇 [SimpleTunnel] Ollama request failed: $e');

      // Return appropriate error response
      if (e is TimeoutException) {
        return HttpResponse(
          status: 504,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'error': 'Gateway timeout',
            'message': 'Request to local Ollama timed out',
          }),
        );
      } else if (e is SocketException) {
        return HttpResponse(
          status: 503,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'error': 'Service unavailable',
            'message': 'Local Ollama is not accessible',
          }),
        );
      } else {
        return HttpResponse(
          status: 500,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'error': 'Internal server error',
            'message': e.toString(),
          }),
        );
      }
    }
  }

  /// Send message through WebSocket with queuing and connection pooling
  Future<void> _sendMessage(TunnelMessage message, {int priority = 0}) async {
    if (_webSocket == null || !_isConnected) {
      // Queue message if not connected
      if (_messageQueue.length < _maxQueueSize) {
        final queuedMessage = _QueuedMessage(
          message: message,
          queuedAt: DateTime.now(),
          priority: priority,
        );
        _messageQueue.add(queuedMessage);
        _messageQueue.sort((a, b) => b.priority.compareTo(a.priority));

        _logger.debug(
          'Message queued',
          correlationId: _correlationId,
          userId: _userId,
          context: {
            'messageType': message.type,
            'messageId': message.id,
            'queueSize': _messageQueue.length,
            'priority': priority,
          },
        );

        // Update queue metrics
        _updateQueueMetrics();
        return;
      } else {
        throw Exception('Message queue full - cannot queue message');
      }
    }

    try {
      final serialized = TunnelMessageProtocol.serialize(message);
      _webSocket!.sink.add(serialized);

      _logger.debug(
        'Message sent',
        correlationId: _correlationId,
        userId: _userId,
        context: {'messageType': message.type, 'messageId': message.id},
      );
    } catch (e) {
      _logger.logTunnelError(
        TunnelErrorCodes.messageSerializationFailed,
        'Failed to send message',
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'messageType': message.type,
          'messageId': message.id,
          'error': e.toString(),
        },
        error: e,
      );
      rethrow;
    }
  }

  /// Process queued messages when connection is restored
  Future<void> _processMessageQueue() async {
    if (_isProcessingQueue || !_isConnected || _messageQueue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    try {
      final startTime = DateTime.now();
      final messagesToProcess = List<_QueuedMessage>.from(_messageQueue);
      _messageQueue.clear();

      _logger.debug(
        'Processing message queue',
        correlationId: _correlationId,
        userId: _userId,
        context: {'queueSize': messagesToProcess.length},
      );

      for (final queuedMessage in messagesToProcess) {
        if (!_isConnected) {
          // Re-queue remaining messages if connection lost
          _messageQueue.addAll(
            messagesToProcess.skip(messagesToProcess.indexOf(queuedMessage)),
          );
          break;
        }

        try {
          final serialized = TunnelMessageProtocol.serialize(
            queuedMessage.message,
          );
          _webSocket!.sink.add(serialized);

          // Small delay to prevent overwhelming the connection
          await Future.delayed(const Duration(milliseconds: 10));
        } catch (e) {
          _logger.logTunnelError(
            TunnelErrorCodes.messageSerializationFailed,
            'Failed to send queued message',
            correlationId: _correlationId,
            userId: _userId,
            context: {
              'messageType': queuedMessage.message.type,
              'messageId': queuedMessage.message.id,
              'queuedAt': queuedMessage.queuedAt.toIso8601String(),
              'error': e.toString(),
            },
            error: e,
          );
        }
      }

      final processingTime = DateTime.now().difference(startTime);
      _logger.debug(
        'Message queue processed',
        correlationId: _correlationId,
        userId: _userId,
        context: {
          'processedCount': messagesToProcess.length,
          'processingTime': processingTime.inMilliseconds,
          'remainingInQueue': _messageQueue.length,
        },
      );

      _updateQueueMetrics();
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Update queue metrics for monitoring
  void _updateQueueMetrics() {
    final queuedCount = _messageQueue.length;
    final averageQueueTime = _calculateAverageQueueTime();
    _metrics.updateQueueMetrics(queuedCount, averageQueueTime);
  }

  /// Calculate average time messages spend in queue
  Duration _calculateAverageQueueTime() {
    if (_messageQueue.isEmpty) return Duration.zero;

    final now = DateTime.now();
    final totalQueueTime = _messageQueue
        .map((msg) => now.difference(msg.queuedAt))
        .reduce(
          (a, b) => Duration(milliseconds: a.inMilliseconds + b.inMilliseconds),
        );

    return Duration(
      milliseconds: totalQueueTime.inMilliseconds ~/ _messageQueue.length,
    );
  }

  /// Get connection from pool or create new one
  // ignore: unused_element
  Future<WebSocketChannel?> _getPooledConnection() async {
    // Try to reuse existing connection from pool
    for (int i = _connectionPool.length - 1; i >= 0; i--) {
      final connection = _connectionPool[i];
      if (connection.closeCode == null) {
        _connectionPool.removeAt(i);
        _metrics.recordPoolHit();
        return connection;
      } else {
        // Remove dead connection from pool
        _connectionPool.removeAt(i);
      }
    }

    _metrics.recordPoolMiss();
    return null;
  }

  /// Return connection to pool for reuse
  // ignore: unused_element
  void _returnConnectionToPool(WebSocketChannel connection) {
    if (_connectionPool.length < _maxPoolSize && connection.closeCode == null) {
      _connectionPool.add(connection);
      _metrics.updatePooledConnections(_connectionPool.length);
    } else {
      // Pool is full or connection is dead, close it
      connection.sink.close();
    }
  }

  /// Start health monitoring with ping/pong
  void _startHealthMonitoring() {
    _pingTimer = Timer.periodic(_pingInterval, (_) => _sendPing());
  }

  /// Stop health monitoring
  void _stopHealthMonitoring() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer = null;
    _lastPingId = null;
  }

  /// Send ping message
  Future<void> _sendPing() async {
    if (!_isConnected) return;

    try {
      final ping = PingMessage.create();
      _lastPingId = ping.id;

      await _sendMessage(ping);

      // Set timeout for pong response
      _pongTimeoutTimer = Timer(_pongTimeout, () {
        debugPrint('🚇 [SimpleTunnel] Pong timeout - connection may be dead');
        _handleConnectionLoss('Ping timeout');
      });

      debugPrint('🚇 [SimpleTunnel] Ping sent: ${ping.id}');
    } catch (e) {
      debugPrint('🚇 [SimpleTunnel] Failed to send ping: $e');
      _handleConnectionLoss('Ping failed: $e');
    }
  }

  /// Handle WebSocket error
  // ignore: unused_element
  void _handleWebSocketError(Object error, [StackTrace? _]) {
    _lastError = 'WebSocket error: $error';

    _logger.logTunnelError(
      TunnelErrorCodes.websocketError,
      'WebSocket connection error',
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'errorType': error.runtimeType.toString(),
        'isConnected': _isConnected,
        'isConnecting': _isConnecting,
      },
      error: error,
    );

    _handleConnectionLoss('WebSocket error: $error');
  }

  /// Handle WebSocket closed
  // ignore: unused_element
  void _handleWebSocketClosed() {
    _logger.logConnection(
      'closed',
      null,
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'wasConnected': _isConnected,
        'pendingRequests': _pendingRequests.length,
      },
    );

    _handleConnectionLoss('Connection closed');
  }

  /// Handle connection loss and trigger reconnection
  // ignore: unused_element
  void _handleConnectionLoss(String reason) {
    if (!_isConnected && !_isConnecting) {
      return; // Already handling disconnection
    }

    _logger.logTunnelError(
      TunnelErrorCodes.connectionLost,
      'Connection lost',
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'reason': reason,
        'wasConnected': _isConnected,
        'wasConnecting': _isConnecting,
        'pendingRequests': _pendingRequests.length,
        'reconnectAttempts': _reconnectAttempts,
      },
    );

    _isConnected = false;
    _isConnecting = false;
    _lastError = reason;

    _stopHealthMonitoring();
    _completePendingRequestsWithError('Connection lost: $reason');

    _debouncedNotifyListeners();

    // Schedule reconnection
    _scheduleReconnection();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnection() {
    if (_reconnectTimer != null) {
      return; // Already scheduled
    }

    final delayIndex = min(_reconnectAttempts, _reconnectDelays.length - 1);
    final delay = _reconnectDelays[delayIndex];

    _logger.logConnection(
      'reconnection_scheduled',
      null,
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'delay': delay,
        'attempt': _reconnectAttempts + 1,
        'maxAttempts': _reconnectDelays.length,
      },
    );

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectTimer = null;
      _reconnectAttempts++;
      _metrics.recordReconnection();

      connect().catchError((e, stackTrace) {
        _logger.logTunnelError(
          TunnelErrorCodes.reconnectionFailed,
          'Reconnection attempt failed',
          correlationId: _correlationId,
          userId: _userId,
          context: {'attempt': _reconnectAttempts, 'delay': delay},
          error: e,
          stackTrace: stackTrace,
        );
      });
    });
  }

  /// Complete all pending requests with error
  void _completePendingRequestsWithError(String error) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(error));
      }
    }
    _pendingRequests.clear();
  }

  /// Update memory usage metrics (approximation based on active objects)
  void _updateMemoryUsage() {
    // Approximate memory usage calculation
    int memoryBytes = 0;

    // Base client overhead
    memoryBytes += 1024 * 1024; // 1MB base

    // Pending requests
    memoryBytes += _pendingRequests.length * 1024; // ~1KB per request

    // Message queue
    memoryBytes += _messageQueue.length * 512; // ~512B per queued message

    // Connection pool
    memoryBytes += _connectionPool.length * 2048; // ~2KB per pooled connection

    _metrics.updateMemoryUsage(memoryBytes);
  }

  /// Get comprehensive performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    _updateMemoryUsage();
    return _metrics.toMap();
  }

  /// Get connection health status
  Map<String, dynamic> getHealthStatus() {
    return {
      'connected': _isConnected,
      'connecting': _isConnecting,
      'lastError': _lastError,
      'reconnectAttempts': _reconnectAttempts,
      'queueSize': _messageQueue.length,
      'pendingRequests': _pendingRequests.length,
      'pooledConnections': _connectionPool.length,
      'metrics': getPerformanceMetrics(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if performance is degraded
  bool get isPerformanceDegraded {
    final metrics = _metrics.toMap();
    return metrics['successRate'] < 80.0 ||
        metrics['timeoutRate'] > 20.0 ||
        metrics['recentAverageResponseTime'] > 5000 ||
        _messageQueue.length > 100;
  }

  /// Get performance alerts
  List<String> getPerformanceAlerts() {
    final alerts = <String>[];
    final metrics = _metrics.toMap();

    if (metrics['successRate'] < 80.0) {
      alerts.add('Low success rate: ${metrics['successRate']}%');
    }

    if (metrics['timeoutRate'] > 20.0) {
      alerts.add('High timeout rate: ${metrics['timeoutRate']}%');
    }

    if (metrics['recentAverageResponseTime'] > 5000) {
      alerts.add(
        'High response time: ${metrics['recentAverageResponseTime']}ms',
      );
    }

    if (_messageQueue.length > 100) {
      alerts.add('Large message queue: ${_messageQueue.length} messages');
    }

    if (metrics['memoryUsageMB'] > 50) {
      alerts.add('High memory usage: ${metrics['memoryUsageMB']}MB');
    }

    if (_reconnectAttempts > 5) {
      alerts.add('Frequent reconnections: $_reconnectAttempts attempts');
    }

    return alerts;
  }

  /// Check if we should attempt to connect based on authentication state
  bool _shouldAttemptConnection() {
    final isAuthenticated = _authService.isAuthenticated.value;
    final hasAccessToken = _authService.getAccessToken() != null;

    _logger.debug(
      'Checking connection requirements',
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'isAuthenticated': isAuthenticated,
        'hasAccessToken': hasAccessToken,
      },
    );

    return isAuthenticated && hasAccessToken;
  }

  /// Handle authentication state changes
  void _onAuthenticationChanged() {
    final wasAuthenticated = _userId != null;
    final isNowAuthenticated = _authService.isAuthenticated.value;
    final accessToken = _authService.getAccessToken();
    _userId = _authService.currentUser?.id;

    _logger.debug(
      'Authentication state changed',
      correlationId: _correlationId,
      userId: _userId,
      context: {
        'wasAuthenticated': wasAuthenticated,
        'isNowAuthenticated': isNowAuthenticated,
        'hasAccessToken': accessToken != null,
        'tokenLength': accessToken?.length ?? 0,
        'platformServiceType': _authService.runtimeType.toString(),
      },
    );

    if (isNowAuthenticated && !_isConnected && !_isConnecting) {
      // User just authenticated and we're not connected - attempt to connect
      _logger.debug(
        'User authenticated, attempting to connect tunnel',
        correlationId: _correlationId,
        userId: _userId,
      );

      if (!kIsWeb) {
        connect().catchError((e) {
          _logger.logTunnelError(
            TunnelErrorCodes.connectionFailed,
            'Failed to connect after authentication',
            correlationId: _correlationId,
            userId: _userId,
            error: e,
          );
        });
      }
    } else if (!isNowAuthenticated && (_isConnected || _isConnecting)) {
      // User logged out - disconnect
      _logger.debug(
        'User logged out, disconnecting tunnel',
        correlationId: _correlationId,
        userId: _userId,
      );
      disconnect();
    }
  }

  /// Generate a unique correlation ID for tracking requests
  String _generateCorrelationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'tunnel_${timestamp}_$random';
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Remove authentication listener
    _authService.removeListener(_onAuthenticationChanged);

    // Cancel timers
    _notifyTimer?.cancel();

    // Clean up connection pool
    for (final connection in _connectionPool) {
      connection.sink.close();
    }
    _connectionPool.clear();

    // Clear message queue
    _messageQueue.clear();

    disconnect();
    _httpClient.close();
    super.dispose();
  }
}

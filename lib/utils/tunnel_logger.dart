/// Enhanced logging utility for Flutter tunnel client with structured logging
/// Provides consistent logging across the simplified tunnel system
library;

import 'dart:developer' as developer;
import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Log levels for different types of events
enum LogLevel { debug, info, warn, error }

/// Error codes for different types of tunnel errors
class TunnelErrorCodes {
  // Connection errors
  static const String connectionFailed = 'CONNECTION_FAILED';
  static const String connectionLost = 'CONNECTION_LOST';
  static const String reconnectionFailed = 'RECONNECTION_FAILED';
  static const String websocketError = 'WEBSOCKET_ERROR';

  // Authentication errors
  static const String authTokenMissing = 'AUTH_TOKEN_MISSING';
  static const String authTokenInvalid = 'AUTH_TOKEN_INVALID';
  static const String authTokenExpired = 'AUTH_TOKEN_EXPIRED';

  // Request errors
  static const String requestTimeout = 'REQUEST_TIMEOUT';
  static const String requestFailed = 'REQUEST_FAILED';
  static const String invalidRequestFormat = 'INVALID_REQUEST_FORMAT';
  static const String invalidResponseFormat = 'INVALID_RESPONSE_FORMAT';

  // Message protocol errors
  static const String messageSerializationFailed =
      'MESSAGE_SERIALIZATION_FAILED';
  static const String messageDeserializationFailed =
      'MESSAGE_DESERIALIZATION_FAILED';
  static const String invalidMessageFormat = 'INVALID_MESSAGE_FORMAT';

  // Local service errors
  static const String ollamaUnavailable = 'OLLAMA_UNAVAILABLE';
  static const String ollamaTimeout = 'OLLAMA_TIMEOUT';
  static const String ollamaError = 'OLLAMA_ERROR';

  // Health check errors
  static const String pingTimeout = 'PING_TIMEOUT';
  static const String pongTimeout = 'PONG_TIMEOUT';
  static const String healthCheckFailed = 'HEALTH_CHECK_FAILED';
}

/// Enhanced tunnel exception with error codes and context
class TunnelException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? context;
  final Exception? originalException;
  final StackTrace? stackTrace;

  const TunnelException(
    this.code,
    this.message, {
    this.context,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('TunnelException: $message (code: $code)');
    if (context != null && context!.isNotEmpty) {
      buffer.write(' - Context: ${jsonEncode(context)}');
    }
    if (originalException != null) {
      buffer.write(' - Caused by: $originalException');
    }
    return buffer.toString();
  }

  /// Create a connection error
  static TunnelException connectionError(
    String message, {
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return TunnelException(
      TunnelErrorCodes.connectionFailed,
      message,
      context: context,
      originalException: originalException,
    );
  }

  /// Create a timeout error
  static TunnelException timeoutError(
    String message, {
    Map<String, dynamic>? context,
  }) {
    return TunnelException(
      TunnelErrorCodes.requestTimeout,
      message,
      context: context,
    );
  }

  /// Create an authentication error
  static TunnelException authError(
    String message, {
    String code = TunnelErrorCodes.authTokenInvalid,
    Map<String, dynamic>? context,
  }) {
    return TunnelException(code, message, context: context);
  }

  /// Create a message protocol error
  static TunnelException protocolError(
    String message, {
    String code = TunnelErrorCodes.invalidMessageFormat,
    Map<String, dynamic>? context,
    Exception? originalException,
  }) {
    return TunnelException(
      code,
      message,
      context: context,
      originalException: originalException,
    );
  }
}

/// Enhanced logger for tunnel client with correlation IDs and structured logging
class TunnelLogger {
  final String service;
  final Uuid _uuid = const Uuid();

  TunnelLogger(this.service);

  /// Generate a new correlation ID
  String generateCorrelationId() => _uuid.v4();

  /// Hash user ID for logging (privacy protection)
  String? _hashUserId(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    // Simple hash for logging - first 8 chars + hash of full ID
    final hash = userId.hashCode.toRadixString(16);
    return '${userId.substring(0, 8)}...$hash';
  }

  /// Log a message with structured data
  void _log(
    LogLevel level,
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logEntry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': level.name,
      'service': service,
      'message': message,
      if (correlationId != null) 'correlationId': correlationId,
      if (userId != null) 'userId': _hashUserId(userId),
      if (context != null) ...context,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    // Use developer.log for structured logging in Flutter
    developer.log(
      jsonEncode(logEntry),
      name: service,
      level: _getLogLevelValue(level),
      error: error,
      stackTrace: stackTrace,
    );

    // Also log for debugging (using developer.log instead of print)
    if (level == LogLevel.error || level == LogLevel.warn) {
      developer.log('${level.name.toUpperCase()}: $message', name: service);
      if (error != null) developer.log('   Error: $error', name: service);
    } else {
      developer.log('${level.name.toUpperCase()}: $message', name: service);
    }
  }

  int _getLogLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  /// Log debug message
  void debug(
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.debug,
      message,
      correlationId: correlationId,
      userId: userId,
      context: context,
    );
  }

  /// Log info message
  void info(
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.info,
      message,
      correlationId: correlationId,
      userId: userId,
      context: context,
    );
  }

  /// Log warning message
  void warn(
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
    Object? error,
  }) {
    _log(
      LogLevel.warn,
      message,
      correlationId: correlationId,
      userId: userId,
      context: context,
      error: error,
    );
  }

  /// Log error message
  void error(
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      correlationId: correlationId,
      userId: userId,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log connection event
  void logConnection(
    String event,
    String? connectionId, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    info(
      'Connection $event',
      correlationId: correlationId,
      userId: userId,
      context: {
        'event': 'connection',
        'connectionEvent': event,
        if (connectionId != null) 'connectionId': connectionId,
        ...?context,
      },
    );
  }

  /// Log request event
  void logRequest(
    String event,
    String requestId, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    final level = (event == 'failed' || event == 'timeout')
        ? LogLevel.warn
        : LogLevel.info;
    _log(
      level,
      'Request $event',
      correlationId: correlationId,
      userId: userId,
      context: {
        'event': 'request',
        'requestEvent': event,
        'requestId': requestId,
        ...?context,
      },
    );
  }

  /// Log tunnel error with structured information
  void logTunnelError(
    String errorCode,
    String message, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    this.error(
      'Tunnel error: $message',
      correlationId: correlationId,
      userId: userId,
      context: {'event': 'tunnel_error', 'errorCode': errorCode, ...?context},
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log performance metrics
  void logPerformance(
    String operation,
    Duration duration, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    info(
      'Performance: $operation',
      correlationId: correlationId,
      userId: userId,
      context: {
        'event': 'performance',
        'operation': operation,
        'duration': duration.inMilliseconds,
        ...?context,
      },
    );
  }

  /// Log security events
  void logSecurity(
    String event, {
    String? correlationId,
    String? userId,
    Map<String, dynamic>? context,
  }) {
    warn(
      'Security event: $event',
      correlationId: correlationId,
      userId: userId,
      context: {'event': 'security', 'securityEvent': event, ...?context},
    );
  }

  /// Create a child logger with additional context
  TunnelLogger child(Map<String, dynamic> additionalContext) {
    // For simplicity, return the same logger
    // In a more complex implementation, you could create a wrapper
    // that automatically includes the additional context
    return this;
  }
}

/// Performance metrics tracker for tunnel operations with enhanced monitoring
class TunnelMetrics {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int timeoutRequests = 0;
  int reconnectionAttempts = 0;
  Duration totalResponseTime = Duration.zero;
  DateTime? lastSuccessfulRequest;
  DateTime? lastFailedRequest;
  DateTime? lastReconnection;

  // Enhanced performance metrics
  int _memoryUsageBytes = 0;
  int _peakMemoryUsageBytes = 0;
  int _activeConnections = 0;
  int _peakActiveConnections = 0;
  final List<Duration> _recentResponseTimes = [];
  final List<DateTime> _requestTimestamps = [];
  static const int _maxRecentSamples = 100;
  static const Duration _throughputWindow = Duration(minutes: 1);

  // Connection pool metrics
  int _pooledConnections = 0;
  int _poolHits = 0;
  int _poolMisses = 0;

  // Message queue metrics
  int _queuedMessages = 0;
  int _peakQueuedMessages = 0;
  Duration _averageQueueTime = Duration.zero;

  /// Get average response time
  Duration get averageResponseTime {
    if (successfulRequests == 0) return Duration.zero;
    return Duration(
      milliseconds: totalResponseTime.inMilliseconds ~/ successfulRequests,
    );
  }

  /// Get recent average response time (last 100 requests)
  Duration get recentAverageResponseTime {
    if (_recentResponseTimes.isEmpty) return Duration.zero;
    final totalMs = _recentResponseTimes
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ _recentResponseTimes.length);
  }

  /// Get 95th percentile response time
  Duration get p95ResponseTime {
    if (_recentResponseTimes.isEmpty) return Duration.zero;
    final sorted = List<Duration>.from(_recentResponseTimes)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
    final index = (sorted.length * 0.95).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get current throughput (requests per minute)
  double get currentThroughput {
    final now = DateTime.now();
    final cutoff = now.subtract(_throughputWindow);
    final recentRequests = _requestTimestamps
        .where((timestamp) => timestamp.isAfter(cutoff))
        .length;
    return recentRequests.toDouble();
  }

  /// Get success rate as percentage
  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  /// Get timeout rate as percentage
  double get timeoutRate {
    if (totalRequests == 0) return 0.0;
    return (timeoutRequests / totalRequests) * 100;
  }

  /// Get connection pool efficiency
  double get poolEfficiency {
    final totalPoolRequests = _poolHits + _poolMisses;
    if (totalPoolRequests == 0) return 0.0;
    return (_poolHits / totalPoolRequests) * 100;
  }

  /// Get memory usage in MB
  double get memoryUsageMB => _memoryUsageBytes / (1024 * 1024);

  /// Get peak memory usage in MB
  double get peakMemoryUsageMB => _peakMemoryUsageBytes / (1024 * 1024);

  /// Record a successful request
  void recordSuccess(Duration responseTime) {
    totalRequests++;
    successfulRequests++;
    totalResponseTime += responseTime;
    lastSuccessfulRequest = DateTime.now();

    // Track recent response times
    _recentResponseTimes.add(responseTime);
    if (_recentResponseTimes.length > _maxRecentSamples) {
      _recentResponseTimes.removeAt(0);
    }

    // Track request timestamps for throughput calculation
    _requestTimestamps.add(DateTime.now());
    _cleanupOldTimestamps();
  }

  /// Record a failed request
  void recordFailure({bool isTimeout = false}) {
    totalRequests++;
    failedRequests++;
    if (isTimeout) {
      timeoutRequests++;
    }
    lastFailedRequest = DateTime.now();

    // Track request timestamps for throughput calculation
    _requestTimestamps.add(DateTime.now());
    _cleanupOldTimestamps();
  }

  /// Record a reconnection attempt
  void recordReconnection() {
    reconnectionAttempts++;
    lastReconnection = DateTime.now();
  }

  /// Update memory usage metrics
  void updateMemoryUsage(int bytes) {
    _memoryUsageBytes = bytes;
    if (bytes > _peakMemoryUsageBytes) {
      _peakMemoryUsageBytes = bytes;
    }
  }

  /// Update active connections count
  void updateActiveConnections(int count) {
    _activeConnections = count;
    if (count > _peakActiveConnections) {
      _peakActiveConnections = count;
    }
  }

  /// Record connection pool hit
  void recordPoolHit() {
    _poolHits++;
  }

  /// Record connection pool miss
  void recordPoolMiss() {
    _poolMisses++;
  }

  /// Update pooled connections count
  void updatePooledConnections(int count) {
    _pooledConnections = count;
  }

  /// Update message queue metrics
  void updateQueueMetrics(int queuedCount, Duration averageQueueTime) {
    _queuedMessages = queuedCount;
    if (queuedCount > _peakQueuedMessages) {
      _peakQueuedMessages = queuedCount;
    }
    _averageQueueTime = averageQueueTime;
  }

  /// Clean up old timestamps to maintain throughput calculation window
  void _cleanupOldTimestamps() {
    final cutoff = DateTime.now().subtract(_throughputWindow);
    _requestTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  }

  /// Get comprehensive metrics as a map
  Map<String, dynamic> toMap() {
    return {
      // Basic request metrics
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'timeoutRequests': timeoutRequests,
      'reconnectionAttempts': reconnectionAttempts,

      // Response time metrics
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'recentAverageResponseTime': recentAverageResponseTime.inMilliseconds,
      'p95ResponseTime': p95ResponseTime.inMilliseconds,

      // Rate metrics
      'successRate': double.parse(successRate.toStringAsFixed(2)),
      'timeoutRate': double.parse(timeoutRate.toStringAsFixed(2)),
      'currentThroughput': double.parse(currentThroughput.toStringAsFixed(2)),

      // Connection metrics
      'activeConnections': _activeConnections,
      'peakActiveConnections': _peakActiveConnections,
      'pooledConnections': _pooledConnections,
      'poolEfficiency': double.parse(poolEfficiency.toStringAsFixed(2)),
      'poolHits': _poolHits,
      'poolMisses': _poolMisses,

      // Memory metrics
      'memoryUsageMB': double.parse(memoryUsageMB.toStringAsFixed(2)),
      'peakMemoryUsageMB': double.parse(peakMemoryUsageMB.toStringAsFixed(2)),

      // Queue metrics
      'queuedMessages': _queuedMessages,
      'peakQueuedMessages': _peakQueuedMessages,
      'averageQueueTime': _averageQueueTime.inMilliseconds,

      // Timestamps
      'lastSuccessfulRequest': lastSuccessfulRequest?.toIso8601String(),
      'lastFailedRequest': lastFailedRequest?.toIso8601String(),
      'lastReconnection': lastReconnection?.toIso8601String(),
    };
  }
}

/// Tunnel Configuration
/// Configuration options for tunnel service
library;

/// Log level enum
enum LogLevel {
  error,
  warn,
  info,
  debug,
  trace,
}

/// Tunnel configuration
class TunnelConfig {
  final int maxReconnectAttempts;
  final Duration reconnectBaseDelay;
  final Duration requestTimeout;
  final int maxQueueSize;
  final bool enableCompression;
  final bool enableAutoReconnect;
  final LogLevel logLevel;

  const TunnelConfig({
    this.maxReconnectAttempts = 10,
    this.reconnectBaseDelay = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 30),
    this.maxQueueSize = 100,
    this.enableCompression = true,
    this.enableAutoReconnect = true,
    this.logLevel = LogLevel.info,
  });

  /// Stable Network profile
  /// Optimized for reliable, low-latency networks
  /// - Fewer reconnection attempts (5)
  /// - Shorter reconnect delay (2s)
  /// - Standard request timeout (30s)
  /// - Smaller queue (100 requests)
  factory TunnelConfig.stableNetwork() {
    return const TunnelConfig(
      maxReconnectAttempts: 5,
      reconnectBaseDelay: Duration(seconds: 2),
      requestTimeout: Duration(seconds: 30),
      maxQueueSize: 100,
      enableCompression: true,
      enableAutoReconnect: true,
      logLevel: LogLevel.warn,
    );
  }

  /// Unstable Network profile
  /// Optimized for unreliable, high-latency networks
  /// - More reconnection attempts (15)
  /// - Longer reconnect delay (5s)
  /// - Extended request timeout (60s)
  /// - Larger queue (200 requests)
  factory TunnelConfig.unstableNetwork() {
    return const TunnelConfig(
      maxReconnectAttempts: 15,
      reconnectBaseDelay: Duration(seconds: 5),
      requestTimeout: Duration(seconds: 60),
      maxQueueSize: 200,
      enableCompression: true,
      enableAutoReconnect: true,
      logLevel: LogLevel.debug,
    );
  }

  /// Low Bandwidth profile
  /// Optimized for bandwidth-constrained networks
  /// - Standard reconnection attempts (10)
  /// - Medium reconnect delay (3s)
  /// - Extended request timeout (60s)
  /// - Smaller queue (50 requests)
  /// - Compression enabled
  factory TunnelConfig.lowBandwidth() {
    return const TunnelConfig(
      maxReconnectAttempts: 10,
      reconnectBaseDelay: Duration(seconds: 3),
      requestTimeout: Duration(seconds: 60),
      maxQueueSize: 50,
      enableCompression: true,
      enableAutoReconnect: true,
      logLevel: LogLevel.info,
    );
  }

  /// Copy with modifications
  TunnelConfig copyWith({
    int? maxReconnectAttempts,
    Duration? reconnectBaseDelay,
    Duration? requestTimeout,
    int? maxQueueSize,
    bool? enableCompression,
    bool? enableAutoReconnect,
    LogLevel? logLevel,
  }) {
    return TunnelConfig(
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectBaseDelay: reconnectBaseDelay ?? this.reconnectBaseDelay,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      enableCompression: enableCompression ?? this.enableCompression,
      enableAutoReconnect: enableAutoReconnect ?? this.enableAutoReconnect,
      logLevel: logLevel ?? this.logLevel,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'maxReconnectAttempts': maxReconnectAttempts,
      'reconnectBaseDelay': reconnectBaseDelay.inMilliseconds,
      'requestTimeout': requestTimeout.inMilliseconds,
      'maxQueueSize': maxQueueSize,
      'enableCompression': enableCompression,
      'enableAutoReconnect': enableAutoReconnect,
      'logLevel': logLevel.name,
    };
  }

  /// Create from JSON
  factory TunnelConfig.fromJson(Map<String, dynamic> json) {
    return TunnelConfig(
      maxReconnectAttempts: json['maxReconnectAttempts'] as int,
      reconnectBaseDelay:
          Duration(milliseconds: json['reconnectBaseDelay'] as int),
      requestTimeout: Duration(milliseconds: json['requestTimeout'] as int),
      maxQueueSize: json['maxQueueSize'] as int,
      enableCompression: json['enableCompression'] as bool,
      enableAutoReconnect: json['enableAutoReconnect'] as bool,
      logLevel: LogLevel.values.firstWhere(
        (e) => e.name == json['logLevel'],
        orElse: () => LogLevel.info,
      ),
    );
  }
}

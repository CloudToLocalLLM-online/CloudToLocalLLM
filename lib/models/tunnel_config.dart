import '../config/app_config.dart';

/// Configuration model for tunnel connections with authentication and connection details
///
/// This model contains all the necessary information to establish and maintain
/// a tunnel connection between the web app and desktop client during setup.
class SetupTunnelConfig {
  final String userId;
  final String cloudProxyUrl;
  final String localOllamaUrl;
  final String authToken;
  final bool enableCloudProxy;
  final int connectionTimeout;
  final int healthCheckInterval;
  final int retryAttempts;
  final int retryDelay;
  final Map<String, String>? customHeaders;
  final Map<String, dynamic>? metadata;

  const SetupTunnelConfig({
    required this.userId,
    required this.cloudProxyUrl,
    required this.localOllamaUrl,
    required this.authToken,
    this.enableCloudProxy = true,
    this.connectionTimeout = 30,
    this.healthCheckInterval = 30,
    this.retryAttempts = 3,
    this.retryDelay = 5,
    this.customHeaders,
    this.metadata,
  });

  /// Create a default configuration for testing
  factory SetupTunnelConfig.defaultConfig({
    required String userId,
    required String authToken,
  }) {
    return SetupTunnelConfig(
      userId: userId,
      cloudProxyUrl: AppConfig.tunnelWebSocketUrl,
      localOllamaUrl: 'http://localhost:11434',
      authToken: authToken,
      enableCloudProxy: true,
      connectionTimeout: 30,
      healthCheckInterval: 30,
      retryAttempts: 3,
      retryDelay: 5,
    );
  }

  /// Create configuration for development environment
  factory SetupTunnelConfig.development({
    required String userId,
    required String authToken,
  }) {
    return SetupTunnelConfig(
      userId: userId,
      cloudProxyUrl: AppConfig.tunnelWebSocketUrlDev,
      localOllamaUrl: 'http://localhost:11434',
      authToken: authToken,
      enableCloudProxy: true,
      connectionTimeout: 10,
      healthCheckInterval: 15,
      retryAttempts: 5,
      retryDelay: 2,
    );
  }

  /// Create a copy of this configuration with updated values
  SetupTunnelConfig copyWith({
    String? userId,
    String? cloudProxyUrl,
    String? localOllamaUrl,
    String? authToken,
    bool? enableCloudProxy,
    int? connectionTimeout,
    int? healthCheckInterval,
    int? retryAttempts,
    int? retryDelay,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? metadata,
  }) {
    return SetupTunnelConfig(
      userId: userId ?? this.userId,
      cloudProxyUrl: cloudProxyUrl ?? this.cloudProxyUrl,
      localOllamaUrl: localOllamaUrl ?? this.localOllamaUrl,
      authToken: authToken ?? this.authToken,
      enableCloudProxy: enableCloudProxy ?? this.enableCloudProxy,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      healthCheckInterval: healthCheckInterval ?? this.healthCheckInterval,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      customHeaders: customHeaders ?? this.customHeaders,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'cloudProxyUrl': cloudProxyUrl,
      'localOllamaUrl': localOllamaUrl,
      'authToken': authToken,
      'enableCloudProxy': enableCloudProxy,
      'connectionTimeout': connectionTimeout,
      'healthCheckInterval': healthCheckInterval,
      'retryAttempts': retryAttempts,
      'retryDelay': retryDelay,
      'customHeaders': customHeaders,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory SetupTunnelConfig.fromJson(Map<String, dynamic> json) {
    return SetupTunnelConfig(
      userId: json['userId'] as String,
      cloudProxyUrl: json['cloudProxyUrl'] as String,
      localOllamaUrl: json['localOllamaUrl'] as String,
      authToken: json['authToken'] as String,
      enableCloudProxy: json['enableCloudProxy'] as bool? ?? true,
      connectionTimeout: json['connectionTimeout'] as int? ?? 30,
      healthCheckInterval: json['healthCheckInterval'] as int? ?? 30,
      retryAttempts: json['retryAttempts'] as int? ?? 3,
      retryDelay: json['retryDelay'] as int? ?? 5,
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Get WebSocket URL for connection
  String get webSocketUrl {
    if (cloudProxyUrl.startsWith('ws://') ||
        cloudProxyUrl.startsWith('wss://')) {
      return cloudProxyUrl;
    }

    // Convert HTTP(S) URL to WebSocket URL
    if (cloudProxyUrl.startsWith('https://')) {
      return cloudProxyUrl.replaceFirst('https://', 'wss://');
    } else if (cloudProxyUrl.startsWith('http://')) {
      return cloudProxyUrl.replaceFirst('http://', 'ws://');
    }

    return cloudProxyUrl;
  }

  /// Get connection headers including authentication
  Map<String, String> get connectionHeaders {
    final headers = <String, String>{
      'Authorization': 'Bearer $authToken',
      'User-Agent': 'CloudToLocalLLM-TunnelClient/1.0',
    };

    if (customHeaders != null) {
      headers.addAll(customHeaders!);
    }

    return headers;
  }

  /// Validate configuration
  bool get isValid {
    return userId.isNotEmpty &&
        cloudProxyUrl.isNotEmpty &&
        localOllamaUrl.isNotEmpty &&
        authToken.isNotEmpty &&
        connectionTimeout > 0 &&
        healthCheckInterval > 0 &&
        retryAttempts >= 0 &&
        retryDelay >= 0;
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> get summary {
    return {
      'userId': userId,
      'cloudProxyUrl': cloudProxyUrl,
      'localOllamaUrl': localOllamaUrl,
      'enableCloudProxy': enableCloudProxy,
      'connectionTimeout': connectionTimeout,
      'healthCheckInterval': healthCheckInterval,
      'retryAttempts': retryAttempts,
      'retryDelay': retryDelay,
      'hasCustomHeaders': customHeaders != null && customHeaders!.isNotEmpty,
      'hasMetadata': metadata != null && metadata!.isNotEmpty,
      'isValid': isValid,
    };
  }

  @override
  String toString() {
    return 'SetupTunnelConfig(userId: $userId, cloudProxyUrl: $cloudProxyUrl, '
        'localOllamaUrl: $localOllamaUrl, enableCloudProxy: $enableCloudProxy, '
        'connectionTimeout: ${connectionTimeout}s, healthCheckInterval: ${healthCheckInterval}s, '
        'retryAttempts: $retryAttempts, retryDelay: ${retryDelay}s, isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SetupTunnelConfig &&
        other.userId == userId &&
        other.cloudProxyUrl == cloudProxyUrl &&
        other.localOllamaUrl == localOllamaUrl &&
        other.authToken == authToken &&
        other.enableCloudProxy == enableCloudProxy &&
        other.connectionTimeout == connectionTimeout &&
        other.healthCheckInterval == healthCheckInterval &&
        other.retryAttempts == retryAttempts &&
        other.retryDelay == retryDelay;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      cloudProxyUrl,
      localOllamaUrl,
      authToken,
      enableCloudProxy,
      connectionTimeout,
      healthCheckInterval,
      retryAttempts,
      retryDelay,
    );
  }
}

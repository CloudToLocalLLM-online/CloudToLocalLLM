/// Tunnel connection state model
///
/// Represents the current state of a tunnel connection with all relevant information
class TunnelState {
  final bool isConnected;
  final bool isConnecting;
  final bool isDisconnecting;
  final String? error;
  final DateTime? connectedAt;
  final int? tunnelPort;
  final String? tunnelId;
  final TunnelConnectionQuality quality;
  final TunnelStats? stats;

  const TunnelState({
    this.isConnected = false,
    this.isConnecting = false,
    this.isDisconnecting = false,
    this.error,
    this.connectedAt,
    this.tunnelPort,
    this.tunnelId,
    this.quality = TunnelConnectionQuality.unknown,
    this.stats,
  });

  TunnelState copyWith({
    bool? isConnected,
    bool? isConnecting,
    bool? isDisconnecting,
    String? error,
    DateTime? connectedAt,
    int? tunnelPort,
    String? tunnelId,
    TunnelConnectionQuality? quality,
    TunnelStats? stats,
    bool clearError = false,
  }) {
    return TunnelState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
      error: clearError ? null : (error ?? this.error),
      connectedAt: connectedAt ?? this.connectedAt,
      tunnelPort: tunnelPort ?? this.tunnelPort,
      tunnelId: tunnelId ?? this.tunnelId,
      quality: quality ?? this.quality,
      stats: stats ?? this.stats,
    );
  }

  bool get isActive => isConnected && error == null;
  bool get hasError => error != null;
  Duration? get connectionDuration {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }
}

/// Tunnel connection quality indicator
enum TunnelConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  unknown;

  String get label {
    switch (this) {
      case TunnelConnectionQuality.excellent:
        return 'Excellent';
      case TunnelConnectionQuality.good:
        return 'Good';
      case TunnelConnectionQuality.fair:
        return 'Fair';
      case TunnelConnectionQuality.poor:
        return 'Poor';
      case TunnelConnectionQuality.unknown:
        return 'Unknown';
    }
  }

  static TunnelConnectionQuality fromLatency(int latencyMs) {
    if (latencyMs < 50) return TunnelConnectionQuality.excellent;
    if (latencyMs < 100) return TunnelConnectionQuality.good;
    if (latencyMs < 200) return TunnelConnectionQuality.fair;
    return TunnelConnectionQuality.poor;
  }
}

/// Tunnel connection statistics
class TunnelStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int averageLatencyMs;
  final DateTime lastRequestAt;
  final double bytesTransferred;
  final double bytesReceived;

  const TunnelStats({
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.averageLatencyMs = 0,
    required this.lastRequestAt,
    this.bytesTransferred = 0,
    this.bytesReceived = 0,
  });

  double get successRate {
    if (totalRequests == 0) return 0;
    return successfulRequests / totalRequests;
  }

  TunnelStats copyWith({
    int? totalRequests,
    int? successfulRequests,
    int? failedRequests,
    int? averageLatencyMs,
    DateTime? lastRequestAt,
    double? bytesTransferred,
    double? bytesReceived,
  }) {
    return TunnelStats(
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      failedRequests: failedRequests ?? this.failedRequests,
      averageLatencyMs: averageLatencyMs ?? this.averageLatencyMs,
      lastRequestAt: lastRequestAt ?? this.lastRequestAt,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      bytesReceived: bytesReceived ?? this.bytesReceived,
    );
  }
}

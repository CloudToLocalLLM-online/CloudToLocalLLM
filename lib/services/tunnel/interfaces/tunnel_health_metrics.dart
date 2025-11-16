/// Tunnel Health Metrics
/// Real-time health and performance metrics
library;

/// Connection quality indicator
enum ConnectionQuality {
  excellent, // < 50ms latency, < 1% loss
  good, // < 100ms latency, < 3% loss
  fair, // < 200ms latency, < 5% loss
  poor, // > 200ms latency or > 5% loss
}

/// Tunnel health metrics
class TunnelHealthMetrics {
  final Duration uptime;
  final int reconnectCount;
  final double averageLatency;
  final double packetLoss;
  final ConnectionQuality quality;
  final int queuedRequests;
  final int successfulRequests;
  final int failedRequests;

  const TunnelHealthMetrics({
    required this.uptime,
    required this.reconnectCount,
    required this.averageLatency,
    required this.packetLoss,
    required this.quality,
    required this.queuedRequests,
    required this.successfulRequests,
    required this.failedRequests,
  });

  /// Calculate success rate
  double get successRate {
    final total = successfulRequests + failedRequests;
    if (total == 0) return 0.0;
    return successfulRequests / total;
  }

  /// Create empty metrics
  factory TunnelHealthMetrics.empty() {
    return const TunnelHealthMetrics(
      uptime: Duration.zero,
      reconnectCount: 0,
      averageLatency: 0.0,
      packetLoss: 0.0,
      quality: ConnectionQuality.excellent,
      queuedRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
    );
  }

  /// Calculate connection quality from metrics
  static ConnectionQuality calculateQuality({
    required double latency,
    required double packetLoss,
  }) {
    if (latency < 50 && packetLoss < 0.01) {
      return ConnectionQuality.excellent;
    } else if (latency < 100 && packetLoss < 0.03) {
      return ConnectionQuality.good;
    } else if (latency < 200 && packetLoss < 0.05) {
      return ConnectionQuality.fair;
    } else {
      return ConnectionQuality.poor;
    }
  }

  /// Copy with modifications
  TunnelHealthMetrics copyWith({
    Duration? uptime,
    int? reconnectCount,
    double? averageLatency,
    double? packetLoss,
    ConnectionQuality? quality,
    int? queuedRequests,
    int? successfulRequests,
    int? failedRequests,
  }) {
    return TunnelHealthMetrics(
      uptime: uptime ?? this.uptime,
      reconnectCount: reconnectCount ?? this.reconnectCount,
      averageLatency: averageLatency ?? this.averageLatency,
      packetLoss: packetLoss ?? this.packetLoss,
      quality: quality ?? this.quality,
      queuedRequests: queuedRequests ?? this.queuedRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      failedRequests: failedRequests ?? this.failedRequests,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uptime': uptime.inMilliseconds,
      'reconnectCount': reconnectCount,
      'averageLatency': averageLatency,
      'packetLoss': packetLoss,
      'quality': quality.name,
      'queuedRequests': queuedRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'successRate': successRate,
    };
  }

  /// Create from JSON
  factory TunnelHealthMetrics.fromJson(Map<String, dynamic> json) {
    final qualityStr = json['quality'] as String;
    final quality = ConnectionQuality.values.firstWhere(
      (e) => e.name == qualityStr,
      orElse: () => ConnectionQuality.poor,
    );

    return TunnelHealthMetrics(
      uptime: Duration(milliseconds: json['uptime'] as int),
      reconnectCount: json['reconnectCount'] as int,
      averageLatency: (json['averageLatency'] as num).toDouble(),
      packetLoss: (json['packetLoss'] as num).toDouble(),
      quality: quality,
      queuedRequests: json['queuedRequests'] as int,
      successfulRequests: json['successfulRequests'] as int,
      failedRequests: json['failedRequests'] as int,
    );
  }
}

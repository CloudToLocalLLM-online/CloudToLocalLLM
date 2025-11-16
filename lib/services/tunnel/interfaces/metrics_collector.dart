/// Metrics Collector Interface
/// Collects and exports client-side tunnel metrics
library;

import 'tunnel_models.dart';

// TunnelMetrics is defined in tunnel_models.dart

/// Abstract interface for metrics collector
abstract class MetricsCollector {
  /// Record a request
  void recordRequest({
    required Duration latency,
    required bool success,
    String? errorType,
  });

  /// Record connection event
  void recordConnection({
    required String state,
    String? reason,
  });

  /// Record reconnection attempt
  void recordReconnection({
    required int attemptNumber,
    required bool success,
    Duration? delay,
  });

  /// Get metrics for time window
  TunnelMetrics getMetrics({Duration? window});

  /// Export in Prometheus format
  Map<String, dynamic> exportPrometheusFormat();

  /// Export in JSON format
  Map<String, dynamic> exportJson();
}

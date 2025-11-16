/// Tunnel Service Interface
/// Manages WebSocket tunnel connection lifecycle
library;

import 'package:flutter/foundation.dart';
import 'tunnel_config.dart';
import 'tunnel_health_metrics.dart';
import 'tunnel_models.dart';
import 'diagnostic_report.dart';

// TunnelConnectionState is defined in tunnel_models.dart

/// Abstract interface for tunnel service
abstract class TunnelService extends ChangeNotifier {
  /// Connect to tunnel server
  Future<void> connect({
    required String serverUrl,
    required String authToken,
    TunnelConfig? config,
  });

  /// Disconnect from tunnel server
  Future<void> disconnect({bool graceful = true});

  /// Gracefully shutdown the tunnel service
  /// Flushes pending requests, closes connections, and persists state
  /// Returns a Future that completes when shutdown is done
  Future<void> shutdownGracefully();

  /// Manually trigger reconnection
  Future<void> reconnect();

  /// Forward request through tunnel
  Future<TunnelResponse> forwardRequest(TunnelRequest request);

  /// Get current connection state
  TunnelConnectionState get connectionState;

  /// Get health metrics
  TunnelHealthMetrics get healthMetrics;

  /// Update configuration
  void updateConfig(TunnelConfig config);

  /// Get current configuration
  TunnelConfig get currentConfig;

  /// Run diagnostic tests
  Future<DiagnosticReport> runDiagnostics();
}

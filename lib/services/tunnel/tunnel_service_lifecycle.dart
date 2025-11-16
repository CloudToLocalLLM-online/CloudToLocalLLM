/// Tunnel Service Lifecycle Manager
/// Manages initialization and cleanup of tunnel services
library;

import 'package:flutter/foundation.dart';
import 'interfaces/interfaces.dart';

/// Lifecycle states for tunnel services
enum TunnelServiceLifecycleState {
  uninitialized,
  initializing,
  ready,
  disposing,
  disposed,
}

/// Manages the lifecycle of tunnel services
class TunnelServiceLifecycle extends ChangeNotifier {
  TunnelServiceLifecycleState _state =
      TunnelServiceLifecycleState.uninitialized;

  TunnelService? _tunnelService;
  RequestQueue? _requestQueue;
  MetricsCollector? _metricsCollector;

  /// Current lifecycle state
  TunnelServiceLifecycleState get state => _state;

  /// Check if services are ready
  bool get isReady => _state == TunnelServiceLifecycleState.ready;

  /// Get tunnel service instance
  TunnelService? get tunnelService => _tunnelService;

  /// Get request queue instance
  RequestQueue? get requestQueue => _requestQueue;

  /// Get metrics collector instance
  MetricsCollector? get metricsCollector => _metricsCollector;

  /// Initialize tunnel services
  ///
  /// This method should be called after authentication to set up
  /// all tunnel-related services.
  Future<void> initialize({
    required TunnelService tunnelService,
    RequestQueue? requestQueue,
    MetricsCollector? metricsCollector,
  }) async {
    if (_state != TunnelServiceLifecycleState.uninitialized) {
      debugPrint('[TunnelLifecycle] Already initialized or initializing');
      return;
    }

    _state = TunnelServiceLifecycleState.initializing;
    notifyListeners();

    try {
      _tunnelService = tunnelService;
      _requestQueue = requestQueue;
      _metricsCollector = metricsCollector;

      // Restore persisted requests if queue is available
      if (_requestQueue != null) {
        await _requestQueue!.restorePersistedRequests();
      }

      _state = TunnelServiceLifecycleState.ready;
      notifyListeners();

      debugPrint('[TunnelLifecycle] Services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[TunnelLifecycle] Initialization failed: $e');
      debugPrint('[TunnelLifecycle] Stack trace: $stackTrace');
      _state = TunnelServiceLifecycleState.uninitialized;
      notifyListeners();
      rethrow;
    }
  }

  /// Dispose tunnel services
  ///
  /// This method should be called during app shutdown or logout
  /// to properly clean up resources.
  Future<void> disposeServices() async {
    if (_state == TunnelServiceLifecycleState.disposed ||
        _state == TunnelServiceLifecycleState.disposing) {
      return;
    }

    _state = TunnelServiceLifecycleState.disposing;
    notifyListeners();

    try {
      // Persist high-priority requests before shutdown
      if (_requestQueue != null) {
        await _requestQueue!.persistHighPriorityRequests();
      }

      // Disconnect tunnel gracefully
      if (_tunnelService != null) {
        await _tunnelService!.disconnect(graceful: true);
      }

      // Clear references
      _tunnelService = null;
      _requestQueue = null;
      _metricsCollector = null;

      _state = TunnelServiceLifecycleState.disposed;
      notifyListeners();

      debugPrint('[TunnelLifecycle] Services disposed successfully');
    } catch (e, stackTrace) {
      debugPrint('[TunnelLifecycle] Disposal failed: $e');
      debugPrint('[TunnelLifecycle] Stack trace: $stackTrace');
      // Still mark as disposed even if cleanup failed
      _state = TunnelServiceLifecycleState.disposed;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Ensure cleanup happens
    if (_state != TunnelServiceLifecycleState.disposed) {
      disposeServices();
    }
    super.dispose();
  }
}

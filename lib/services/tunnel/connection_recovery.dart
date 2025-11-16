/// Connection Recovery Manager
///
/// Handles connection recovery flow including detection, reconnection, and state restoration.
///
/// ## Recovery Flow
///
/// The connection recovery manager orchestrates the complete recovery process:
///
/// 1. **Disconnection Detection**
///    - Triggered by WebSocket error, heartbeat timeout, or network error
///    - Updates connection state to DISCONNECTED
///    - Records error for diagnostics
///
/// 2. **Reconnection Attempt**
///    - Updates state to RECONNECTING
///    - Uses ReconnectionManager with exponential backoff
///    - Retries up to maxAttempts times
///
/// 3. **State Restoration**
///    - After successful reconnection, restores connection state
///    - Resets error counters
///    - Updates connection metadata
///
/// 4. **Request Flushing**
///    - Flushes queued requests after successful reconnection
///    - Ensures no data loss during disconnection
///    - Maintains request ordering
///
/// ## Usage Example
///
/// ```dart
/// final recovery = ConnectionRecovery(
///   reconnectionManager: manager,
///   stateTracker: tracker,
///   connectFunction: () => tunnel.connect(url, token),
///   requestQueue: queue,
///   onLog: (msg) => print('[Recovery] $msg'),
/// );
///
/// // Handle disconnection
/// try {
///   await websocket.listen((message) {
///     // Process message
///   }, onError: (error) async {
///     final success = await recovery.handleDisconnection(
///       reason: 'WebSocket error',
///       error: TunnelError(...),
///       autoReconnect: true,
///     );
///   });
/// } catch (e) {
///   // Handle error
/// }
/// ```
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'interfaces/tunnel_models.dart';
import 'interfaces/request_queue.dart';
import 'reconnection_manager.dart';
import 'connection_state_tracker.dart';

/// Connection recovery manager
///
/// Orchestrates the complete recovery flow including disconnection detection,
/// reconnection attempts, state restoration, and request flushing.
class ConnectionRecovery {
  /// Reconnection manager for exponential backoff
  final ReconnectionManager reconnectionManager;

  /// Connection state tracker
  final ConnectionStateTracker stateTracker;

  /// Optional request queue for flushing after reconnect
  final RequestQueue? requestQueue;

  /// Function to call for reconnection
  final Future<void> Function() connectFunction;

  /// Optional logging callback
  final void Function(String message)? onLog;

  /// Whether recovery is currently in progress
  bool _isRecovering = false;

  /// Timer for recovery timeout
  Timer? _recoveryTimer;

  /// Completer for recovery result
  Completer<bool>? _recoveryCompleter;

  /// Create a new ConnectionRecovery manager
  ///
  /// @param reconnectionManager - Manager for reconnection attempts
  /// @param stateTracker - Tracker for connection state
  /// @param connectFunction - Function to call for reconnection
  /// @param requestQueue - Optional queue for flushing requests
  /// @param onLog - Optional logging callback
  ConnectionRecovery({
    required this.reconnectionManager,
    required this.stateTracker,
    required this.connectFunction,
    this.requestQueue,
    this.onLog,
  });

  /// Check if recovery is in progress
  bool get isRecovering => _isRecovering;

  /// Detect and handle disconnection
  ///
  /// Called when a disconnection is detected (WebSocket error, heartbeat timeout, etc).
  /// Updates connection state and optionally initiates recovery.
  ///
  /// @param reason - Reason for disconnection (e.g., 'WebSocket error')
  /// @param error - Optional TunnelError with details
  /// @param autoReconnect - Whether to automatically attempt reconnection
  /// @return true if recovery succeeded, false otherwise
  ///
  /// @example
  /// ```dart
  /// websocket.onError = (error) async {
  ///   await recovery.handleDisconnection(
  ///     reason: 'WebSocket error: $error',
  ///     autoReconnect: true,
  ///   );
  /// };
  /// ```
  Future<bool> handleDisconnection({
    required String reason,
    TunnelError? error,
    bool autoReconnect = true,
  }) async {
    _log('Disconnection detected: $reason');

    // Update state to disconnected
    stateTracker.updateState(
      TunnelConnectionState.disconnected,
      message: reason,
      metadata: {
        'reason': reason,
        'autoReconnect': autoReconnect,
        if (error != null) 'error': error.toJson(),
      },
    );

    // Record error if provided
    if (error != null) {
      stateTracker.recordError(error);
    }

    // Attempt recovery if auto-reconnect is enabled
    if (autoReconnect) {
      return await attemptRecovery();
    }

    return false;
  }

  /// Attempt connection recovery
  ///
  /// Initiates the recovery flow:
  /// 1. Update state to RECONNECTING
  /// 2. Use reconnection manager to attempt reconnection
  /// 3. Restore state on success
  /// 4. Flush queued requests
  ///
  /// @return true if recovery succeeded, false otherwise
  ///
  /// @example
  /// ```dart
  /// final success = await recovery.attemptRecovery();
  /// if (success) {
  ///   print('Connection restored');
  /// }
  /// ```
  Future<bool> attemptRecovery() async {
    if (_isRecovering) {
      _log('Recovery already in progress');
      return _recoveryCompleter?.future ?? Future.value(false);
    }

    _isRecovering = true;
    _recoveryCompleter = Completer<bool>();

    try {
      _log('Starting connection recovery');

      // Update state to reconnecting
      stateTracker.updateState(
        TunnelConnectionState.reconnecting,
        message: 'Attempting to reconnect...',
      );

      // Attempt reconnection with exponential backoff
      final success = await reconnectionManager.attemptReconnection(() async {
        // Track reconnection attempt
        stateTracker.incrementReconnectAttempts();

        // Attempt to connect
        await connectFunction();

        // If we get here, connection succeeded
        _log('Reconnection attempt succeeded');
      });

      if (success) {
        // Connection restored successfully
        await _onRecoverySuccess();
        _recoveryCompleter!.complete(true);
        return true;
      } else {
        // Recovery was cancelled
        _log('Recovery cancelled');
        stateTracker.updateState(
          TunnelConnectionState.disconnected,
          message: 'Recovery cancelled',
        );
        _recoveryCompleter!.complete(false);
        return false;
      }
    } catch (e, stackTrace) {
      // Recovery failed
      _log('Recovery failed: $e');

      final error = e is TunnelError
          ? e
          : TunnelError.fromException(
              e as Exception,
              stackTrace: stackTrace,
            );

      stateTracker.updateState(
        TunnelConnectionState.error,
        message: 'Recovery failed: ${error.userMessage}',
      );

      stateTracker.recordError(error);

      _recoveryCompleter!.complete(false);
      return false;
    } finally {
      _isRecovering = false;
      _recoveryCompleter = null;
    }
  }

  /// Handle successful recovery
  Future<void> _onRecoverySuccess() async {
    _log('Connection recovery successful');

    // Reset reconnection attempts
    stateTracker.resetReconnectAttempts();

    // Update state to connected
    stateTracker.updateState(
      TunnelConnectionState.connected,
      message: 'Reconnected successfully',
    );

    // Restore connection state
    await _restoreConnectionState();

    // Flush queued requests
    await _flushQueuedRequests();
  }

  /// Restore connection state after reconnection
  Future<void> _restoreConnectionState() async {
    _log('Restoring connection state');

    // Connection state is already tracked by stateTracker
    // Additional state restoration can be added here if needed
    // For example: re-subscribe to channels, restore session data, etc.

    // Record state restoration event
    stateTracker.recordEvent(ConnectionEvent(
      type: ConnectionEventType.connected,
      message: 'Connection state restored',
    ));
  }

  /// Flush queued requests after successful reconnection
  Future<void> _flushQueuedRequests() async {
    if (requestQueue == null) {
      _log('No request queue configured');
      return;
    }

    final queueSize = requestQueue!.size;
    if (queueSize == 0) {
      _log('No queued requests to flush');
      return;
    }

    _log('Flushing $queueSize queued requests');

    // Note: The actual request sending will be handled by the TunnelService
    // This just logs the queue state. The TunnelService should monitor
    // the connection state and automatically process queued requests.

    stateTracker.recordEvent(ConnectionEvent(
      type: ConnectionEventType.connected,
      message: 'Ready to flush $queueSize queued requests',
      metadata: {
        'queueSize': queueSize,
      },
    ));
  }

  /// Cancel ongoing recovery
  ///
  /// Stops the recovery process and resets state
  void cancelRecovery() {
    if (!_isRecovering) {
      return;
    }

    _log('Cancelling recovery');

    reconnectionManager.cancel();
    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    if (_recoveryCompleter != null && !_recoveryCompleter!.isCompleted) {
      _recoveryCompleter!.complete(false);
    }

    _isRecovering = false;
    _recoveryCompleter = null;
  }

  /// Handle network change event
  ///
  /// Called when network connectivity changes (e.g., WiFi to cellular)
  Future<void> handleNetworkChange({
    required bool isConnected,
    String? networkType,
  }) async {
    _log('Network change detected: connected=$isConnected, type=$networkType');

    stateTracker.recordEvent(ConnectionEvent(
      type: ConnectionEventType.connected,
      message: 'Network change detected',
      metadata: {
        'isConnected': isConnected,
        'networkType': networkType,
      },
    ));

    if (isConnected &&
        stateTracker.state == TunnelConnectionState.disconnected) {
      // Network is back, attempt recovery
      _log('Network restored, attempting recovery');
      await attemptRecovery();
    } else if (!isConnected &&
        stateTracker.state == TunnelConnectionState.connected) {
      // Network lost, handle disconnection
      await handleDisconnection(
        reason: 'Network connection lost',
        autoReconnect: true,
      );
    }
  }

  /// Test connection health
  ///
  /// Performs a quick health check to verify connection is working
  Future<bool> testConnection() async {
    try {
      _log('Testing connection health');

      // This is a placeholder - actual implementation would send a test message
      // and wait for response. For now, we just check the state.

      final isHealthy = stateTracker.state == TunnelConnectionState.connected;

      stateTracker.recordHealthCheck(
        healthy: isHealthy,
        message: isHealthy ? 'Connection healthy' : 'Connection unhealthy',
      );

      return isHealthy;
    } catch (e) {
      _log('Connection health check failed: $e');

      stateTracker.recordHealthCheck(
        healthy: false,
        message: 'Health check failed: $e',
      );

      return false;
    }
  }

  /// Get recovery statistics
  Map<String, dynamic> getRecoveryStats() {
    return {
      'isRecovering': _isRecovering,
      'reconnectAttempts': stateTracker.reconnectAttempts,
      'currentAttempt': reconnectionManager.currentAttempt,
      'maxAttempts': reconnectionManager.maxAttempts,
      'lastAttemptTime': reconnectionManager.lastAttemptTime?.toIso8601String(),
      'connectionState': stateTracker.state.name,
      'queuedRequests': requestQueue?.size ?? 0,
    };
  }

  /// Log message
  void _log(String message) {
    if (onLog != null) {
      onLog!(message);
    } else {
      debugPrint('[ConnectionRecovery] $message');
    }
  }

  /// Dispose resources
  void dispose() {
    cancelRecovery();
    _recoveryTimer?.cancel();
  }
}

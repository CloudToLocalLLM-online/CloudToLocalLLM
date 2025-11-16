/// Reconnection Manager
///
/// Handles automatic reconnection with exponential backoff and jitter.
///
/// ## Algorithm: Exponential Backoff with Jitter
///
/// The reconnection manager implements exponential backoff to avoid overwhelming
/// the server during recovery.
///
/// ### Formula
///
/// ```
/// delay = min(baseDelay * 2^(attempt-1) * (1 + jitter), maxDelay)
/// jitter = random(0, 0.3)  // 30% random variation
/// ```
///
/// ### Example Delays (baseDelay=1s, maxDelay=60s)
///
/// - Attempt 1: ~1s (1 * 2^0 * 1.0-1.3)
/// - Attempt 2: ~2-2.6s (1 * 2^1 * 1.0-1.3)
/// - Attempt 3: ~4-5.2s (1 * 2^2 * 1.0-1.3)
/// - Attempt 4: ~8-10.4s (1 * 2^3 * 1.0-1.3)
/// - Attempt 5: ~16-20.8s (1 * 2^4 * 1.0-1.3)
/// - Attempt 6+: ~60s (capped at maxDelay)
///
/// ### Benefits
///
/// - **Exponential**: Delays grow exponentially, reducing server load
/// - **Jitter**: Random variation prevents thundering herd
/// - **Capped**: Maximum delay prevents excessive waiting
///
/// ### Usage Example
///
/// ```dart
/// final manager = ReconnectionManager(
///   maxAttempts: 10,
///   baseDelay: Duration(seconds: 2),
///   maxDelay: Duration(seconds: 60),
///   onLog: (msg) => print('[Reconnect] $msg'),
/// );
///
/// try {
///   final success = await manager.attemptReconnection(() async {
///     await tunnel.connect(serverUrl, token);
///   });
///
///   if (success) {
///     print('Reconnected successfully');
///   }
/// } catch (e) {
///   print('Failed to reconnect: $e');
/// }
/// ```
///
/// Requirements: 1.1, 1.2, 1.8, 1.9, 1.10
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'interfaces/tunnel_models.dart';

/// Reconnection manager for automatic reconnection with exponential backoff
///
/// Implements exponential backoff with jitter to handle network failures gracefully.
class ReconnectionManager {
  /// Maximum number of reconnection attempts
  final int maxAttempts;

  /// Base delay for first reconnection attempt
  final Duration baseDelay;

  /// Maximum delay between attempts
  final Duration maxDelay;

  /// Random number generator for jitter
  final Random _random = Random();

  /// Optional logging callback
  final void Function(String message)? onLog;

  /// Current attempt number (0 when not reconnecting)
  int _currentAttempt = 0;

  /// Timer for scheduled reconnection
  Timer? _reconnectTimer;

  /// Whether reconnection has been cancelled
  bool _isCancelled = false;

  /// Timestamp of last reconnection attempt
  DateTime? _lastAttemptTime;

  /// Create a new ReconnectionManager
  ///
  /// @param maxAttempts - Maximum number of reconnection attempts
  /// @param baseDelay - Base delay for exponential backoff
  /// @param maxDelay - Maximum delay between attempts
  /// @param onLog - Optional logging callback
  ReconnectionManager({
    required this.maxAttempts,
    required this.baseDelay,
    required this.maxDelay,
    this.onLog,
  });

  /// Get current attempt number
  ///
  /// Returns 0 when not reconnecting, 1-based attempt number during reconnection.
  int get currentAttempt => _currentAttempt;

  /// Check if reconnection is in progress
  bool get isReconnecting => _currentAttempt > 0 && !_isCancelled;

  /// Get last attempt time
  DateTime? get lastAttemptTime => _lastAttemptTime;

  /// Attempt reconnection with exponential backoff
  ///
  /// Calls [connectFn] repeatedly with exponential backoff until:
  /// - Connection succeeds (returns normally)
  /// - Max attempts reached (throws TunnelError)
  /// - Cancelled via [cancel] method
  ///
  /// @param connectFn - Async function that attempts connection
  /// @return true if connection succeeded, false if cancelled
  /// @throws TunnelError if max attempts exceeded
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final success = await manager.attemptReconnection(() async {
  ///     await tunnel.connect(serverUrl, token);
  ///   });
  /// } catch (e) {
  ///   // Max attempts exceeded
  /// }
  /// ```
  Future<bool> attemptReconnection(Future<void> Function() connectFn) async {
    _currentAttempt = 0;
    _isCancelled = false;

    while (_currentAttempt < maxAttempts && !_isCancelled) {
      _currentAttempt++;
      _lastAttemptTime = DateTime.now();

      _log('Reconnection attempt $_currentAttempt of $maxAttempts');

      try {
        await connectFn();
        _log('Reconnection successful after $_currentAttempt attempts');
        _currentAttempt = 0; // Reset on success
        return true;
      } catch (e) {
        _log('Reconnection attempt $_currentAttempt failed: $e');

        if (_isCancelled) {
          _log('Reconnection cancelled by user');
          _currentAttempt = 0;
          return false;
        }

        if (_currentAttempt >= maxAttempts) {
          _log('Max reconnection attempts ($maxAttempts) exceeded');
          _currentAttempt = 0;
          throw TunnelError(
            category: TunnelErrorCategory.network,
            code: TunnelErrorCodes.maxReconnectAttemptsExceeded,
            message: 'Failed to reconnect after $maxAttempts attempts',
            context: {
              'attempts': maxAttempts,
              'lastError': e.toString(),
            },
          );
        }

        // Calculate delay and wait
        final delay = calculateBackoff(_currentAttempt);
        _log('Waiting ${delay.inSeconds}s before next attempt...');

        await _delayWithCancellation(delay);

        if (_isCancelled) {
          _log('Reconnection cancelled during delay');
          _currentAttempt = 0;
          return false;
        }
      }
    }

    _currentAttempt = 0;
    return false;
  }

  /// Calculate exponential backoff delay with jitter
  ///
  /// Formula: min(maxDelay, baseDelay * 2^(attempt-1) * (1 + jitter))
  /// where jitter is a random value between -0.3 and +0.3 (±30%)
  ///
  /// This prevents thundering herd problem where multiple clients
  /// reconnect at exactly the same time.
  Duration calculateBackoff(int attempt) {
    if (attempt <= 0) return baseDelay;

    // Exponential: 2^(attempt-1) * baseDelay
    final exponentialMs = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final exponential = Duration(milliseconds: exponentialMs.toInt());

    // Add jitter: ±30% randomness
    final jitter = _random.nextDouble() * 0.6 - 0.3; // -0.3 to +0.3
    final withJitterMs = exponential.inMilliseconds * (1 + jitter);
    final withJitter = Duration(milliseconds: withJitterMs.toInt());

    // Cap at maxDelay
    return withJitter > maxDelay ? maxDelay : withJitter;
  }

  /// Delay with cancellation support
  Future<void> _delayWithCancellation(Duration delay) async {
    final completer = Completer<void>();

    _reconnectTimer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future;
    } finally {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  /// Cancel ongoing reconnection attempts
  ///
  /// This will stop any pending reconnection and reset the state.
  /// The current [attemptReconnection] call will return false.
  void cancel() {
    _log('Cancelling reconnection attempts');
    _isCancelled = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Reset reconnection state
  ///
  /// Clears attempt counter and cancellation flag.
  /// Use this after a successful manual reconnection.
  void reset() {
    _log('Resetting reconnection state');
    _currentAttempt = 0;
    _isCancelled = false;
    _lastAttemptTime = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Log message if logging is enabled
  void _log(String message) {
    if (onLog != null) {
      onLog!(message);
    } else {
      debugPrint('[ReconnectionManager] $message');
    }
  }

  /// Dispose resources
  void dispose() {
    cancel();
  }
}

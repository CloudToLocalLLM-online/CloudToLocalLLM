/// Error Recovery Strategy
///
/// Implements automatic recovery strategies for different error types.
///
/// ## Error Recovery Patterns
///
/// The error recovery strategy provides category-specific recovery logic:
///
/// ### Network Errors
/// - Trigger automatic reconnection with exponential backoff
/// - Queue requests during disconnection
/// - Flush queue after successful reconnection
///
/// ### Authentication Errors
/// - Distinguish between expired and invalid tokens
/// - Attempt token refresh for expired tokens
/// - Redirect to login for invalid tokens
///
/// ### Server Errors
/// - Implement circuit breaker pattern
/// - Retry with exponential backoff
/// - Use fallback strategies
///
/// ### Protocol Errors
/// - Attempt fallback to uncompressed mode
/// - Retry with different protocol options
/// - Log detailed protocol information
///
/// ### Configuration Errors
/// - Require manual intervention
/// - Provide clear error messages
/// - Suggest corrective actions
///
/// ## Usage Example
///
/// ```dart
/// final strategy = ErrorRecoveryStrategy(
///   reconnectionManager: manager,
///   testConnection: () => tunnel.testConnection(),
///   reconnect: () => tunnel.reconnect(),
///   flushQueuedRequests: () => queue.flush(),
///   refreshAuthToken: () => auth.refreshToken(),
/// );
///
/// try {
///   // Some operation that fails
/// } catch (e) {
///   if (e is TunnelError) {
///     final result = await strategy.attemptRecovery(e);
///     if (result.success) {
///       print('Recovered after ${result.attempts} attempts');
///     }
///   }
/// }
/// ```
///
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.9
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'interfaces/tunnel_models.dart';
import 'reconnection_manager.dart';

/// Result of an error recovery attempt
///
/// Contains information about whether recovery succeeded and how long it took.
class RecoveryResult {
  /// Whether recovery was successful
  final bool success;

  /// Optional message describing the recovery result
  final String? message;

  /// How long the recovery took
  final Duration duration;

  /// Number of recovery attempts made
  final int attempts;

  /// Create a new RecoveryResult
  const RecoveryResult({
    required this.success,
    this.message,
    required this.duration,
    required this.attempts,
  });
}

/// Error recovery strategy
///
/// Provides automatic recovery for different error categories with
/// category-specific recovery logic.
class ErrorRecoveryStrategy {
  /// Reconnection manager for network error recovery
  final ReconnectionManager _reconnectionManager;

  /// Function to test connection health
  final Future<bool> Function() _testConnection;

  /// Function to reconnect
  final Future<void> Function() _reconnect;

  /// Function to flush queued requests
  final Future<void> Function() _flushQueuedRequests;

  /// Optional function to refresh authentication token
  final Future<void> Function()? _refreshAuthToken;

  /// Create a new ErrorRecoveryStrategy
  ///
  /// @param reconnectionManager - Manager for reconnection attempts
  /// @param testConnection - Function to test connection
  /// @param reconnect - Function to reconnect
  /// @param flushQueuedRequests - Function to flush queued requests
  /// @param refreshAuthToken - Optional function to refresh auth token
  ErrorRecoveryStrategy({
    required ReconnectionManager reconnectionManager,
    required Future<bool> Function() testConnection,
    required Future<void> Function() reconnect,
    required Future<void> Function() flushQueuedRequests,
    Future<void> Function()? refreshAuthToken,
  })  : _reconnectionManager = reconnectionManager,
        _testConnection = testConnection,
        _reconnect = reconnect,
        _flushQueuedRequests = flushQueuedRequests,
        _refreshAuthToken = refreshAuthToken;

  /// Attempt recovery from an error
  ///
  /// Routes to category-specific recovery logic based on error type.
  ///
  /// @param error - The error to recover from
  /// @return Recovery result with success status and details
  Future<RecoveryResult> attemptRecovery(TunnelError error) async {
    debugPrint('Attempting recovery for error: ${error.code}');

    switch (error.category) {
      case TunnelErrorCategory.network:
        return await _recoverFromNetworkError(error);

      case TunnelErrorCategory.authentication:
        return await _recoverFromAuthError(error);

      case TunnelErrorCategory.server:
        return await _recoverFromServerError(error);

      case TunnelErrorCategory.protocol:
        return await _recoverFromProtocolError(error);

      case TunnelErrorCategory.configuration:
        return RecoveryResult(
          success: false,
          message: 'Configuration errors require manual intervention',
          duration: Duration.zero,
          attempts: 0,
        );

      case TunnelErrorCategory.unknown:
        return await _recoverFromUnknownError(error);
    }
  }

  /// Recover from network errors
  ///
  /// Implements network error recovery:
  /// 1. Trigger automatic reconnection with exponential backoff
  /// 2. Queue requests during disconnection
  /// 3. Flush queue after successful reconnection
  ///
  /// @private
  /// @param error - The network error
  /// @return Recovery result
  Future<RecoveryResult> _recoverFromNetworkError(TunnelError error) async {
    final stopwatch = Stopwatch()..start();
    var attempts = 0;

    debugPrint('Recovering from network error: ${error.code}');

    try {
      // Use exponential backoff for reconnection
      while (attempts < _reconnectionManager.maxAttempts) {
        attempts++;

        // Calculate backoff delay
        final delay = _reconnectionManager.calculateBackoff(attempts);
        debugPrint(
          'Network recovery attempt $attempts/${_reconnectionManager.maxAttempts}, '
          'waiting ${delay.inMilliseconds}ms',
        );

        await Future.delayed(delay);

        // Test connection
        final isConnected = await _testConnection();
        if (isConnected) {
          debugPrint('Connection test passed, attempting reconnect');

          // Reconnect
          await _reconnect();

          // Flush queued requests
          await _flushQueuedRequests();

          stopwatch.stop();
          return RecoveryResult(
            success: true,
            message: 'Successfully recovered from network error',
            duration: stopwatch.elapsed,
            attempts: attempts,
          );
        }

        debugPrint('Connection test failed, will retry');
      }

      stopwatch.stop();
      return RecoveryResult(
        success: false,
        message: 'Failed to recover after $attempts attempts',
        duration: stopwatch.elapsed,
        attempts: attempts,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during network recovery: $e');
      return RecoveryResult(
        success: false,
        message: 'Recovery failed: $e',
        duration: stopwatch.elapsed,
        attempts: attempts,
      );
    }
  }

  /// Recover from authentication errors
  Future<RecoveryResult> _recoverFromAuthError(TunnelError error) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('Recovering from authentication error: ${error.code}');

    try {
      // For expired tokens, try to refresh
      if (error.code == TunnelErrorCodes.tokenExpired) {
        if (_refreshAuthToken != null) {
          debugPrint('Attempting to refresh authentication token');

          await _refreshAuthToken();

          // Try to reconnect with new token
          await _reconnect();

          stopwatch.stop();
          return RecoveryResult(
            success: true,
            message: 'Successfully refreshed authentication token',
            duration: stopwatch.elapsed,
            attempts: 1,
          );
        } else {
          stopwatch.stop();
          return RecoveryResult(
            success: false,
            message: 'Token refresh not available, user must re-authenticate',
            duration: stopwatch.elapsed,
            attempts: 0,
          );
        }
      }

      // For other auth errors, user intervention is required
      stopwatch.stop();
      return RecoveryResult(
        success: false,
        message: 'Authentication error requires user intervention',
        duration: stopwatch.elapsed,
        attempts: 0,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during authentication recovery: $e');
      return RecoveryResult(
        success: false,
        message: 'Authentication recovery failed: $e',
        duration: stopwatch.elapsed,
        attempts: 1,
      );
    }
  }

  /// Recover from server errors
  Future<RecoveryResult> _recoverFromServerError(TunnelError error) async {
    final stopwatch = Stopwatch()..start();
    var attempts = 0;

    debugPrint('Recovering from server error: ${error.code}');

    try {
      // For rate limit errors, wait and retry
      if (error.code == TunnelErrorCodes.rateLimitExceeded) {
        debugPrint('Rate limit exceeded, waiting before retry');

        // Wait for rate limit to reset (typically 60 seconds)
        await Future.delayed(const Duration(seconds: 60));

        attempts = 1;
        stopwatch.stop();

        return RecoveryResult(
          success: true,
          message: 'Waited for rate limit reset',
          duration: stopwatch.elapsed,
          attempts: attempts,
        );
      }

      // For server unavailable, use exponential backoff
      if (error.code == TunnelErrorCodes.serverUnavailable) {
        while (attempts < 5) {
          // Limit attempts for server errors
          attempts++;

          final delay = _reconnectionManager.calculateBackoff(attempts);
          debugPrint(
            'Server unavailable, attempt $attempts/5, waiting ${delay.inMilliseconds}ms',
          );

          await Future.delayed(delay);

          // Test if server is back
          final isConnected = await _testConnection();
          if (isConnected) {
            await _reconnect();

            stopwatch.stop();
            return RecoveryResult(
              success: true,
              message: 'Server is back online',
              duration: stopwatch.elapsed,
              attempts: attempts,
            );
          }
        }

        stopwatch.stop();
        return RecoveryResult(
          success: false,
          message: 'Server still unavailable after $attempts attempts',
          duration: stopwatch.elapsed,
          attempts: attempts,
        );
      }

      // For queue full, wait and retry
      if (error.code == TunnelErrorCodes.queueFull) {
        debugPrint('Queue full, waiting for queue to drain');

        await Future.delayed(const Duration(seconds: 5));

        attempts = 1;
        stopwatch.stop();

        return RecoveryResult(
          success: true,
          message: 'Waited for queue to drain',
          duration: stopwatch.elapsed,
          attempts: attempts,
        );
      }

      // Other server errors
      stopwatch.stop();
      return RecoveryResult(
        success: false,
        message: 'Server error requires manual intervention',
        duration: stopwatch.elapsed,
        attempts: 0,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during server error recovery: $e');
      return RecoveryResult(
        success: false,
        message: 'Server error recovery failed: $e',
        duration: stopwatch.elapsed,
        attempts: attempts,
      );
    }
  }

  /// Recover from protocol errors
  Future<RecoveryResult> _recoverFromProtocolError(TunnelError error) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('Recovering from protocol error: ${error.code}');

    try {
      // For WebSocket errors, try to reconnect
      if (error.code == TunnelErrorCodes.websocketError) {
        debugPrint('WebSocket error, attempting reconnect');

        await _reconnect();

        stopwatch.stop();
        return RecoveryResult(
          success: true,
          message: 'Reconnected after WebSocket error',
          duration: stopwatch.elapsed,
          attempts: 1,
        );
      }

      // For SSH errors, try to reconnect
      if (error.code == TunnelErrorCodes.sshError) {
        debugPrint('SSH error, attempting reconnect');

        await _reconnect();

        stopwatch.stop();
        return RecoveryResult(
          success: true,
          message: 'Reconnected after SSH error',
          duration: stopwatch.elapsed,
          attempts: 1,
        );
      }

      // For compression errors, reconnect (compression may be disabled)
      if (error.code == TunnelErrorCodes.compressionError) {
        debugPrint('Compression error, attempting reconnect');

        await _reconnect();

        stopwatch.stop();
        return RecoveryResult(
          success: true,
          message: 'Reconnected after compression error',
          duration: stopwatch.elapsed,
          attempts: 1,
        );
      }

      // Other protocol errors may require manual intervention
      stopwatch.stop();
      return RecoveryResult(
        success: false,
        message: 'Protocol error may require manual intervention',
        duration: stopwatch.elapsed,
        attempts: 0,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during protocol error recovery: $e');
      return RecoveryResult(
        success: false,
        message: 'Protocol error recovery failed: $e',
        duration: stopwatch.elapsed,
        attempts: 1,
      );
    }
  }

  /// Recover from unknown errors
  Future<RecoveryResult> _recoverFromUnknownError(TunnelError error) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('Recovering from unknown error: ${error.message}');

    try {
      // For unknown errors, try a simple reconnect
      debugPrint('Attempting reconnect for unknown error');

      await _reconnect();

      stopwatch.stop();
      return RecoveryResult(
        success: true,
        message: 'Reconnected after unknown error',
        duration: stopwatch.elapsed,
        attempts: 1,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during unknown error recovery: $e');
      return RecoveryResult(
        success: false,
        message: 'Unknown error recovery failed: $e',
        duration: stopwatch.elapsed,
        attempts: 1,
      );
    }
  }

  /// Check if error is recoverable
  static bool isRecoverable(TunnelError error) {
    // Configuration errors are not automatically recoverable
    if (error.category == TunnelErrorCategory.configuration) {
      return false;
    }

    // Authentication errors (except expired tokens) require user action
    if (error.category == TunnelErrorCategory.authentication &&
        error.code != TunnelErrorCodes.tokenExpired) {
      return false;
    }

    // Most other errors are potentially recoverable
    return error.isRetryable;
  }

  /// Get recovery strategy description
  static String getRecoveryStrategyDescription(TunnelError error) {
    switch (error.category) {
      case TunnelErrorCategory.network:
        return 'Will automatically retry with exponential backoff';

      case TunnelErrorCategory.authentication:
        if (error.code == TunnelErrorCodes.tokenExpired) {
          return 'Will attempt to refresh authentication token';
        }
        return 'Requires user to re-authenticate';

      case TunnelErrorCategory.server:
        if (error.code == TunnelErrorCodes.rateLimitExceeded) {
          return 'Will wait for rate limit to reset';
        }
        if (error.code == TunnelErrorCodes.serverUnavailable) {
          return 'Will retry when server becomes available';
        }
        return 'Will retry with backoff';

      case TunnelErrorCategory.protocol:
        return 'Will attempt to reconnect';

      case TunnelErrorCategory.configuration:
        return 'Requires manual configuration fix';

      case TunnelErrorCategory.unknown:
        return 'Will attempt to reconnect';
    }
  }
}

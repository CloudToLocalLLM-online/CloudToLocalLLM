import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/setup_error.dart';

/// Service for handling error recovery and retry logic in the setup wizard
///
/// This service provides:
/// - Automatic retry mechanisms with exponential backoff
/// - Error recovery strategies based on error type
/// - Context-aware error handling for different setup steps
/// - Error analytics and logging
class SetupErrorRecoveryService extends ChangeNotifier {
  final Map<String, SetupRetryState> _retryStates = {};
  final List<SetupError> _errorHistory = [];
  final StreamController<SetupError> _errorStreamController =
      StreamController<SetupError>.broadcast();

  // Configuration
  static const int _defaultMaxRetries = 3;
  static const Duration _defaultBaseDelay = Duration(seconds: 2);
  static const Duration _defaultMaxDelay = Duration(minutes: 2);

  /// Stream of errors for monitoring and analytics
  Stream<SetupError> get errorStream => _errorStreamController.stream;

  /// Get error history
  List<SetupError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Get retry state for a specific operation
  SetupRetryState getRetryState(String operationId) {
    return _retryStates[operationId] ?? SetupRetryState.initial();
  }

  /// Handle an error and determine recovery strategy
  Future<SetupErrorRecoveryResult> handleError(
    SetupError error, {
    String? operationId,
    int? maxRetries,
    Duration? baseDelay,
    Duration? maxDelay,
  }) async {
    debugPrint(
      '🔧 [ErrorRecovery] Handling error: ${error.code} in step: ${error.setupStep}',
    );

    // Add to error history
    _errorHistory.add(error);
    _errorStreamController.add(error);

    // Limit error history size
    if (_errorHistory.length > 100) {
      _errorHistory.removeAt(0);
    }

    final opId = operationId ?? error.setupStep ?? 'unknown';
    final currentRetryState = _retryStates[opId] ?? SetupRetryState.initial();

    // Determine if we should retry
    final shouldRetry = _shouldRetryError(
      error,
      currentRetryState,
      maxRetries ?? _defaultMaxRetries,
    );

    if (shouldRetry) {
      // Update retry state
      final newRetryState = currentRetryState.nextRetryAttempt(
        maxAttempts: maxRetries ?? _defaultMaxRetries,
        baseDelay: baseDelay ?? _defaultBaseDelay,
        maxDelay: maxDelay ?? _defaultMaxDelay,
        error: error,
      );
      _retryStates[opId] = newRetryState;

      debugPrint(
        '🔧 [ErrorRecovery] Will retry operation $opId (attempt ${newRetryState.attemptCount})',
      );

      return SetupErrorRecoveryResult.retry(
        error: error,
        retryState: newRetryState,
        recoveryStrategy: _getRecoveryStrategy(error),
      );
    } else {
      debugPrint(
        '🔧 [ErrorRecovery] Will not retry operation $opId (max attempts reached or not retryable)',
      );

      return SetupErrorRecoveryResult.failed(
        error: error,
        retryState: currentRetryState,
        recoveryStrategy: _getRecoveryStrategy(error),
      );
    }
  }

  /// Execute an operation with automatic retry logic
  Future<T> executeWithRetry<T>(
    String operationId,
    Future<T> Function() operation, {
    int maxRetries = _defaultMaxRetries,
    Duration baseDelay = _defaultBaseDelay,
    Duration maxDelay = _defaultMaxDelay,
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final result = await operation();

      // Success - reset retry state
      _retryStates[operationId] = SetupRetryState.initial();
      debugPrint('🔧 [ErrorRecovery] Operation $operationId succeeded');

      return result;
    } catch (exception) {
      // Create setup error from exception
      final setupError = SetupError.fromException(
        exception,
        setupStep: setupStep,
        context: context,
      );

      // Handle the error
      final recoveryResult = await handleError(
        setupError,
        operationId: operationId,
        maxRetries: maxRetries,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
      );

      if (recoveryResult.shouldRetry) {
        // Wait for retry delay
        if (recoveryResult.retryState.timeUntilNextRetry != null &&
            recoveryResult.retryState.timeUntilNextRetry! > Duration.zero) {
          debugPrint(
            '🔧 [ErrorRecovery] Waiting ${recoveryResult.retryState.timeUntilNextRetry} before retry',
          );
          await Future.delayed(recoveryResult.retryState.timeUntilNextRetry!);
        }

        // Recursive retry
        return executeWithRetry<T>(
          operationId,
          operation,
          maxRetries: maxRetries,
          baseDelay: baseDelay,
          maxDelay: maxDelay,
          setupStep: setupStep,
          context: context,
        );
      } else {
        // No more retries - rethrow the original exception
        throw SetupErrorException(setupError);
      }
    }
  }

  /// Reset retry state for an operation
  void resetRetryState(String operationId) {
    _retryStates.remove(operationId);
    debugPrint(
      '🔧 [ErrorRecovery] Reset retry state for operation: $operationId',
    );
  }

  /// Reset all retry states
  void resetAllRetryStates() {
    _retryStates.clear();
    debugPrint('🔧 [ErrorRecovery] Reset all retry states');
  }

  /// Get error statistics
  SetupErrorStatistics getErrorStatistics() {
    final errorsByType = <SetupErrorType, int>{};
    final errorsByStep = <String, int>{};
    var totalRetryableErrors = 0;
    var totalCriticalErrors = 0;

    for (final error in _errorHistory) {
      // Count by type
      errorsByType[error.type] = (errorsByType[error.type] ?? 0) + 1;

      // Count by step
      if (error.setupStep != null) {
        errorsByStep[error.setupStep!] =
            (errorsByStep[error.setupStep!] ?? 0) + 1;
      }

      // Count special categories
      if (error.isRetryable) totalRetryableErrors++;
      if (error.isCritical) totalCriticalErrors++;
    }

    return SetupErrorStatistics(
      totalErrors: _errorHistory.length,
      errorsByType: errorsByType,
      errorsByStep: errorsByStep,
      retryableErrors: totalRetryableErrors,
      criticalErrors: totalCriticalErrors,
      activeRetryOperations: _retryStates.length,
    );
  }

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
    debugPrint('🔧 [ErrorRecovery] Cleared error history');
    notifyListeners();
  }

  /// Determine if an error should be retried
  bool _shouldRetryError(
    SetupError error,
    SetupRetryState retryState,
    int maxRetries,
  ) {
    // Don't retry if error is not retryable
    if (!error.isRetryable) return false;

    // Don't retry if max attempts reached
    if (retryState.hasReachedMaxAttempts ||
        retryState.attemptCount >= maxRetries) {
      return false;
    }

    // Don't retry critical errors immediately
    if (error.isCritical && retryState.attemptCount > 0) {
      return false;
    }

    return true;
  }

  /// Get recovery strategy for an error
  SetupErrorRecoveryStrategy _getRecoveryStrategy(SetupError error) {
    switch (error.type) {
      case SetupErrorType.platformDetection:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.manualIntervention,
          description: 'Allow manual platform selection',
          actions: [
            'Show manual platform selection',
            'Provide platform detection troubleshooting',
          ],
        );

      case SetupErrorType.containerCreation:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.automaticRetry,
          description: 'Retry container creation with exponential backoff',
          actions: [
            'Wait and retry',
            'Check service status',
            'Provide alternative setup method',
          ],
        );

      case SetupErrorType.downloadFailure:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.alternativeMethod,
          description: 'Provide alternative download methods',
          actions: [
            'Offer direct download links',
            'Suggest different browser',
            'Provide manual download instructions',
          ],
        );

      case SetupErrorType.tunnelConfiguration:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.guidedTroubleshooting,
          description: 'Guide user through network troubleshooting',
          actions: [
            'Check firewall settings',
            'Verify port availability',
            'Provide manual configuration',
          ],
        );

      case SetupErrorType.connectionValidation:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.guidedTroubleshooting,
          description: 'Guide user through connection troubleshooting',
          actions: [
            'Verify desktop client is running',
            'Check network connectivity',
            'Provide manual connection steps',
          ],
        );

      case SetupErrorType.authentication:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.userAction,
          description: 'Require user to re-authenticate',
          actions: [
            'Redirect to login',
            'Clear authentication cache',
            'Provide authentication troubleshooting',
          ],
        );

      case SetupErrorType.networkError:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.automaticRetry,
          description: 'Retry with network troubleshooting guidance',
          actions: [
            'Wait and retry',
            'Provide network troubleshooting',
            'Suggest offline alternatives',
          ],
        );

      default:
        return SetupErrorRecoveryStrategy(
          type: SetupErrorRecoveryType.manualIntervention,
          description: 'Require manual intervention',
          actions: [
            'Provide troubleshooting steps',
            'Offer support contact',
            'Allow skip if possible',
          ],
        );
    }
  }

  @override
  void dispose() {
    _errorStreamController.close();
    super.dispose();
  }
}

/// Result of error recovery handling
@immutable
class SetupErrorRecoveryResult {
  final SetupError error;
  final SetupRetryState retryState;
  final SetupErrorRecoveryStrategy recoveryStrategy;
  final bool shouldRetry;

  const SetupErrorRecoveryResult({
    required this.error,
    required this.retryState,
    required this.recoveryStrategy,
    required this.shouldRetry,
  });

  factory SetupErrorRecoveryResult.retry({
    required SetupError error,
    required SetupRetryState retryState,
    required SetupErrorRecoveryStrategy recoveryStrategy,
  }) {
    return SetupErrorRecoveryResult(
      error: error,
      retryState: retryState,
      recoveryStrategy: recoveryStrategy,
      shouldRetry: true,
    );
  }

  factory SetupErrorRecoveryResult.failed({
    required SetupError error,
    required SetupRetryState retryState,
    required SetupErrorRecoveryStrategy recoveryStrategy,
  }) {
    return SetupErrorRecoveryResult(
      error: error,
      retryState: retryState,
      recoveryStrategy: recoveryStrategy,
      shouldRetry: false,
    );
  }
}

/// Recovery strategy types
enum SetupErrorRecoveryType {
  automaticRetry,
  manualIntervention,
  alternativeMethod,
  guidedTroubleshooting,
  userAction,
}

/// Recovery strategy for handling errors
@immutable
class SetupErrorRecoveryStrategy {
  final SetupErrorRecoveryType type;
  final String description;
  final List<String> actions;

  const SetupErrorRecoveryStrategy({
    required this.type,
    required this.description,
    required this.actions,
  });
}

/// Error statistics for analytics
@immutable
class SetupErrorStatistics {
  final int totalErrors;
  final Map<SetupErrorType, int> errorsByType;
  final Map<String, int> errorsByStep;
  final int retryableErrors;
  final int criticalErrors;
  final int activeRetryOperations;

  const SetupErrorStatistics({
    required this.totalErrors,
    required this.errorsByType,
    required this.errorsByStep,
    required this.retryableErrors,
    required this.criticalErrors,
    required this.activeRetryOperations,
  });

  /// Get most common error type
  SetupErrorType? get mostCommonErrorType {
    if (errorsByType.isEmpty) return null;

    var maxCount = 0;
    SetupErrorType? mostCommon;

    for (final entry in errorsByType.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostCommon = entry.key;
      }
    }

    return mostCommon;
  }

  /// Get most problematic setup step
  String? get mostProblematicStep {
    if (errorsByStep.isEmpty) return null;

    var maxCount = 0;
    String? mostProblematic;

    for (final entry in errorsByStep.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostProblematic = entry.key;
      }
    }

    return mostProblematic;
  }

  /// Convert to JSON for analytics
  Map<String, dynamic> toJson() {
    return {
      'totalErrors': totalErrors,
      'errorsByType': errorsByType.map((k, v) => MapEntry(k.name, v)),
      'errorsByStep': errorsByStep,
      'retryableErrors': retryableErrors,
      'criticalErrors': criticalErrors,
      'activeRetryOperations': activeRetryOperations,
      'mostCommonErrorType': mostCommonErrorType?.name,
      'mostProblematicStep': mostProblematicStep,
    };
  }
}

/// Exception wrapper for setup errors
class SetupErrorException implements Exception {
  final SetupError setupError;

  const SetupErrorException(this.setupError);

  @override
  String toString() {
    return 'SetupErrorException: ${setupError.userFriendlyMessage}';
  }
}

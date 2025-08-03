/// LLM Error Handler Service
///
/// Provides provider-specific error handling, retry strategies, and recovery mechanisms
/// for LLM communication failures. Implements exponential backoff and intelligent
/// error classification.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/llm_communication_error.dart';
import 'provider_discovery_service.dart';

/// Retry configuration for different error types
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Duration jitter;

  const RetryConfig({
    required this.maxRetries,
    required this.initialDelay,
    this.backoffMultiplier = 2.0,
    required this.maxDelay,
    this.jitter = const Duration(milliseconds: 100),
  });

  /// Default retry configuration
  static const RetryConfig defaultConfig = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
    jitter: Duration(milliseconds: 100),
  );

  /// Aggressive retry for critical operations
  static const RetryConfig aggressive = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 15),
    jitter: Duration(milliseconds: 50),
  );

  /// Conservative retry for non-critical operations
  static const RetryConfig conservative = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 3.0,
    maxDelay: Duration(minutes: 1),
    jitter: Duration(milliseconds: 200),
  );
}

/// Provider-specific error handling configuration
class ProviderErrorConfig {
  final Map<LLMCommunicationErrorType, RetryConfig> retryConfigs;
  final Set<LLMCommunicationErrorType> retryableErrors;
  final Set<LLMCommunicationErrorType> switchProviderErrors;
  final Duration healthCheckInterval;

  const ProviderErrorConfig({
    required this.retryConfigs,
    required this.retryableErrors,
    required this.switchProviderErrors,
    this.healthCheckInterval = const Duration(minutes: 5),
  });

  /// Get retry config for specific error type
  RetryConfig getRetryConfig(LLMCommunicationErrorType errorType) {
    return retryConfigs[errorType] ?? RetryConfig.defaultConfig;
  }

  /// Check if error type is retryable
  bool isRetryable(LLMCommunicationErrorType errorType) {
    return retryableErrors.contains(errorType);
  }

  /// Check if error should trigger provider switch
  bool shouldSwitchProvider(LLMCommunicationErrorType errorType) {
    return switchProviderErrors.contains(errorType);
  }
}

/// LLM Error Handler Service
class LLMErrorHandler extends ChangeNotifier {
  final ProviderDiscoveryService? _providerDiscovery;
  final Map<ProviderType, ProviderErrorConfig> _providerConfigs;
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, List<LLMCommunicationError>> _errorHistory = {};
  final Random _random = Random();

  LLMErrorHandler({
    ProviderDiscoveryService? providerDiscovery,
    Map<ProviderType, ProviderErrorConfig>? providerConfigs,
  }) : _providerDiscovery = providerDiscovery,
       _providerConfigs = providerConfigs ?? _getDefaultProviderConfigs();

  /// Handle LLM communication error with provider-specific logic
  Future<T?> handleError<T>(
    LLMCommunicationError error,
    Future<T> Function() operation, {
    String? providerId,
    ProviderType? providerType,
    bool allowProviderSwitch = true,
  }) async {
    debugPrint('Handling LLM error: ${error.type} for provider: $providerId');

    // Record error for analytics
    _recordError(error, providerId);

    // Get provider-specific configuration
    final config = _getProviderConfig(providerType);

    // Check if error is retryable
    if (config.isRetryable(error.type) &&
        error.retryCount < config.getRetryConfig(error.type).maxRetries) {
      return await _retryWithBackoff(error, operation, config);
    }

    // Check if we should switch providers
    if (allowProviderSwitch &&
        config.shouldSwitchProvider(error.type) &&
        _providerDiscovery != null) {
      return await _attemptProviderSwitch(error, operation, providerId);
    }

    // No recovery possible, return null or rethrow
    debugPrint('No recovery strategy available for error: ${error.type}');
    return null;
  }

  /// Execute operation with comprehensive error handling
  Future<T> executeWithErrorHandling<T>(
    Future<T> Function() operation, {
    String? providerId,
    ProviderType? providerType,
    String? requestId,
    bool allowProviderSwitch = true,
    Duration? timeout,
  }) async {
    try {
      // Execute operation with timeout if specified
      if (timeout != null) {
        return await operation().timeout(timeout);
      } else {
        return await operation();
      }
    } catch (exception) {
      // Convert exception to LLMCommunicationError
      final error = exception is LLMCommunicationError
          ? exception
          : LLMCommunicationError.fromException(
              exception is Exception
                  ? exception
                  : Exception(exception.toString()),
              providerId: providerId,
              requestId: requestId,
              timeout: timeout,
            );

      // Attempt error handling and recovery
      final result = await handleError<T>(
        error,
        operation,
        providerId: providerId,
        providerType: providerType,
        allowProviderSwitch: allowProviderSwitch,
      );

      if (result != null) {
        return result;
      }

      // If no recovery was possible, rethrow the original error
      throw error;
    }
  }

  /// Retry operation with exponential backoff
  Future<T?> _retryWithBackoff<T>(
    LLMCommunicationError error,
    Future<T> Function() operation,
    ProviderErrorConfig config,
  ) async {
    final retryConfig = config.getRetryConfig(error.type);
    final newRetryCount = error.retryCount + 1;

    // Calculate delay with exponential backoff and jitter
    final baseDelay = Duration(
      milliseconds:
          (retryConfig.initialDelay.inMilliseconds *
                  pow(retryConfig.backoffMultiplier, newRetryCount - 1))
              .round(),
    );

    final delayWithJitter = Duration(
      milliseconds: min(
        baseDelay.inMilliseconds +
            _random.nextInt(retryConfig.jitter.inMilliseconds),
        retryConfig.maxDelay.inMilliseconds,
      ),
    );

    debugPrint(
      'Retrying operation (attempt $newRetryCount/${retryConfig.maxRetries}) after ${delayWithJitter.inMilliseconds}ms',
    );

    // Wait before retry
    await Future.delayed(delayWithJitter);

    try {
      return await operation();
    } catch (exception) {
      // Convert and update retry count
      final retryError = exception is LLMCommunicationError
          ? exception.withRetryCount(newRetryCount)
          : LLMCommunicationError.fromException(
              exception is Exception
                  ? exception
                  : Exception(exception.toString()),
              retryCount: newRetryCount,
            );

      // Recursively handle the retry error
      return await handleError<T>(retryError, operation);
    }
  }

  /// Attempt to switch to a different provider
  Future<T?> _attemptProviderSwitch<T>(
    LLMCommunicationError error,
    Future<T> Function() operation,
    String? currentProviderId,
  ) async {
    if (_providerDiscovery == null) {
      debugPrint('Provider discovery not available for provider switch');
      return null;
    }

    // Get available providers excluding the current one
    final availableProviders = _providerDiscovery
        .getAvailableProviders()
        .where((provider) => provider.id != currentProviderId)
        .toList();

    if (availableProviders.isEmpty) {
      debugPrint('No alternative providers available for switch');
      return null;
    }

    // Try each available provider
    for (final provider in availableProviders) {
      try {
        debugPrint(
          'Attempting provider switch to: ${provider.name} (${provider.id})',
        );

        // This would need to be implemented with actual provider switching logic
        // For now, we'll just attempt the operation again
        return await operation();
      } catch (exception) {
        debugPrint('Provider switch to ${provider.name} failed: $exception');
        continue;
      }
    }

    debugPrint('All provider switch attempts failed');
    return null;
  }

  /// Record error for analytics and monitoring
  void _recordError(LLMCommunicationError error, String? providerId) {
    final key = providerId ?? 'unknown';

    // Update error counts
    _errorCounts[key] = (_errorCounts[key] ?? 0) + 1;
    _lastErrorTimes[key] = DateTime.now();

    // Add to error history (keep last 100 errors per provider)
    if (!_errorHistory.containsKey(key)) {
      _errorHistory[key] = [];
    }

    _errorHistory[key]!.add(error);
    if (_errorHistory[key]!.length > 100) {
      _errorHistory[key]!.removeAt(0);
    }

    // Notify listeners of error state change
    notifyListeners();
  }

  /// Get provider-specific error configuration
  ProviderErrorConfig _getProviderConfig(ProviderType? providerType) {
    if (providerType != null && _providerConfigs.containsKey(providerType)) {
      return _providerConfigs[providerType]!;
    }
    return _providerConfigs[ProviderType.ollama]!; // Default to Ollama config
  }

  /// Get error statistics for a provider
  Map<String, dynamic> getErrorStats(String? providerId) {
    final key = providerId ?? 'unknown';
    final errors = _errorHistory[key] ?? [];

    if (errors.isEmpty) {
      return {
        'totalErrors': 0,
        'lastError': null,
        'errorRate': 0.0,
        'commonErrors': <String>[],
      };
    }

    // Calculate error type distribution
    final errorTypeCounts = <LLMCommunicationErrorType, int>{};
    for (final error in errors) {
      errorTypeCounts[error.type] = (errorTypeCounts[error.type] ?? 0) + 1;
    }

    // Get most common errors
    final commonErrors = errorTypeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalErrors': _errorCounts[key] ?? 0,
      'lastError': _lastErrorTimes[key]?.toIso8601String(),
      'recentErrors': errors.length,
      'errorTypes': errorTypeCounts.map(
        (k, v) => MapEntry(k.toString().split('.').last, v),
      ),
      'commonErrors': commonErrors
          .take(5)
          .map((e) => e.key.toString().split('.').last)
          .toList(),
    };
  }

  /// Get overall error statistics
  Map<String, dynamic> getOverallStats() {
    final totalErrors = _errorCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final providersWithErrors = _errorCounts.keys.length;

    return {
      'totalErrors': totalErrors,
      'providersWithErrors': providersWithErrors,
      'errorCounts': Map<String, int>.from(_errorCounts),
      'lastErrorTimes': _lastErrorTimes.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
    };
  }

  /// Clear error history for a provider
  void clearErrorHistory(String? providerId) {
    final key = providerId ?? 'unknown';
    _errorCounts.remove(key);
    _lastErrorTimes.remove(key);
    _errorHistory.remove(key);
    notifyListeners();
  }

  /// Clear all error history
  void clearAllErrorHistory() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _errorHistory.clear();
    notifyListeners();
  }

  /// Get default provider configurations
  static Map<ProviderType, ProviderErrorConfig> _getDefaultProviderConfigs() {
    // Define retryable error types
    const retryableErrors = {
      LLMCommunicationErrorType.connectionTimeout,
      LLMCommunicationErrorType.requestTimeout,
      LLMCommunicationErrorType.responseTimeout,
      LLMCommunicationErrorType.networkError,
      LLMCommunicationErrorType.connectionLost,
      LLMCommunicationErrorType.responseCorrupted,
    };

    // Define errors that should trigger provider switch
    const switchProviderErrors = {
      LLMCommunicationErrorType.providerNotFound,
      LLMCommunicationErrorType.providerUnavailable,
      LLMCommunicationErrorType.providerTimeout,
      LLMCommunicationErrorType.modelNotFound,
      LLMCommunicationErrorType.modelNotLoaded,
    };

    // Retry configurations for different error types
    final retryConfigs = <LLMCommunicationErrorType, RetryConfig>{
      LLMCommunicationErrorType.connectionTimeout: RetryConfig.aggressive,
      LLMCommunicationErrorType.requestTimeout: RetryConfig.conservative,
      LLMCommunicationErrorType.networkError: RetryConfig.defaultConfig,
      LLMCommunicationErrorType.responseTimeout: RetryConfig.conservative,
      LLMCommunicationErrorType.connectionLost: RetryConfig.aggressive,
    };

    // Create provider-specific configurations
    return {
      ProviderType.ollama: ProviderErrorConfig(
        retryConfigs: retryConfigs,
        retryableErrors: retryableErrors,
        switchProviderErrors: switchProviderErrors,
        healthCheckInterval: const Duration(minutes: 5),
      ),
      ProviderType.lmStudio: ProviderErrorConfig(
        retryConfigs: retryConfigs,
        retryableErrors: retryableErrors,
        switchProviderErrors: switchProviderErrors,
        healthCheckInterval: const Duration(minutes: 3),
      ),
      ProviderType.openAICompatible: ProviderErrorConfig(
        retryConfigs: retryConfigs,
        retryableErrors: retryableErrors,
        switchProviderErrors: switchProviderErrors,
        healthCheckInterval: const Duration(minutes: 2),
      ),
      ProviderType.custom: ProviderErrorConfig(
        retryConfigs: retryConfigs,
        retryableErrors: retryableErrors,
        switchProviderErrors: switchProviderErrors,
        healthCheckInterval: const Duration(minutes: 10),
      ),
    };
  }

  @override
  void dispose() {
    // Clean up resources
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _errorHistory.clear();
    super.dispose();
  }
}

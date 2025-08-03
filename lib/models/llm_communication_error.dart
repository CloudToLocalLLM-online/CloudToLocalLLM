/// LLM Communication Error Model
///
/// Comprehensive error classification system for LLM communication failures.
/// Provides structured error information with context and recovery suggestions.
library;

/// LLM communication error types
enum LLMCommunicationErrorType {
  // Provider-related errors
  providerNotFound,
  providerUnavailable,
  providerTimeout,
  providerConfigurationError,

  // Connection errors
  connectionTimeout,
  connectionRefused,
  connectionLost,
  networkError,

  // Request errors
  requestTimeout,
  requestTooLarge,
  requestMalformed,
  requestRateLimited,

  // Authentication errors
  authenticationFailed,
  authorizationDenied,
  tokenExpired,

  // Model errors
  modelNotFound,
  modelNotLoaded,
  modelError,
  modelUnsupported,

  // Response errors
  responseTimeout,
  responseCorrupted,
  responseTooLarge,
  responseParsingError,

  // Tunnel errors
  tunnelDisconnected,
  tunnelError,
  bridgeUnavailable,

  // System errors
  systemError,
  memoryError,
  diskSpaceError,

  // Unknown errors
  unknown,
}

/// Error severity levels
enum ErrorSeverity {
  low, // Minor issues, system can continue
  medium, // Significant issues, some functionality affected
  high, // Major issues, core functionality affected
  critical, // System-breaking issues, immediate attention required
}

/// Error recovery strategies
enum RecoveryStrategy {
  retry, // Simple retry
  retryWithBackoff, // Retry with exponential backoff
  switchProvider, // Try different provider
  fallbackMode, // Use fallback functionality
  userIntervention, // Requires user action
  systemRestart, // Requires system restart
  noRecovery, // No automatic recovery possible
}

/// LLM Communication Error class
class LLMCommunicationError implements Exception {
  final LLMCommunicationErrorType type;
  final String message;
  final String? details;
  final ErrorSeverity severity;
  final RecoveryStrategy recoveryStrategy;
  final Map<String, dynamic>? context;
  final Exception? originalException;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? providerId;
  final String? requestId;
  final int? httpStatusCode;
  final Duration? timeout;
  final int retryCount;
  final List<String> troubleshootingSteps;

  LLMCommunicationError({
    required this.type,
    required this.message,
    this.details,
    required this.severity,
    required this.recoveryStrategy,
    this.context,
    this.originalException,
    this.stackTrace,
    DateTime? timestamp,
    this.providerId,
    this.requestId,
    this.httpStatusCode,
    this.timeout,
    this.retryCount = 0,
    this.troubleshootingSteps = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from exception
  factory LLMCommunicationError.fromException(
    Exception exception, {
    LLMCommunicationErrorType? type,
    String? message,
    String? details,
    ErrorSeverity? severity,
    RecoveryStrategy? recoveryStrategy,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
    String? providerId,
    String? requestId,
    int? httpStatusCode,
    Duration? timeout,
    int retryCount = 0,
  }) {
    final inferredType = type ?? _inferErrorTypeFromException(exception);
    final inferredSeverity = severity ?? _inferSeverityFromType(inferredType);
    final inferredRecovery =
        recoveryStrategy ?? _inferRecoveryFromType(inferredType);
    final inferredMessage = message ?? _getDefaultMessageForType(inferredType);
    final troubleshooting = _getTroubleshootingStepsForType(inferredType);

    return LLMCommunicationError(
      type: inferredType,
      message: inferredMessage,
      details: details ?? exception.toString(),
      severity: inferredSeverity,
      recoveryStrategy: inferredRecovery,
      context: context,
      originalException: exception,
      stackTrace: stackTrace,
      providerId: providerId,
      requestId: requestId,
      httpStatusCode: httpStatusCode,
      timeout: timeout,
      retryCount: retryCount,
      troubleshootingSteps: troubleshooting,
    );
  }

  /// Create provider not found error
  factory LLMCommunicationError.providerNotFound({
    String? providerId,
    String? requestId,
    Map<String, dynamic>? context,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.providerNotFound,
      message: 'LLM provider not found or not available',
      details: providerId != null ? 'Provider ID: $providerId' : null,
      severity: ErrorSeverity.high,
      recoveryStrategy: RecoveryStrategy.switchProvider,
      context: context,
      providerId: providerId,
      requestId: requestId,
      troubleshootingSteps: [
        'Check if the LLM provider is running',
        'Verify provider configuration',
        'Try switching to a different provider',
        'Check network connectivity',
      ],
    );
  }

  /// Create connection timeout error
  factory LLMCommunicationError.connectionTimeout({
    Duration? timeout,
    String? providerId,
    String? requestId,
    Map<String, dynamic>? context,
    int retryCount = 0,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.connectionTimeout,
      message: 'Connection to LLM provider timed out',
      details: timeout != null ? 'Timeout: ${timeout.inSeconds}s' : null,
      severity: ErrorSeverity.medium,
      recoveryStrategy: RecoveryStrategy.retryWithBackoff,
      context: context,
      providerId: providerId,
      requestId: requestId,
      timeout: timeout,
      retryCount: retryCount,
      troubleshootingSteps: [
        'Check network connectivity',
        'Verify provider is responding',
        'Try increasing timeout duration',
        'Check for network congestion',
      ],
    );
  }

  /// Create request timeout error
  factory LLMCommunicationError.requestTimeout({
    Duration? timeout,
    String? providerId,
    String? requestId,
    Map<String, dynamic>? context,
    int retryCount = 0,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.requestTimeout,
      message: 'LLM request timed out',
      details: timeout != null ? 'Timeout: ${timeout.inSeconds}s' : null,
      severity: ErrorSeverity.medium,
      recoveryStrategy: RecoveryStrategy.retryWithBackoff,
      context: context,
      providerId: providerId,
      requestId: requestId,
      timeout: timeout,
      retryCount: retryCount,
      troubleshootingSteps: [
        'Try a simpler request',
        'Check if model is loaded',
        'Increase request timeout',
        'Verify provider performance',
      ],
    );
  }

  /// Create tunnel disconnected error
  factory LLMCommunicationError.tunnelDisconnected({
    String? requestId,
    Map<String, dynamic>? context,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.tunnelDisconnected,
      message: 'Tunnel connection to desktop client lost',
      severity: ErrorSeverity.high,
      recoveryStrategy: RecoveryStrategy.userIntervention,
      context: context,
      requestId: requestId,
      troubleshootingSteps: [
        'Check desktop client connection',
        'Verify internet connectivity',
        'Restart desktop client',
        'Check firewall settings',
      ],
    );
  }

  /// Create model not found error
  factory LLMCommunicationError.modelNotFound({
    String? modelName,
    String? providerId,
    String? requestId,
    Map<String, dynamic>? context,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.modelNotFound,
      message: 'Requested model not found',
      details: modelName != null ? 'Model: $modelName' : null,
      severity: ErrorSeverity.medium,
      recoveryStrategy: RecoveryStrategy.userIntervention,
      context: context,
      providerId: providerId,
      requestId: requestId,
      troubleshootingSteps: [
        'Check available models',
        'Download the required model',
        'Verify model name spelling',
        'Try a different model',
      ],
    );
  }

  /// Create authentication failed error
  factory LLMCommunicationError.authenticationFailed({
    String? providerId,
    String? requestId,
    int? httpStatusCode,
    Map<String, dynamic>? context,
  }) {
    return LLMCommunicationError(
      type: LLMCommunicationErrorType.authenticationFailed,
      message: 'Authentication with LLM provider failed',
      severity: ErrorSeverity.high,
      recoveryStrategy: RecoveryStrategy.userIntervention,
      context: context,
      providerId: providerId,
      requestId: requestId,
      httpStatusCode: httpStatusCode,
      troubleshootingSteps: [
        'Check API credentials',
        'Verify authentication tokens',
        'Check provider access permissions',
        'Update authentication configuration',
      ],
    );
  }

  /// Check if error is retryable
  bool get isRetryable {
    switch (recoveryStrategy) {
      case RecoveryStrategy.retry:
      case RecoveryStrategy.retryWithBackoff:
        return true;
      default:
        return false;
    }
  }

  /// Check if error allows provider switching
  bool get allowsProviderSwitch {
    switch (recoveryStrategy) {
      case RecoveryStrategy.switchProvider:
      case RecoveryStrategy.fallbackMode:
        return true;
      default:
        return false;
    }
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case LLMCommunicationErrorType.providerNotFound:
        return 'AI provider is not available. Please check your connection.';
      case LLMCommunicationErrorType.connectionTimeout:
        return 'Connection timed out. Please try again.';
      case LLMCommunicationErrorType.requestTimeout:
        return 'Request took too long. Please try a simpler query.';
      case LLMCommunicationErrorType.tunnelDisconnected:
        return 'Connection to desktop client lost. Please check your connection.';
      case LLMCommunicationErrorType.modelNotFound:
        return 'The requested AI model is not available.';
      case LLMCommunicationErrorType.authenticationFailed:
        return 'Authentication failed. Please check your credentials.';
      default:
        return message;
    }
  }

  /// Create a copy with updated retry count
  LLMCommunicationError withRetryCount(int newRetryCount) {
    return LLMCommunicationError(
      type: type,
      message: message,
      details: details,
      severity: severity,
      recoveryStrategy: recoveryStrategy,
      context: context,
      originalException: originalException,
      stackTrace: stackTrace,
      timestamp: timestamp,
      providerId: providerId,
      requestId: requestId,
      httpStatusCode: httpStatusCode,
      timeout: timeout,
      retryCount: newRetryCount,
      troubleshootingSteps: troubleshootingSteps,
    );
  }

  /// Convert to JSON for logging/serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'message': message,
      'details': details,
      'severity': severity.toString().split('.').last,
      'recoveryStrategy': recoveryStrategy.toString().split('.').last,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'providerId': providerId,
      'requestId': requestId,
      'httpStatusCode': httpStatusCode,
      'timeout': timeout?.inMilliseconds,
      'retryCount': retryCount,
      'troubleshootingSteps': troubleshootingSteps,
      'userFriendlyMessage': userFriendlyMessage,
      'isRetryable': isRetryable,
      'allowsProviderSwitch': allowsProviderSwitch,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('LLMCommunicationError(');
    buffer.write('type: $type, ');
    buffer.write('message: $message');
    if (details != null) buffer.write(', details: $details');
    if (providerId != null) buffer.write(', providerId: $providerId');
    if (requestId != null) buffer.write(', requestId: $requestId');
    if (retryCount > 0) buffer.write(', retryCount: $retryCount');
    buffer.write(')');
    return buffer.toString();
  }

  /// Infer error type from exception
  static LLMCommunicationErrorType _inferErrorTypeFromException(
    Exception exception,
  ) {
    final exceptionString = exception.toString().toLowerCase();

    if (exceptionString.contains('timeout')) {
      return LLMCommunicationErrorType.connectionTimeout;
    }
    if (exceptionString.contains('connection refused') ||
        exceptionString.contains('connection failed')) {
      return LLMCommunicationErrorType.connectionRefused;
    }
    if (exceptionString.contains('network') ||
        exceptionString.contains('socket')) {
      return LLMCommunicationErrorType.networkError;
    }
    if (exceptionString.contains('auth')) {
      return LLMCommunicationErrorType.authenticationFailed;
    }
    if (exceptionString.contains('model')) {
      return LLMCommunicationErrorType.modelError;
    }
    if (exceptionString.contains('tunnel') ||
        exceptionString.contains('bridge')) {
      return LLMCommunicationErrorType.tunnelError;
    }

    return LLMCommunicationErrorType.unknown;
  }

  /// Infer severity from error type
  static ErrorSeverity _inferSeverityFromType(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.memoryError:
      case LLMCommunicationErrorType.diskSpaceError:
        return ErrorSeverity.critical;

      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.tunnelDisconnected:
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.bridgeUnavailable:
        return ErrorSeverity.high;

      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.modelNotFound:
      case LLMCommunicationErrorType.responseTimeout:
        return ErrorSeverity.medium;

      default:
        return ErrorSeverity.low;
    }
  }

  /// Infer recovery strategy from error type
  static RecoveryStrategy _inferRecoveryFromType(
    LLMCommunicationErrorType type,
  ) {
    switch (type) {
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
      case LLMCommunicationErrorType.networkError:
        return RecoveryStrategy.retryWithBackoff;

      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return RecoveryStrategy.switchProvider;

      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.modelNotFound:
      case LLMCommunicationErrorType.tunnelDisconnected:
        return RecoveryStrategy.userIntervention;

      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.memoryError:
        return RecoveryStrategy.systemRestart;

      default:
        return RecoveryStrategy.retry;
    }
  }

  /// Get default message for error type
  static String _getDefaultMessageForType(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.providerNotFound:
        return 'LLM provider not found';
      case LLMCommunicationErrorType.connectionTimeout:
        return 'Connection timeout';
      case LLMCommunicationErrorType.requestTimeout:
        return 'Request timeout';
      case LLMCommunicationErrorType.tunnelDisconnected:
        return 'Tunnel disconnected';
      case LLMCommunicationErrorType.modelNotFound:
        return 'Model not found';
      case LLMCommunicationErrorType.authenticationFailed:
        return 'Authentication failed';
      default:
        return 'LLM communication error';
    }
  }

  /// Get troubleshooting steps for error type
  static List<String> _getTroubleshootingStepsForType(
    LLMCommunicationErrorType type,
  ) {
    switch (type) {
      case LLMCommunicationErrorType.providerNotFound:
        return [
          'Check if the LLM provider is running',
          'Verify provider configuration',
          'Try switching to a different provider',
        ];
      case LLMCommunicationErrorType.connectionTimeout:
        return [
          'Check network connectivity',
          'Verify provider is responding',
          'Try increasing timeout duration',
        ];
      case LLMCommunicationErrorType.tunnelDisconnected:
        return [
          'Check desktop client connection',
          'Verify internet connectivity',
          'Restart desktop client',
        ];
      default:
        return ['Check system status', 'Try again later'];
    }
  }
}

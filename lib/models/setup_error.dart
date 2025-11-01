import 'package:flutter/foundation.dart';

/// Enhanced error classification for setup wizard failures
///
/// Provides detailed error types to enable better user feedback and
/// appropriate recovery strategies for different failure scenarios.
enum SetupErrorType {
  /// Platform detection failures
  platformDetection,

  /// Container creation and management failures
  containerCreation,

  /// Download-related failures
  downloadFailure,

  /// Installation guide and validation failures
  installationFailure,

  /// Tunnel configuration and connection failures
  tunnelConfiguration,

  /// Connection validation and testing failures
  connectionValidation,

  /// Authentication and user management failures
  authentication,

  /// Network connectivity issues
  networkError,

  /// Service unavailable or timeout
  serviceTimeout,

  /// Permission or security-related failures
  permissionError,

  /// Configuration or settings errors
  configurationError,

  /// Unknown or unclassified error
  unknown,
}

/// Enhanced setup error with classification and user guidance
@immutable
class SetupError {
  final SetupErrorType type;
  final String code;
  final String message;
  final String? technicalDetails;
  final String userFriendlyMessage;
  final String actionableGuidance;
  final List<String> troubleshootingSteps;
  final bool isRetryable;
  final Duration? suggestedRetryDelay;
  final String? setupStep;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  const SetupError({
    required this.type,
    required this.code,
    required this.message,
    this.technicalDetails,
    required this.userFriendlyMessage,
    required this.actionableGuidance,
    this.troubleshootingSteps = const [],
    required this.isRetryable,
    this.suggestedRetryDelay,
    this.setupStep,
    this.context = const {},
    required this.timestamp,
  });

  /// Create error from exception with automatic classification
  factory SetupError.fromException(
    dynamic exception, {
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) {
    final errorMessage = exception.toString().toLowerCase();
    final timestamp = DateTime.now();

    // Platform detection errors
    if (errorMessage.contains('platform') ||
        errorMessage.contains('user agent')) {
      return SetupError(
        type: SetupErrorType.platformDetection,
        code: 'PLATFORM_DETECTION_FAILED',
        message: exception.toString(),
        technicalDetails: exception.toString(),
        userFriendlyMessage: 'Unable to detect your operating system',
        actionableGuidance: 'Please select your platform manually',
        troubleshootingSteps: [
          'Try refreshing the page',
          'Use manual platform selection',
          'Check browser compatibility',
          'Contact support if issue persists',
        ],
        isRetryable: true,
        suggestedRetryDelay: const Duration(seconds: 5),
        setupStep: setupStep,
        context: context,
        timestamp: timestamp,
      );
    }

    // Container creation errors
    if (errorMessage.contains('container') || errorMessage.contains('docker')) {
      return SetupError(
        type: SetupErrorType.containerCreation,
        code: 'CONTAINER_CREATION_FAILED',
        message: exception.toString(),
        technicalDetails: exception.toString(),
        userFriendlyMessage: 'Failed to create your secure container',
        actionableGuidance: 'Please try again or contact support',
        troubleshootingSteps: [
          'Check internet connection',
          'Verify server availability',
          'Try again in a few minutes',
          'Contact support if problem continues',
        ],
        isRetryable: true,
        suggestedRetryDelay: const Duration(seconds: 30),
        setupStep: setupStep,
        context: context,
        timestamp: timestamp,
      );
    }

    // Download errors
    if (errorMessage.contains('download') || errorMessage.contains('fetch')) {
      return SetupError(
        type: SetupErrorType.downloadFailure,
        code: 'DOWNLOAD_FAILED',
        message: exception.toString(),
        technicalDetails: exception.toString(),
        userFriendlyMessage: 'Download failed',
        actionableGuidance: 'Please try downloading again',
        troubleshootingSteps: [
          'Check internet connection',
          'Try a different browser',
          'Disable ad blockers temporarily',
          'Use alternative download mirror',
        ],
        isRetryable: true,
        suggestedRetryDelay: const Duration(seconds: 10),
        setupStep: setupStep,
        context: context,
        timestamp: timestamp,
      );
    }

    // Network errors
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('unreachable')) {
      return SetupError(
        type: SetupErrorType.networkError,
        code: 'NETWORK_ERROR',
        message: exception.toString(),
        technicalDetails: exception.toString(),
        userFriendlyMessage: 'Network connection problem',
        actionableGuidance: 'Check your internet connection and try again',
        troubleshootingSteps: [
          'Check internet connection',
          'Verify firewall settings',
          'Try disabling VPN temporarily',
          'Contact your network administrator',
        ],
        isRetryable: true,
        suggestedRetryDelay: const Duration(seconds: 15),
        setupStep: setupStep,
        context: context,
        timestamp: timestamp,
      );
    }

    // Authentication errors
    if (errorMessage.contains('auth') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('forbidden')) {
      return SetupError(
        type: SetupErrorType.authentication,
        code: 'AUTH_ERROR',
        message: exception.toString(),
        technicalDetails: exception.toString(),
        userFriendlyMessage: 'Authentication failed',
        actionableGuidance: 'Please log in again',
        troubleshootingSteps: [
          'Log out and log back in',
          'Clear browser cache and cookies',
          'Try a different browser',
          'Contact support if issue persists',
        ],
        isRetryable: false,
        setupStep: setupStep,
        context: context,
        timestamp: timestamp,
      );
    }

    // Default to unknown error
    return SetupError(
      type: SetupErrorType.unknown,
      code: 'UNKNOWN_ERROR',
      message: exception.toString(),
      technicalDetails: exception.toString(),
      userFriendlyMessage: 'An unexpected error occurred',
      actionableGuidance: 'Please try again or contact support',
      troubleshootingSteps: [
        'Try refreshing the page',
        'Clear browser cache',
        'Try a different browser',
        'Contact support with error details',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 10),
      setupStep: setupStep,
      context: context,
      timestamp: timestamp,
    );
  }

  /// Create specific error types with predefined configurations
  factory SetupError.platformDetectionFailed({
    String? details,
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) {
    return SetupError(
      type: SetupErrorType.platformDetection,
      code: 'PLATFORM_DETECTION_FAILED',
      message: 'Platform detection failed',
      technicalDetails: details,
      userFriendlyMessage: 'Unable to detect your operating system',
      actionableGuidance:
          'Please select your platform manually from the options below',
      troubleshootingSteps: [
        'Try refreshing the page',
        'Use manual platform selection',
        'Check if JavaScript is enabled',
        'Try a different browser',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 5),
      setupStep: setupStep,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  factory SetupError.containerCreationFailed({
    String? details,
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) {
    return SetupError(
      type: SetupErrorType.containerCreation,
      code: 'CONTAINER_CREATION_FAILED',
      message: 'Container creation failed',
      technicalDetails: details,
      userFriendlyMessage: 'Failed to create your secure container',
      actionableGuidance:
          'We\'ll try again automatically, or you can retry manually',
      troubleshootingSteps: [
        'Check internet connection',
        'Wait a moment and try again',
        'Verify server status',
        'Contact support if problem persists',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 30),
      setupStep: setupStep,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  factory SetupError.downloadFailed({
    String? details,
    String? setupStep,
    String? platform,
    Map<String, dynamic> context = const {},
  }) {
    return SetupError(
      type: SetupErrorType.downloadFailure,
      code: 'DOWNLOAD_FAILED',
      message: 'Download failed',
      technicalDetails: details,
      userFriendlyMessage: 'Failed to download the desktop client',
      actionableGuidance:
          'Try downloading again or use an alternative download method',
      troubleshootingSteps: [
        'Check internet connection',
        'Try downloading with a different browser',
        'Disable ad blockers temporarily',
        'Use the direct download link',
        if (platform != null) 'Try the alternative $platform package',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 10),
      setupStep: setupStep,
      context: {...context, if (platform != null) 'platform': platform},
      timestamp: DateTime.now(),
    );
  }

  factory SetupError.tunnelConfigurationFailed({
    String? details,
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) {
    return SetupError(
      type: SetupErrorType.tunnelConfiguration,
      code: 'TUNNEL_CONFIG_FAILED',
      message: 'Tunnel configuration failed',
      technicalDetails: details,
      userFriendlyMessage: 'Failed to configure the connection tunnel',
      actionableGuidance: 'Check your network settings and try again',
      troubleshootingSteps: [
        'Check firewall settings',
        'Verify port availability',
        'Try disabling VPN temporarily',
        'Check antivirus software settings',
        'Contact network administrator if needed',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 20),
      setupStep: setupStep,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  factory SetupError.connectionValidationFailed({
    String? details,
    String? setupStep,
    Map<String, dynamic> context = const {},
  }) {
    return SetupError(
      type: SetupErrorType.connectionValidation,
      code: 'CONNECTION_VALIDATION_FAILED',
      message: 'Connection validation failed',
      technicalDetails: details,
      userFriendlyMessage: 'Unable to verify the connection is working',
      actionableGuidance:
          'Check that the desktop client is running and try again',
      troubleshootingSteps: [
        'Ensure desktop client is running',
        'Check firewall and antivirus settings',
        'Verify network connectivity',
        'Restart the desktop client',
        'Try connecting manually',
      ],
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 15),
      setupStep: setupStep,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  /// Get icon for error type
  String getErrorIcon() {
    switch (type) {
      case SetupErrorType.platformDetection:
        return '';
      case SetupErrorType.containerCreation:
        return '�';
      case SetupErrorType.downloadFailure:
        return '⬇';
      case SetupErrorType.installationFailure:
        return '';
      case SetupErrorType.tunnelConfiguration:
        return '';
      case SetupErrorType.connectionValidation:
        return '';
      case SetupErrorType.authentication:
        return '�';
      case SetupErrorType.networkError:
        return '';
      case SetupErrorType.serviceTimeout:
        return '';
      case SetupErrorType.permissionError:
        return '�';
      case SetupErrorType.configurationError:
        return '';
      default:
        return '';
    }
  }

  /// Get color for error type (Material Design color names)
  String getErrorColor() {
    switch (type) {
      case SetupErrorType.authentication:
      case SetupErrorType.permissionError:
        return 'red';
      case SetupErrorType.networkError:
      case SetupErrorType.serviceTimeout:
        return 'orange';
      case SetupErrorType.configurationError:
        return 'amber';
      default:
        return 'red';
    }
  }

  /// Check if error is critical (requires immediate attention)
  bool get isCritical {
    switch (type) {
      case SetupErrorType.authentication:
      case SetupErrorType.permissionError:
        return true;
      default:
        return false;
    }
  }

  /// Get detailed troubleshooting guide
  String getDetailedTroubleshootingGuide() {
    final buffer = StringBuffer();
    buffer.writeln('## Troubleshooting Guide');
    buffer.writeln();
    buffer.writeln('**Error:** ${getErrorIcon()} $userFriendlyMessage');
    buffer.writeln();
    buffer.writeln('**What to try:**');

    for (int i = 0; i < troubleshootingSteps.length; i++) {
      buffer.writeln('${i + 1}. ${troubleshootingSteps[i]}');
    }

    if (isRetryable && suggestedRetryDelay != null) {
      buffer.writeln();
      buffer.writeln(
        '**Retry:** This error can be retried automatically in ${suggestedRetryDelay!.inSeconds} seconds.',
      );
    }

    if (technicalDetails != null) {
      buffer.writeln();
      buffer.writeln('**Technical Details:**');
      buffer.writeln('```');
      buffer.writeln(technicalDetails);
      buffer.writeln('```');
    }

    return buffer.toString();
  }

  /// Convert to JSON for logging and analytics
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'code': code,
      'message': message,
      'technicalDetails': technicalDetails,
      'userFriendlyMessage': userFriendlyMessage,
      'actionableGuidance': actionableGuidance,
      'troubleshootingSteps': troubleshootingSteps,
      'isRetryable': isRetryable,
      'suggestedRetryDelay': suggestedRetryDelay?.inMilliseconds,
      'setupStep': setupStep,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'isCritical': isCritical,
    };
  }

  /// Create from JSON
  factory SetupError.fromJson(Map<String, dynamic> json) {
    return SetupError(
      type: SetupErrorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SetupErrorType.unknown,
      ),
      code: json['code'] as String,
      message: json['message'] as String,
      technicalDetails: json['technicalDetails'] as String?,
      userFriendlyMessage: json['userFriendlyMessage'] as String,
      actionableGuidance: json['actionableGuidance'] as String,
      troubleshootingSteps: List<String>.from(
        json['troubleshootingSteps'] ?? [],
      ),
      isRetryable: json['isRetryable'] as bool,
      suggestedRetryDelay: json['suggestedRetryDelay'] != null
          ? Duration(milliseconds: json['suggestedRetryDelay'] as int)
          : null,
      setupStep: json['setupStep'] as String?,
      context: Map<String, dynamic>.from(json['context'] ?? {}),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'SetupError(type: $type, code: $code, message: $userFriendlyMessage, '
        'step: $setupStep, retryable: $isRetryable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetupError &&
        other.type == type &&
        other.code == code &&
        other.message == message &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(type, code, message, timestamp);
  }
}

/// Retry state for setup operations
@immutable
class SetupRetryState {
  final int attemptCount;
  final DateTime? lastAttempt;
  final DateTime? nextAttempt;
  final Duration currentDelay;
  final bool isBackedOff;
  final bool hasReachedMaxAttempts;
  final SetupError? lastError;

  const SetupRetryState({
    this.attemptCount = 0,
    this.lastAttempt,
    this.nextAttempt,
    this.currentDelay = const Duration(seconds: 1),
    this.isBackedOff = false,
    this.hasReachedMaxAttempts = false,
    this.lastError,
  });

  /// Create initial retry state
  factory SetupRetryState.initial() {
    return const SetupRetryState();
  }

  /// Create next retry state with exponential backoff
  SetupRetryState nextRetryAttempt({
    required int maxAttempts,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(minutes: 2),
    SetupError? error,
  }) {
    final newAttemptCount = attemptCount + 1;
    final hasReachedMax = newAttemptCount >= maxAttempts;

    // Use error's suggested delay if available, otherwise exponential backoff
    Duration nextDelay;
    if (error?.suggestedRetryDelay != null) {
      nextDelay = error!.suggestedRetryDelay!;
    } else {
      // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, up to maxDelay
      nextDelay = Duration(
        milliseconds: (baseDelay.inMilliseconds * (1 << (newAttemptCount - 1)))
            .clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds),
      );
    }

    final now = DateTime.now();
    final nextAttemptTime = hasReachedMax ? null : now.add(nextDelay);

    return SetupRetryState(
      attemptCount: newAttemptCount,
      lastAttempt: now,
      nextAttempt: nextAttemptTime,
      currentDelay: nextDelay,
      isBackedOff: nextDelay > baseDelay,
      hasReachedMaxAttempts: hasReachedMax,
      lastError: error,
    );
  }

  /// Reset retry state
  SetupRetryState reset() {
    return SetupRetryState.initial();
  }

  /// Check if ready for next attempt
  bool get canRetry {
    if (hasReachedMaxAttempts) return false;
    if (nextAttempt == null) return true;
    return DateTime.now().isAfter(nextAttempt!);
  }

  /// Time until next retry attempt
  Duration? get timeUntilNextRetry {
    if (nextAttempt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(nextAttempt!)) return Duration.zero;
    return nextAttempt!.difference(now);
  }

  @override
  String toString() {
    return 'SetupRetryState(attempts: $attemptCount, '
        'canRetry: $canRetry, delay: $currentDelay)';
  }
}

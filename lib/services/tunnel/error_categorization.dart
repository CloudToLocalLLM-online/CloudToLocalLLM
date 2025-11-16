/// Error Categorization System
/// Maps exceptions to error categories and generates user-friendly messages
library;

import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'interfaces/tunnel_models.dart';

/// Error categorization service
/// Provides intelligent error detection and categorization
class ErrorCategorizationService {
  /// Categorize an exception into a TunnelError
  static TunnelError categorizeException(
    Exception exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    // Try specific exception types first
    if (exception is SocketException) {
      return _categorizeSocketException(exception, stackTrace, context);
    } else if (exception is WebSocketChannelException) {
      return _categorizeWebSocketException(exception, stackTrace, context);
    } else if (exception is TimeoutException) {
      return _categorizeTimeoutException(exception, stackTrace, context);
    } else if (exception is FormatException) {
      return _categorizeFormatException(exception, stackTrace, context);
    }

    // Fall back to string-based categorization
    return _categorizeByMessage(exception, stackTrace, context);
  }

  /// Categorize SocketException
  static TunnelError _categorizeSocketException(
    SocketException exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    final message = exception.message.toLowerCase();
    final osError = exception.osError?.message.toLowerCase() ?? '';

    // Connection refused
    if (message.contains('connection refused') ||
        osError.contains('connection refused') ||
        osError.contains('econnrefused')) {
      return TunnelError.network(
        code: TunnelErrorCodes.connectionRefused,
        message: exception.toString(),
        suggestion: 'Check if the server is running and your firewall settings',
        stackTrace: stackTrace,
        context: {
          ...?context,
          'address': exception.address?.toString(),
          'port': exception.port,
          'osError': exception.osError?.toString(),
        },
      );
    }

    // Network unreachable
    if (message.contains('network is unreachable') ||
        osError.contains('network unreachable') ||
        osError.contains('enetunreach')) {
      return TunnelError.network(
        code: TunnelErrorCodes.networkUnreachable,
        message: exception.toString(),
        suggestion: 'Verify your network connection and try again',
        stackTrace: stackTrace,
        context: {
          ...?context,
          'address': exception.address?.toString(),
          'port': exception.port,
          'osError': exception.osError?.toString(),
        },
      );
    }

    // Host not found (DNS)
    if (message.contains('failed host lookup') ||
        message.contains('host not found') ||
        osError.contains('nodename nor servname provided')) {
      return TunnelError.network(
        code: TunnelErrorCodes.dnsResolutionFailed,
        message: exception.toString(),
        suggestion: 'Check your DNS settings and internet connection',
        stackTrace: stackTrace,
        context: {
          ...?context,
          'address': exception.address?.toString(),
          'port': exception.port,
          'osError': exception.osError?.toString(),
        },
      );
    }

    // Generic network error
    return TunnelError.network(
      code: TunnelErrorCodes.connectionRefused,
      message: exception.toString(),
      stackTrace: stackTrace,
      context: {
        ...?context,
        'address': exception.address?.toString(),
        'port': exception.port,
        'osError': exception.osError?.toString(),
      },
    );
  }

  /// Categorize WebSocketChannelException
  static TunnelError _categorizeWebSocketException(
    WebSocketChannelException exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    final message = exception.message?.toLowerCase() ?? '';
    final innerException = exception.inner;

    // Check inner exception first
    if (innerException != null) {
      if (innerException is SocketException) {
        return _categorizeSocketException(
          innerException,
          stackTrace,
          context,
        );
      }
    }

    // WebSocket-specific errors
    if (message.contains('connection closed') ||
        message.contains('closed before')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.websocketError,
        message: exception.toString(),
        userMessage: 'WebSocket connection closed unexpectedly',
        suggestion:
            'The connection was interrupted. Reconnecting automatically',
        stackTrace: stackTrace,
        context: {
          ...?context,
          'innerException': innerException?.toString(),
        },
      );
    }

    // Generic WebSocket error
    return TunnelError(
      category: TunnelErrorCategory.protocol,
      code: TunnelErrorCodes.websocketError,
      message: exception.toString(),
      stackTrace: stackTrace,
      context: {
        ...?context,
        'innerException': innerException?.toString(),
      },
    );
  }

  /// Categorize TimeoutException
  static TunnelError _categorizeTimeoutException(
    TimeoutException exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    return TunnelError.network(
      code: TunnelErrorCodes.requestTimeout,
      message: exception.message ?? 'Operation timed out',
      suggestion: 'Check your network connection and try again',
      stackTrace: stackTrace,
      context: {
        ...?context,
        'duration': exception.duration?.toString(),
      },
    );
  }

  /// Categorize FormatException
  static TunnelError _categorizeFormatException(
    FormatException exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    return TunnelError.configuration(
      code: TunnelErrorCodes.configurationError,
      message: exception.toString(),
      suggestion: 'Check your configuration values',
      stackTrace: stackTrace,
      context: {
        ...?context,
        'source': exception.source,
        'offset': exception.offset,
      },
    );
  }

  /// Categorize by exception message
  static TunnelError _categorizeByMessage(
    Exception exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    final message = exception.toString().toLowerCase();

    // Authentication errors
    if (message.contains('authentication') ||
        message.contains('unauthorized') ||
        message.contains('401')) {
      return TunnelError.authentication(
        code: TunnelErrorCodes.authenticationFailed,
        message: exception.toString(),
        suggestion: 'Verify your credentials are correct',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('token expired') ||
        message.contains('expired') ||
        message.contains('jwt')) {
      return TunnelError.authentication(
        code: TunnelErrorCodes.tokenExpired,
        message: exception.toString(),
        suggestion: 'Click here to re-authenticate',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('invalid credentials') ||
        message.contains('invalid password') ||
        message.contains('invalid username')) {
      return TunnelError.authentication(
        code: TunnelErrorCodes.invalidCredentials,
        message: exception.toString(),
        suggestion: 'Check your username and password',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Server errors
    if (message.contains('503') ||
        message.contains('service unavailable') ||
        message.contains('unavailable')) {
      return TunnelError(
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.serverUnavailable,
        message: exception.toString(),
        suggestion:
            'The server will retry automatically. Your requests are queued',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('429') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return TunnelError(
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.rateLimitExceeded,
        message: exception.toString(),
        suggestion: 'Wait a moment before sending more requests',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Protocol errors
    if (message.contains('ssh')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.sshError,
        message: exception.toString(),
        suggestion: 'Run diagnostics for more information',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('compression')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.compressionError,
        message: exception.toString(),
        suggestion: 'Try disabling compression in settings',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('protocol') || message.contains('version')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.protocolVersionMismatch,
        message: exception.toString(),
        suggestion: 'Update to the latest version',
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (message.contains('host key')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.hostKeyVerificationFailed,
        message: exception.toString(),
        suggestion: 'Verify the server identity or update the host key',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Configuration errors
    if (message.contains('configuration') ||
        message.contains('config') ||
        message.contains('invalid setting')) {
      return TunnelError.configuration(
        code: TunnelErrorCodes.configurationError,
        message: exception.toString(),
        suggestion: 'Reset to default settings or check configuration values',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Queue errors
    if (message.contains('queue full') || message.contains('queue limit')) {
      return TunnelError(
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.queueFull,
        message: exception.toString(),
        suggestion: 'Wait for pending requests to complete',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Channel errors
    if (message.contains('channel') || message.contains('max channels')) {
      return TunnelError(
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.channelLimitExceeded,
        message: exception.toString(),
        suggestion: 'Close some connections and try again',
        stackTrace: stackTrace,
        context: context,
      );
    }

    // Default to unknown
    return TunnelError(
      category: TunnelErrorCategory.unknown,
      code: TunnelErrorCodes.unknown,
      message: exception.toString(),
      suggestion: 'Run diagnostics for more information',
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Generate error code from HTTP status code
  static String errorCodeFromHttpStatus(int statusCode) {
    switch (statusCode) {
      case 401:
        return TunnelErrorCodes.authenticationFailed;
      case 403:
        return TunnelErrorCodes.invalidCredentials;
      case 429:
        return TunnelErrorCodes.rateLimitExceeded;
      case 503:
        return TunnelErrorCodes.serverUnavailable;
      case 408:
        return TunnelErrorCodes.requestTimeout;
      default:
        return TunnelErrorCodes.unknown;
    }
  }

  /// Create TunnelError from HTTP status code
  static TunnelError fromHttpStatus(
    int statusCode, {
    String? message,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final code = errorCodeFromHttpStatus(statusCode);
    final category = _categoryFromCode(code);

    return TunnelError(
      category: category,
      code: code,
      message: message ?? 'HTTP $statusCode',
      stackTrace: stackTrace,
      context: {
        ...?context,
        'statusCode': statusCode,
      },
    );
  }

  /// Get category from error code
  static TunnelErrorCategory _categoryFromCode(String code) {
    if (code == TunnelErrorCodes.authenticationFailed ||
        code == TunnelErrorCodes.tokenExpired ||
        code == TunnelErrorCodes.invalidCredentials) {
      return TunnelErrorCategory.authentication;
    }
    if (code == TunnelErrorCodes.serverUnavailable ||
        code == TunnelErrorCodes.rateLimitExceeded ||
        code == TunnelErrorCodes.queueFull) {
      return TunnelErrorCategory.server;
    }
    if (code == TunnelErrorCodes.connectionRefused ||
        code == TunnelErrorCodes.networkUnreachable ||
        code == TunnelErrorCodes.dnsResolutionFailed ||
        code == TunnelErrorCodes.requestTimeout) {
      return TunnelErrorCategory.network;
    }
    if (code == TunnelErrorCodes.configurationError) {
      return TunnelErrorCategory.configuration;
    }
    if (code == TunnelErrorCodes.sshError ||
        code == TunnelErrorCodes.websocketError ||
        code == TunnelErrorCodes.compressionError ||
        code == TunnelErrorCodes.protocolVersionMismatch ||
        code == TunnelErrorCodes.hostKeyVerificationFailed ||
        code == TunnelErrorCodes.channelLimitExceeded) {
      return TunnelErrorCategory.protocol;
    }
    return TunnelErrorCategory.unknown;
  }
}

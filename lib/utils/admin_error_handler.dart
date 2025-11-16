import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Error types for admin operations
enum AdminErrorType {
  authentication,
  authorization,
  validation,
  notFound,
  serverError,
  paymentGateway,
  network,
  unknown,
}

/// Admin error with type and user-friendly message
class AdminError {
  final AdminErrorType type;
  final String message;
  final String? technicalDetails;
  final int? statusCode;

  const AdminError({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.statusCode,
  });

  @override
  String toString() {
    if (kDebugMode && technicalDetails != null) {
      return '$message\nTechnical details: $technicalDetails';
    }
    return message;
  }
}

/// Utility class for handling admin-related errors
class AdminErrorHandler {
  /// Handle DioException and convert to AdminError
  static AdminError handleDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    // Extract error message from response
    String? apiMessage;
    if (responseData is Map<String, dynamic>) {
      apiMessage = responseData['error'] as String? ??
          responseData['message'] as String?;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AdminError(
          type: AdminErrorType.network,
          message: 'Connection timeout. Please check your internet connection.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(statusCode, apiMessage, error);

      case DioExceptionType.cancel:
        return AdminError(
          type: AdminErrorType.unknown,
          message: 'Request was cancelled.',
          technicalDetails: error.message,
        );

      case DioExceptionType.connectionError:
        return AdminError(
          type: AdminErrorType.network,
          message:
              'Unable to connect to the server. Please check your internet connection.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case DioExceptionType.badCertificate:
        return AdminError(
          type: AdminErrorType.network,
          message: 'Security certificate error. Please contact support.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case DioExceptionType.unknown:
        return AdminError(
          type: AdminErrorType.unknown,
          message:
              apiMessage ?? 'An unexpected error occurred. Please try again.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );
    }
  }

  /// Handle bad response based on status code
  static AdminError _handleBadResponse(
    int? statusCode,
    String? apiMessage,
    DioException error,
  ) {
    switch (statusCode) {
      case 400:
        return AdminError(
          type: AdminErrorType.validation,
          message: apiMessage ?? 'Invalid request. Please check your input.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 401:
        return AdminError(
          type: AdminErrorType.authentication,
          message: 'Your session has expired. Please log in again.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 403:
        return AdminError(
          type: AdminErrorType.authorization,
          message: apiMessage ??
              'You do not have permission to perform this action.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 404:
        return AdminError(
          type: AdminErrorType.notFound,
          message: apiMessage ?? 'The requested resource was not found.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 409:
        return AdminError(
          type: AdminErrorType.validation,
          message: apiMessage ?? 'This operation conflicts with existing data.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 422:
        return AdminError(
          type: AdminErrorType.validation,
          message: apiMessage ?? 'Validation failed. Please check your input.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 429:
        return AdminError(
          type: AdminErrorType.serverError,
          message: 'Too many requests. Please wait a moment and try again.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return AdminError(
          type: AdminErrorType.serverError,
          message: apiMessage ??
              'Server error. Please try again later or contact support.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );

      default:
        return AdminError(
          type: AdminErrorType.unknown,
          message:
              apiMessage ?? 'An unexpected error occurred. Please try again.',
          technicalDetails: error.message,
          statusCode: statusCode,
        );
    }
  }

  /// Handle payment gateway errors
  static AdminError handlePaymentGatewayError(dynamic error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      String? gatewayError;

      if (responseData is Map<String, dynamic>) {
        gatewayError = responseData['gateway_error'] as String? ??
            responseData['stripe_error'] as String? ??
            responseData['paypal_error'] as String?;
      }

      if (gatewayError != null) {
        return AdminError(
          type: AdminErrorType.paymentGateway,
          message: _getPaymentGatewayMessage(gatewayError),
          technicalDetails: gatewayError,
          statusCode: error.response?.statusCode,
        );
      }

      return handleDioException(error);
    }

    return AdminError(
      type: AdminErrorType.paymentGateway,
      message: 'Payment processing failed. Please try again.',
      technicalDetails: error.toString(),
    );
  }

  /// Get user-friendly message for payment gateway errors
  static String _getPaymentGatewayMessage(String gatewayError) {
    final lowerError = gatewayError.toLowerCase();

    if (lowerError.contains('card_declined')) {
      return 'The card was declined. Please try a different payment method.';
    } else if (lowerError.contains('insufficient_funds')) {
      return 'Insufficient funds. Please try a different payment method.';
    } else if (lowerError.contains('expired_card')) {
      return 'The card has expired. Please use a different payment method.';
    } else if (lowerError.contains('incorrect_cvc')) {
      return 'Incorrect security code. Please check and try again.';
    } else if (lowerError.contains('processing_error')) {
      return 'Payment processing error. Please try again.';
    } else if (lowerError.contains('rate_limit')) {
      return 'Too many payment attempts. Please wait a moment and try again.';
    } else if (lowerError.contains('refund')) {
      return 'Refund processing failed. Please contact support.';
    }

    return 'Payment processing failed: $gatewayError';
  }

  /// Handle validation errors
  static AdminError handleValidationError(String message, {String? field}) {
    return AdminError(
      type: AdminErrorType.validation,
      message: field != null ? '$field: $message' : message,
      technicalDetails: field,
    );
  }

  /// Handle generic errors
  static AdminError handleGenericError(dynamic error) {
    if (error is DioException) {
      return handleDioException(error);
    }

    if (error is AdminError) {
      return error;
    }

    return AdminError(
      type: AdminErrorType.unknown,
      message: 'An unexpected error occurred: ${error.toString()}',
      technicalDetails: error.toString(),
    );
  }

  /// Log error for debugging
  static void logError(AdminError error, {String? context}) {
    if (kDebugMode) {
      final prefix = context != null ? '[$context]' : '[AdminError]';
      debugPrint('$prefix ${error.type.name}: ${error.message}');
      if (error.technicalDetails != null) {
        debugPrint('$prefix Technical: ${error.technicalDetails}');
      }
      if (error.statusCode != null) {
        debugPrint('$prefix Status Code: ${error.statusCode}');
      }
    }
  }
}

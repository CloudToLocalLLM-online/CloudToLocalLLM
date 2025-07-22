/// Message protocol utilities for serialization, deserialization, and validation
/// of tunnel messages between Flutter client and cloud API
library;

import 'dart:convert';
import '../models/tunnel_message.dart';

/// Exception thrown when message protocol operations fail
class MessageProtocolException implements Exception {
  final String message;
  final dynamic cause;

  const MessageProtocolException(this.message, [this.cause]);

  @override
  String toString() =>
      'MessageProtocolException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Message protocol utilities for tunnel communication
class TunnelMessageProtocol {
  /// Serialize a tunnel message to JSON string
  ///
  /// Throws [MessageProtocolException] if serialization fails
  static String serialize(TunnelMessage message) {
    try {
      return jsonEncode(message.toJson());
    } catch (e) {
      throw MessageProtocolException('Failed to serialize message', e);
    }
  }

  /// Deserialize JSON string to tunnel message
  ///
  /// Throws [MessageProtocolException] if parsing fails or message is invalid
  static TunnelMessage deserialize(String jsonString) {
    if (jsonString.isEmpty) {
      throw const MessageProtocolException('JSON string cannot be empty');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw MessageProtocolException('Failed to parse JSON', e);
    }

    try {
      return TunnelMessage.fromJson(json);
    } catch (e) {
      throw MessageProtocolException('Invalid tunnel message format', e);
    }
  }

  /// Validate HTTP request object
  static bool validateHttpRequest(HttpRequest request) {
    try {
      // Method validation
      if (request.method.isEmpty ||
          !HttpMethods.all.contains(request.method.toUpperCase())) {
        return false;
      }

      // Path validation
      if (request.path.isEmpty) {
        return false;
      }

      // Headers validation (can be empty for any method)
      // Headers are always provided as a Map, so no additional validation needed

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate HTTP response object
  static bool validateHttpResponse(HttpResponse response) {
    try {
      // Status code validation
      if (response.status < 100 || response.status > 599) {
        return false;
      }

      // Headers validation (can be empty)
      // Body validation (can be empty)
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate tunnel message object
  static bool validateTunnelMessage(TunnelMessage message) {
    try {
      // Type validation
      if (!TunnelMessageTypes.all.contains(message.type)) {
        return false;
      }

      // ID validation
      if (message.id.isEmpty) {
        return false;
      }

      // Type-specific validation
      switch (message.type) {
        case TunnelMessageTypes.httpRequest:
          return _validateRequestMessage(message as TunnelRequestMessage);
        case TunnelMessageTypes.httpResponse:
          return _validateResponseMessage(message as TunnelResponseMessage);
        case TunnelMessageTypes.ping:
          return _validatePingMessage(message as PingMessage);
        case TunnelMessageTypes.pong:
          return _validatePongMessage(message as PongMessage);
        case TunnelMessageTypes.error:
          return _validateErrorMessage(message as ErrorMessage);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Validate tunnel request message
  static bool _validateRequestMessage(TunnelRequestMessage message) {
    // Method validation
    if (message.method.isEmpty ||
        !HttpMethods.all.contains(message.method.toUpperCase())) {
      return false;
    }

    // Path validation
    if (message.path.isEmpty) {
      return false;
    }

    return true;
  }

  /// Validate tunnel response message
  static bool _validateResponseMessage(TunnelResponseMessage message) {
    // Status validation
    if (message.status < 100 || message.status > 599) {
      return false;
    }

    return true;
  }

  /// Validate ping message
  static bool _validatePingMessage(PingMessage message) {
    // Timestamp validation
    if (message.timestamp.isEmpty) {
      return false;
    }

    try {
      DateTime.parse(message.timestamp);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate pong message
  static bool _validatePongMessage(PongMessage message) {
    return _validatePingMessage(
      PingMessage(id: message.id, timestamp: message.timestamp),
    );
  }

  /// Validate error message
  static bool _validateErrorMessage(ErrorMessage message) {
    // Error message validation
    if (message.error.isEmpty) {
      return false;
    }

    return true;
  }

  /// Create HTTP request from tunnel request message
  ///
  /// Throws [MessageProtocolException] if message is invalid
  static HttpRequest extractHttpRequest(TunnelRequestMessage message) {
    if (!_validateRequestMessage(message)) {
      throw const MessageProtocolException('Invalid tunnel request message');
    }

    return message.toHttpRequest();
  }

  /// Create HTTP response from tunnel response message
  ///
  /// Throws [MessageProtocolException] if message is invalid
  static HttpResponse extractHttpResponse(TunnelResponseMessage message) {
    if (!_validateResponseMessage(message)) {
      throw const MessageProtocolException('Invalid tunnel response message');
    }

    return message.toHttpResponse();
  }

  /// Create tunnel request message from HTTP request
  ///
  /// Throws [MessageProtocolException] if request is invalid
  static TunnelRequestMessage createRequestMessage(HttpRequest request) {
    if (!validateHttpRequest(request)) {
      throw const MessageProtocolException('Invalid HTTP request format');
    }

    return TunnelRequestMessage.fromHttpRequest(request);
  }

  /// Create tunnel response message from HTTP response
  ///
  /// Throws [MessageProtocolException] if response is invalid
  static TunnelResponseMessage createResponseMessage(
    String requestId,
    HttpResponse response,
  ) {
    if (requestId.isEmpty) {
      throw const MessageProtocolException('Request ID cannot be empty');
    }

    if (!validateHttpResponse(response)) {
      throw const MessageProtocolException('Invalid HTTP response format');
    }

    return TunnelResponseMessage.fromHttpResponse(requestId, response);
  }

  /// Create ping message
  static PingMessage createPingMessage() {
    return PingMessage.create();
  }

  /// Create pong message in response to ping
  ///
  /// Throws [MessageProtocolException] if ping ID is invalid
  static PongMessage createPongMessage(String pingId) {
    if (pingId.isEmpty) {
      throw const MessageProtocolException('Ping ID cannot be empty');
    }

    return PongMessage(id: pingId, timestamp: DateTime.now().toIso8601String());
  }

  /// Create error message
  ///
  /// Throws [MessageProtocolException] if parameters are invalid
  static ErrorMessage createErrorMessage(
    String requestId,
    String error, [
    int? code,
  ]) {
    if (requestId.isEmpty) {
      throw const MessageProtocolException('Request ID cannot be empty');
    }

    if (error.isEmpty) {
      throw const MessageProtocolException('Error message cannot be empty');
    }

    return ErrorMessage.create(requestId, error, code);
  }
}

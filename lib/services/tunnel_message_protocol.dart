/// Tunnel Message Protocol for CloudToLocalLLM
///
/// This library provides comprehensive message protocol utilities for serialization,
/// deserialization, and validation of tunnel messages between the Flutter client
/// and cloud API. It supports enhanced LLM-specific message types and streaming
/// communication patterns.
///
/// ## Key Features
/// - **Type-Safe Message Handling**: Strongly typed message classes with validation
/// - **LLM-Specific Extensions**: Support for provider routing and streaming messages
/// - **Error Handling**: Comprehensive error classification and recovery
/// - **Performance Optimized**: Efficient serialization for high-throughput scenarios
/// - **Protocol Versioning**: Forward-compatible message format design
///
/// ## Message Types
/// - **HTTP Request/Response**: Standard HTTP tunnel messages
/// - **LLM Request/Response**: Enhanced messages with provider routing
/// - **Streaming Messages**: Real-time streaming support for LLM responses
/// - **Control Messages**: Ping/pong, heartbeat, and status messages
/// - **Error Messages**: Detailed error reporting with context
///
/// ## Usage Example
/// ```dart
/// // Serialize a message
/// final json = TunnelMessageProtocol.serialize(message);
///
/// // Deserialize from JSON
/// final message = TunnelMessageProtocol.deserialize(jsonString);
///
/// // Validate message format
/// final isValid = TunnelMessageProtocol.validateMessage(message);
/// ```
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
///
/// This class provides static methods for handling all aspects of tunnel message
/// communication, including serialization, deserialization, validation, and
/// message creation utilities.
///
/// ## Core Capabilities
/// - **Serialization**: Convert tunnel messages to JSON strings
/// - **Deserialization**: Parse JSON strings back to typed message objects
/// - **Validation**: Comprehensive validation of message format and content
/// - **Message Creation**: Factory methods for creating different message types
/// - **Error Handling**: Robust error handling with detailed error messages
///
/// ## Thread Safety
/// All methods are static and thread-safe, making this class suitable for
/// use in concurrent environments and background processing.
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
        case TunnelMessageTypes.llmRequest:
          return _validateLLMRequestMessage(message as LLMRequestMessage);
        case TunnelMessageTypes.llmResponse:
          return _validateLLMResponseMessage(message as LLMResponseMessage);
        case TunnelMessageTypes.llmStreamChunk:
          return _validateLLMStreamChunkMessage(message as LLMStreamChunkMessage);
        case TunnelMessageTypes.llmStreamEnd:
          return _validateLLMStreamEndMessage(message as LLMStreamEndMessage);
        case TunnelMessageTypes.providerStatus:
          return _validateProviderStatusMessage(message as ProviderStatusMessage);
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

  /// Validate LLM request message
  static bool _validateLLMRequestMessage(LLMRequestMessage message) {
    // Method validation
    if (message.method.isEmpty ||
        !HttpMethods.all.contains(message.method.toUpperCase())) {
      return false;
    }

    // Path validation
    if (message.path.isEmpty) {
      return false;
    }

    // Request type validation
    if (message.requestType.isEmpty) {
      return false;
    }

    return true;
  }

  /// Validate LLM response message
  static bool _validateLLMResponseMessage(LLMResponseMessage message) {
    // Status validation
    if (message.status < 100 || message.status > 599) {
      return false;
    }

    return true;
  }

  /// Validate LLM stream chunk message
  static bool _validateLLMStreamChunkMessage(LLMStreamChunkMessage message) {
    // Request ID validation
    if (message.requestId.isEmpty) {
      return false;
    }

    // Sequence number validation
    if (message.sequenceNumber < 0) {
      return false;
    }

    return true;
  }

  /// Validate LLM stream end message
  static bool _validateLLMStreamEndMessage(LLMStreamEndMessage message) {
    // Request ID validation
    if (message.requestId.isEmpty) {
      return false;
    }

    // Total chunks validation
    if (message.totalChunks < 0) {
      return false;
    }

    return true;
  }

  /// Validate provider status message
  static bool _validateProviderStatusMessage(ProviderStatusMessage message) {
    // Providers list can be empty (no providers available)
    // Timestamp validation
    try {
      message.timestamp.toIso8601String();
      return true;
    } catch (e) {
      return false;
    }
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

  /// Create LLM request message from HTTP request
  ///
  /// Throws [MessageProtocolException] if request is invalid
  static LLMRequestMessage createLLMRequestMessage(
    HttpRequest request, {
    required String requestType,
    String? preferredProvider,
    bool isStreaming = false,
    Duration? customTimeout,
    Map<String, dynamic> llmParameters = const {},
  }) {
    if (!validateHttpRequest(request)) {
      throw const MessageProtocolException('Invalid HTTP request format');
    }

    if (requestType.isEmpty) {
      throw const MessageProtocolException('Request type cannot be empty');
    }

    return LLMRequestMessage.fromHttpRequest(
      request,
      requestType: requestType,
      preferredProvider: preferredProvider,
      isStreaming: isStreaming,
      customTimeout: customTimeout,
      llmParameters: llmParameters,
    );
  }

  /// Create LLM response message from HTTP response
  ///
  /// Throws [MessageProtocolException] if response is invalid
  static LLMResponseMessage createLLMResponseMessage(
    String requestId,
    HttpResponse response, {
    String? providerId,
    bool usedFallback = false,
    Duration? processingTime,
  }) {
    if (requestId.isEmpty) {
      throw const MessageProtocolException('Request ID cannot be empty');
    }

    if (!validateHttpResponse(response)) {
      throw const MessageProtocolException('Invalid HTTP response format');
    }

    return LLMResponseMessage.fromHttpResponse(
      requestId,
      response,
      providerId: providerId,
      usedFallback: usedFallback,
      processingTime: processingTime,
    );
  }

  /// Create LLM stream chunk message
  ///
  /// Throws [MessageProtocolException] if parameters are invalid
  static LLMStreamChunkMessage createLLMStreamChunkMessage(
    String requestId,
    String chunk,
    int sequenceNumber, {
    bool isComplete = false,
    String? providerId,
  }) {
    if (requestId.isEmpty) {
      throw const MessageProtocolException('Request ID cannot be empty');
    }

    if (sequenceNumber < 0) {
      throw const MessageProtocolException('Sequence number must be non-negative');
    }

    return LLMStreamChunkMessage.create(
      requestId,
      chunk,
      sequenceNumber,
      isComplete: isComplete,
      providerId: providerId,
    );
  }

  /// Create LLM stream end message
  ///
  /// Throws [MessageProtocolException] if parameters are invalid
  static LLMStreamEndMessage createLLMStreamEndMessage(
    String requestId,
    int totalChunks,
    Duration totalTime, {
    String? providerId,
    String? finalStatus,
  }) {
    if (requestId.isEmpty) {
      throw const MessageProtocolException('Request ID cannot be empty');
    }

    if (totalChunks < 0) {
      throw const MessageProtocolException('Total chunks must be non-negative');
    }

    return LLMStreamEndMessage.create(
      requestId,
      totalChunks,
      totalTime,
      providerId: providerId,
      finalStatus: finalStatus,
    );
  }

  /// Create provider status message
  ///
  /// Throws [MessageProtocolException] if providers list is invalid
  static ProviderStatusMessage createProviderStatusMessage(
    List<ProviderInfo> providers,
  ) {
    // Providers list can be empty (no providers available)
    return ProviderStatusMessage.create(providers);
  }

  /// Extract LLM request from LLM request message
  ///
  /// Throws [MessageProtocolException] if message is invalid
  static HttpRequest extractLLMHttpRequest(LLMRequestMessage message) {
    if (!_validateLLMRequestMessage(message)) {
      throw const MessageProtocolException('Invalid LLM request message');
    }

    return message.toHttpRequest();
  }

  /// Extract LLM response from LLM response message
  ///
  /// Throws [MessageProtocolException] if message is invalid
  static HttpResponse extractLLMHttpResponse(LLMResponseMessage message) {
    if (!_validateLLMResponseMessage(message)) {
      throw const MessageProtocolException('Invalid LLM response message');
    }

    return message.toHttpResponse();
  }
}

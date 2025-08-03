/// Core message protocol models for the simplified tunnel system
/// Defines message types for communication between Flutter client and cloud API
///
/// This library implements the WebSocket-based tunnel protocol that enables
/// secure communication between the Flutter client and cloud API backend.
/// The protocol uses JSON-serializable message types for bidirectional
/// communication with proper error handling and health checks.
library;

import 'package:uuid/uuid.dart';

/// HTTP request model representing an API request to be tunneled
///
/// Used to encapsulate HTTP requests that need to be proxied through
/// the tunnel system to the local Ollama instance.
class HttpRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body;

  const HttpRequest({
    required this.method,
    required this.path,
    required this.headers,
    this.body,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'headers': headers,
    if (body != null) 'body': body,
  };

  factory HttpRequest.fromJson(Map<String, dynamic> json) => HttpRequest(
    method: json['method'] as String,
    path: json['path'] as String,
    headers: Map<String, String>.from(json['headers'] as Map),
    body: json['body'] as String?,
  );
}

/// HTTP response model representing an API response from the tunneled request
///
/// Contains the complete HTTP response data including status code, headers,
/// and body content from the local Ollama instance.
class HttpResponse {
  final int status;
  final Map<String, String> headers;
  final String body;

  const HttpResponse({
    required this.status,
    required this.headers,
    required this.body,
  });

  Map<String, dynamic> toJson() => {
    'status': status,
    'headers': headers,
    'body': body,
  };

  factory HttpResponse.fromJson(Map<String, dynamic> json) => HttpResponse(
    status: json['status'] as int,
    headers: Map<String, String>.from(json['headers'] as Map),
    body: json['body'] as String,
  );
}

/// Base tunnel message interface for all message types in the tunnel protocol
///
/// Provides common functionality for message serialization/deserialization
/// and serves as the foundation for the type-safe message hierarchy.
/// Each message has a unique ID and type identifier.
abstract class TunnelMessage {
  final String type;
  final String id;

  const TunnelMessage({required this.type, required this.id});

  Map<String, dynamic> toJson();

  static TunnelMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case TunnelMessageTypes.httpRequest:
        return TunnelRequestMessage.fromJson(json);
      case TunnelMessageTypes.httpResponse:
        return TunnelResponseMessage.fromJson(json);
      case TunnelMessageTypes.llmRequest:
        return LLMRequestMessage.fromJson(json);
      case TunnelMessageTypes.llmResponse:
        return LLMResponseMessage.fromJson(json);
      case TunnelMessageTypes.llmStreamChunk:
        return LLMStreamChunkMessage.fromJson(json);
      case TunnelMessageTypes.llmStreamEnd:
        return LLMStreamEndMessage.fromJson(json);
      case TunnelMessageTypes.providerStatus:
        return ProviderStatusMessage.fromJson(json);
      case TunnelMessageTypes.ping:
        return PingMessage.fromJson(json);
      case TunnelMessageTypes.pong:
        return PongMessage.fromJson(json);
      case TunnelMessageTypes.error:
        return ErrorMessage.fromJson(json);
      default:
        throw ArgumentError('Unknown message type: $type');
    }
  }
}

/// Tunnel request message (Cloud → Desktop)
///
/// Represents an HTTP request being sent from the cloud service to the
/// desktop application. Contains all necessary information to reconstruct
/// the original HTTP request on the desktop side.
class TunnelRequestMessage extends TunnelMessage {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body;

  const TunnelRequestMessage({
    required super.id,
    required this.method,
    required this.path,
    required this.headers,
    this.body,
  }) : super(type: TunnelMessageTypes.httpRequest);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'method': method,
    'path': path,
    'headers': headers,
    if (body != null) 'body': body,
  };

  factory TunnelRequestMessage.fromJson(Map<String, dynamic> json) =>
      TunnelRequestMessage(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: json['body'] as String?,
      );

  factory TunnelRequestMessage.fromHttpRequest(HttpRequest request) =>
      TunnelRequestMessage(
        id: const Uuid().v4(),
        method: request.method,
        path: request.path,
        headers: request.headers,
        body: request.body,
      );

  HttpRequest toHttpRequest() =>
      HttpRequest(method: method, path: path, headers: headers, body: body);
}

/// Tunnel response message (Desktop → Cloud)
///
/// Represents an HTTP response being sent from the desktop application
/// back to the cloud service. Contains the complete response data including
/// status code, headers, and body content.
class TunnelResponseMessage extends TunnelMessage {
  final int status;
  final Map<String, String> headers;
  final String body;

  const TunnelResponseMessage({
    required super.id,
    required this.status,
    required this.headers,
    required this.body,
  }) : super(type: TunnelMessageTypes.httpResponse);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'status': status,
    'headers': headers,
    'body': body,
  };

  factory TunnelResponseMessage.fromJson(Map<String, dynamic> json) =>
      TunnelResponseMessage(
        id: json['id'] as String,
        status: json['status'] as int,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: json['body'] as String,
      );

  factory TunnelResponseMessage.fromHttpResponse(
    String requestId,
    HttpResponse response,
  ) => TunnelResponseMessage(
    id: requestId,
    status: response.status,
    headers: response.headers,
    body: response.body,
  );

  HttpResponse toHttpResponse() =>
      HttpResponse(status: status, headers: headers, body: body);
}

/// Ping message for connection health checks and keepalive
///
/// Used to verify that the WebSocket connection is still active and
/// to measure round-trip latency between cloud and desktop.
class PingMessage extends TunnelMessage {
  final String timestamp;

  const PingMessage({required super.id, required this.timestamp})
    : super(type: TunnelMessageTypes.ping);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp,
  };

  factory PingMessage.fromJson(Map<String, dynamic> json) => PingMessage(
    id: json['id'] as String,
    timestamp: json['timestamp'] as String,
  );

  factory PingMessage.create() => PingMessage(
    id: const Uuid().v4(),
    timestamp: DateTime.now().toIso8601String(),
  );
}

/// Pong message in response to ping
///
/// Sent in response to a PingMessage to complete the health check cycle.
/// Contains the original ping ID for correlation and a new timestamp for
/// latency calculation.
class PongMessage extends TunnelMessage {
  final String timestamp;

  const PongMessage({required super.id, required this.timestamp})
    : super(type: TunnelMessageTypes.pong);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp,
  };

  factory PongMessage.fromJson(Map<String, dynamic> json) => PongMessage(
    id: json['id'] as String,
    timestamp: json['timestamp'] as String,
  );

  factory PongMessage.fromPing(PingMessage ping) =>
      PongMessage(id: ping.id, timestamp: DateTime.now().toIso8601String());
}

/// Error message for tunnel protocol error handling
///
/// Used to communicate errors that occur during tunnel operation,
/// such as connection issues, timeout errors, or protocol violations.
/// Contains an error message and optional error code.
class ErrorMessage extends TunnelMessage {
  final String error;
  final int? code;

  const ErrorMessage({required super.id, required this.error, this.code})
    : super(type: TunnelMessageTypes.error);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'error': error,
    if (code != null) 'code': code,
  };

  factory ErrorMessage.fromJson(Map<String, dynamic> json) => ErrorMessage(
    id: json['id'] as String,
    error: json['error'] as String,
    code: json['code'] as int?,
  );

  factory ErrorMessage.create(String requestId, String error, [int? code]) =>
      ErrorMessage(id: requestId, error: error, code: code);
}

/// LLM request message with provider routing information
///
/// Enhanced request message that includes LLM-specific metadata such as
/// preferred provider, request type, and streaming configuration.
class LLMRequestMessage extends TunnelMessage {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body;
  final String requestType;
  final String? preferredProvider;
  final bool isStreaming;
  final Duration? customTimeout;
  final Map<String, dynamic> llmParameters;

  const LLMRequestMessage({
    required super.id,
    required this.method,
    required this.path,
    required this.headers,
    this.body,
    required this.requestType,
    this.preferredProvider,
    this.isStreaming = false,
    this.customTimeout,
    this.llmParameters = const {},
  }) : super(type: TunnelMessageTypes.llmRequest);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'method': method,
    'path': path,
    'headers': headers,
    if (body != null) 'body': body,
    'requestType': requestType,
    if (preferredProvider != null) 'preferredProvider': preferredProvider,
    'isStreaming': isStreaming,
    if (customTimeout != null) 'customTimeout': customTimeout!.inMilliseconds,
    'llmParameters': llmParameters,
  };

  factory LLMRequestMessage.fromJson(Map<String, dynamic> json) =>
      LLMRequestMessage(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: json['body'] as String?,
        requestType: json['requestType'] as String,
        preferredProvider: json['preferredProvider'] as String?,
        isStreaming: json['isStreaming'] as bool? ?? false,
        customTimeout: json['customTimeout'] != null
            ? Duration(milliseconds: json['customTimeout'] as int)
            : null,
        llmParameters: Map<String, dynamic>.from(
          json['llmParameters'] as Map? ?? {},
        ),
      );

  factory LLMRequestMessage.fromHttpRequest(
    HttpRequest request, {
    required String requestType,
    String? preferredProvider,
    bool isStreaming = false,
    Duration? customTimeout,
    Map<String, dynamic> llmParameters = const {},
  }) =>
      LLMRequestMessage(
        id: const Uuid().v4(),
        method: request.method,
        path: request.path,
        headers: request.headers,
        body: request.body,
        requestType: requestType,
        preferredProvider: preferredProvider,
        isStreaming: isStreaming,
        customTimeout: customTimeout,
        llmParameters: llmParameters,
      );

  HttpRequest toHttpRequest() =>
      HttpRequest(method: method, path: path, headers: headers, body: body);
}

/// LLM response message with provider information
///
/// Enhanced response message that includes information about which
/// provider handled the request and whether fallback was used.
class LLMResponseMessage extends TunnelMessage {
  final int status;
  final Map<String, String> headers;
  final String body;
  final String? providerId;
  final bool usedFallback;
  final Duration? processingTime;

  const LLMResponseMessage({
    required super.id,
    required this.status,
    required this.headers,
    required this.body,
    this.providerId,
    this.usedFallback = false,
    this.processingTime,
  }) : super(type: TunnelMessageTypes.llmResponse);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'status': status,
    'headers': headers,
    'body': body,
    if (providerId != null) 'providerId': providerId,
    'usedFallback': usedFallback,
    if (processingTime != null) 'processingTime': processingTime!.inMilliseconds,
  };

  factory LLMResponseMessage.fromJson(Map<String, dynamic> json) =>
      LLMResponseMessage(
        id: json['id'] as String,
        status: json['status'] as int,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: json['body'] as String,
        providerId: json['providerId'] as String?,
        usedFallback: json['usedFallback'] as bool? ?? false,
        processingTime: json['processingTime'] != null
            ? Duration(milliseconds: json['processingTime'] as int)
            : null,
      );

  factory LLMResponseMessage.fromHttpResponse(
    String requestId,
    HttpResponse response, {
    String? providerId,
    bool usedFallback = false,
    Duration? processingTime,
  }) =>
      LLMResponseMessage(
        id: requestId,
        status: response.status,
        headers: response.headers,
        body: response.body,
        providerId: providerId,
        usedFallback: usedFallback,
        processingTime: processingTime,
      );

  HttpResponse toHttpResponse() =>
      HttpResponse(status: status, headers: headers, body: body);
}

/// LLM streaming chunk message for real-time responses
///
/// Used to send streaming data chunks from LLM providers in real-time.
/// Each chunk contains a portion of the response data and sequence information.
class LLMStreamChunkMessage extends TunnelMessage {
  final String requestId;
  final String chunk;
  final int sequenceNumber;
  final bool isComplete;
  final String? providerId;

  const LLMStreamChunkMessage({
    required super.id,
    required this.requestId,
    required this.chunk,
    required this.sequenceNumber,
    this.isComplete = false,
    this.providerId,
  }) : super(type: TunnelMessageTypes.llmStreamChunk);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'requestId': requestId,
    'chunk': chunk,
    'sequenceNumber': sequenceNumber,
    'isComplete': isComplete,
    if (providerId != null) 'providerId': providerId,
  };

  factory LLMStreamChunkMessage.fromJson(Map<String, dynamic> json) =>
      LLMStreamChunkMessage(
        id: json['id'] as String,
        requestId: json['requestId'] as String,
        chunk: json['chunk'] as String,
        sequenceNumber: json['sequenceNumber'] as int,
        isComplete: json['isComplete'] as bool? ?? false,
        providerId: json['providerId'] as String?,
      );

  factory LLMStreamChunkMessage.create(
    String requestId,
    String chunk,
    int sequenceNumber, {
    bool isComplete = false,
    String? providerId,
  }) =>
      LLMStreamChunkMessage(
        id: const Uuid().v4(),
        requestId: requestId,
        chunk: chunk,
        sequenceNumber: sequenceNumber,
        isComplete: isComplete,
        providerId: providerId,
      );
}

/// LLM stream end message to signal completion of streaming
///
/// Sent when a streaming LLM response is complete, providing final
/// statistics and status information.
class LLMStreamEndMessage extends TunnelMessage {
  final String requestId;
  final int totalChunks;
  final Duration totalTime;
  final String? providerId;
  final String? finalStatus;

  const LLMStreamEndMessage({
    required super.id,
    required this.requestId,
    required this.totalChunks,
    required this.totalTime,
    this.providerId,
    this.finalStatus,
  }) : super(type: TunnelMessageTypes.llmStreamEnd);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'requestId': requestId,
    'totalChunks': totalChunks,
    'totalTime': totalTime.inMilliseconds,
    if (providerId != null) 'providerId': providerId,
    if (finalStatus != null) 'finalStatus': finalStatus,
  };

  factory LLMStreamEndMessage.fromJson(Map<String, dynamic> json) =>
      LLMStreamEndMessage(
        id: json['id'] as String,
        requestId: json['requestId'] as String,
        totalChunks: json['totalChunks'] as int,
        totalTime: Duration(milliseconds: json['totalTime'] as int),
        providerId: json['providerId'] as String?,
        finalStatus: json['finalStatus'] as String?,
      );

  factory LLMStreamEndMessage.create(
    String requestId,
    int totalChunks,
    Duration totalTime, {
    String? providerId,
    String? finalStatus,
  }) =>
      LLMStreamEndMessage(
        id: const Uuid().v4(),
        requestId: requestId,
        totalChunks: totalChunks,
        totalTime: totalTime,
        providerId: providerId,
        finalStatus: finalStatus,
      );
}

/// Provider status message for health monitoring
///
/// Used to communicate the status and health information of LLM providers
/// between the desktop client and cloud service.
class ProviderStatusMessage extends TunnelMessage {
  final List<ProviderInfo> providers;
  final DateTime timestamp;

  const ProviderStatusMessage({
    required super.id,
    required this.providers,
    required this.timestamp,
  }) : super(type: TunnelMessageTypes.providerStatus);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'providers': providers.map((p) => p.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory ProviderStatusMessage.fromJson(Map<String, dynamic> json) =>
      ProviderStatusMessage(
        id: json['id'] as String,
        providers: (json['providers'] as List)
            .map((p) => ProviderInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  factory ProviderStatusMessage.create(List<ProviderInfo> providers) =>
      ProviderStatusMessage(
        id: const Uuid().v4(),
        providers: providers,
        timestamp: DateTime.now(),
      );
}

/// Provider information for status reporting
class ProviderInfo {
  final String id;
  final String name;
  final String type;
  final String baseUrl;
  final String status;
  final DateTime lastSeen;
  final List<String> availableModels;
  final Map<String, dynamic> capabilities;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.status,
    required this.lastSeen,
    this.availableModels = const [],
    this.capabilities = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'baseUrl': baseUrl,
    'status': status,
    'lastSeen': lastSeen.toIso8601String(),
    'availableModels': availableModels,
    'capabilities': capabilities,
  };

  factory ProviderInfo.fromJson(Map<String, dynamic> json) => ProviderInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    baseUrl: json['baseUrl'] as String,
    status: json['status'] as String,
    lastSeen: DateTime.parse(json['lastSeen'] as String),
    availableModels: List<String>.from(json['availableModels'] as List? ?? []),
    capabilities: Map<String, dynamic>.from(json['capabilities'] as Map? ?? {}),
  );
}

/// Message type constants for the tunnel protocol
///
/// Defines the standard message types used in the tunnel protocol.
/// These string identifiers are used in JSON serialization to
/// determine the concrete message type during deserialization.
class TunnelMessageTypes {
  static const String httpRequest = 'http_request';
  static const String httpResponse = 'http_response';
  static const String llmRequest = 'llm_request';
  static const String llmResponse = 'llm_response';
  static const String llmStreamChunk = 'llm_stream_chunk';
  static const String llmStreamEnd = 'llm_stream_end';
  static const String providerStatus = 'provider_status';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';

  static const List<String> all = [
    httpRequest,
    httpResponse,
    llmRequest,
    llmResponse,
    llmStreamChunk,
    llmStreamEnd,
    providerStatus,
    ping,
    pong,
    error,
  ];
}

/// HTTP method constants for tunnel requests
///
/// Standard HTTP methods supported by the tunnel protocol.
/// Used to ensure consistent method naming across the system.
class HttpMethods {
  static const String get = 'GET';
  static const String post = 'POST';
  static const String put = 'PUT';
  static const String delete = 'DELETE';
  static const String patch = 'PATCH';
  static const String head = 'HEAD';
  static const String options = 'OPTIONS';

  static const List<String> all = [
    get,
    post,
    put,
    delete,
    patch,
    head,
    options,
  ];
}

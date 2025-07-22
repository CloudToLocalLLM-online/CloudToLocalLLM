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

/// Message type constants for the tunnel protocol
///
/// Defines the standard message types used in the tunnel protocol.
/// These string identifiers are used in JSON serialization to
/// determine the concrete message type during deserialization.
class TunnelMessageTypes {
  static const String httpRequest = 'http_request';
  static const String httpResponse = 'http_response';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';

  static const List<String> all = [
    httpRequest,
    httpResponse,
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

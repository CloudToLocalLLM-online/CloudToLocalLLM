/// Integration tests for the simplified tunnel system components
/// Tests message protocol, HTTP forwarding, and error handling
// ignore_for_file: unused_import
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;

import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([AuthService, http.Client])
import 'tunnel_end_to_end_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestConfig.initialize();

  group('Tunnel Message Protocol Integration Tests', () {
    group('Message Serialization/Deserialization', () {
      test('should serialize and deserialize HTTP request messages', () {
        final request = TunnelRequestMessage(
          id: 'req-123',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        final serialized = TunnelMessageProtocol.serialize(request);
        expect(serialized, isA<String>());

        final deserialized = TunnelMessageProtocol.deserialize(serialized);
        expect(deserialized, isA<TunnelRequestMessage>());
        expect(deserialized.id, equals('req-123'));
        expect((deserialized as TunnelRequestMessage).method, equals('GET'));
        expect(deserialized.path, equals('/api/models'));
      });

      test('should serialize and deserialize HTTP response messages', () {
        final response = TunnelResponseMessage(
          id: 'req-123',
          status: 200,
          headers: {'content-type': 'application/json'},
          body: '{"result": "success"}',
        );

        final serialized = TunnelMessageProtocol.serialize(response);
        expect(serialized, isA<String>());

        final deserialized = TunnelMessageProtocol.deserialize(serialized);
        expect(deserialized, isA<TunnelResponseMessage>());
        expect(deserialized.id, equals('req-123'));
        expect((deserialized as TunnelResponseMessage).status, equals(200));
        expect(deserialized.body, equals('{"result": "success"}'));
      });

      test('should serialize and deserialize ping/pong messages', () {
        final ping = PingMessage.create();
        final serialized = TunnelMessageProtocol.serialize(ping);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized, isA<PingMessage>());
        expect(deserialized.id, equals(ping.id));

        final pong = PongMessage.fromPing(ping);
        final pongSerialized = TunnelMessageProtocol.serialize(pong);
        final pongDeserialized = TunnelMessageProtocol.deserialize(
          pongSerialized,
        );

        expect(pongDeserialized, isA<PongMessage>());
        expect(pongDeserialized.id, equals(ping.id));
      });

      test('should handle error messages', () {
        final error = ErrorMessage(
          id: 'error-123',
          error: 'Test error message',
          code: 500,
        );

        final serialized = TunnelMessageProtocol.serialize(error);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized, isA<ErrorMessage>());
        expect(deserialized.id, equals('error-123'));
        expect(
          (deserialized as ErrorMessage).error,
          equals('Test error message'),
        );
        expect(deserialized.code, equals(500));
      });
    });

    group('Message Protocol Validation', () {
      test('should validate message types', () {
        expect(TunnelMessageTypes.all, contains('http_request'));
        expect(TunnelMessageTypes.all, contains('http_response'));
        expect(TunnelMessageTypes.all, contains('ping'));
        expect(TunnelMessageTypes.all, contains('pong'));
        expect(TunnelMessageTypes.all, contains('error'));
      });

      test('should handle invalid JSON gracefully', () {
        expect(
          () => TunnelMessageProtocol.deserialize('invalid json'),
          throwsA(isA<MessageProtocolException>()),
        );
      });

      test('should handle unknown message types', () {
        final unknownMessage = jsonEncode({
          'type': 'unknown_type',
          'id': 'unknown-123',
        });

        expect(
          () => TunnelMessageProtocol.deserialize(unknownMessage),
          throwsA(isA<MessageProtocolException>()),
        );
      });

      test('should validate required fields', () {
        // Test missing required fields
        final incompleteMessage = jsonEncode({
          'type': 'http_request',
          // Missing id, method, path, headers
        });

        expect(
          () => TunnelMessageProtocol.deserialize(incompleteMessage),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('HTTP Request/Response Conversion', () {
      test('should convert between tunnel messages and HTTP objects', () {
        // Test request conversion
        final httpRequest = HttpRequest(
          method: 'POST',
          path: '/api/chat',
          headers: {'content-type': 'application/json'},
          body: '{"prompt": "Hello"}',
        );

        final tunnelRequest = TunnelRequestMessage.fromHttpRequest(httpRequest);
        expect(tunnelRequest.method, equals('POST'));
        expect(tunnelRequest.path, equals('/api/chat'));
        expect(tunnelRequest.body, equals('{"prompt": "Hello"}'));

        final convertedBack = tunnelRequest.toHttpRequest();
        expect(convertedBack.method, equals(httpRequest.method));
        expect(convertedBack.path, equals(httpRequest.path));
        expect(convertedBack.body, equals(httpRequest.body));

        // Test response conversion
        final httpResponse = HttpResponse(
          status: 200,
          headers: {'content-type': 'application/json'},
          body: '{"response": "Hi there!"}',
        );

        final tunnelResponse = TunnelResponseMessage.fromHttpResponse(
          'req-456',
          httpResponse,
        );
        expect(tunnelResponse.id, equals('req-456'));
        expect(tunnelResponse.status, equals(200));
        expect(tunnelResponse.body, equals('{"response": "Hi there!"}'));

        final responseBack = tunnelResponse.toHttpResponse();
        expect(responseBack.status, equals(httpResponse.status));
        expect(responseBack.body, equals(httpResponse.body));
      });
    });

    group('End-to-End Message Flow Simulation', () {
      test('should simulate complete request/response cycle', () {
        // Step 1: Create incoming request from cloud
        final incomingRequest = TunnelRequestMessage(
          id: 'e2e-test-123',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        // Step 2: Serialize for transmission
        final requestJson = TunnelMessageProtocol.serialize(incomingRequest);
        expect(requestJson, isA<String>());

        // Step 3: Deserialize on client side
        final deserializedRequest = TunnelMessageProtocol.deserialize(
          requestJson,
        );
        expect(deserializedRequest, isA<TunnelRequestMessage>());

        // Step 4: Convert to HTTP request for local processing
        final httpRequest = (deserializedRequest as TunnelRequestMessage)
            .toHttpRequest();
        expect(httpRequest.method, equals('GET'));
        expect(httpRequest.path, equals('/api/models'));

        // Step 5: Simulate HTTP response from local Ollama
        final httpResponse = HttpResponse(
          status: 200,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'models': [
              {'name': 'llama2'},
            ],
          }),
        );

        // Step 6: Convert back to tunnel response
        final tunnelResponse = TunnelResponseMessage.fromHttpResponse(
          incomingRequest.id,
          httpResponse,
        );
        expect(tunnelResponse.id, equals(incomingRequest.id));
        expect(tunnelResponse.status, equals(200));

        // Step 7: Serialize response for transmission back to cloud
        final responseJson = TunnelMessageProtocol.serialize(tunnelResponse);
        expect(responseJson, isA<String>());

        // Step 8: Verify round-trip integrity
        final finalResponse = TunnelMessageProtocol.deserialize(responseJson);
        expect(finalResponse, isA<TunnelResponseMessage>());
        expect(finalResponse.id, equals(incomingRequest.id));
        expect((finalResponse as TunnelResponseMessage).status, equals(200));
      });

      test('should simulate ping/pong health check cycle', () {
        // Step 1: Create ping from cloud
        final ping = PingMessage.create();
        expect(ping.id, isNotEmpty);
        expect(ping.timestamp, isNotEmpty);

        // Step 2: Serialize ping
        final pingJson = TunnelMessageProtocol.serialize(ping);

        // Step 3: Deserialize on client
        final deserializedPing = TunnelMessageProtocol.deserialize(pingJson);
        expect(deserializedPing, isA<PingMessage>());

        // Step 4: Create pong response
        final pong = PongMessage.fromPing(deserializedPing as PingMessage);
        expect(pong.id, equals(ping.id));

        // Step 5: Serialize pong
        final pongJson = TunnelMessageProtocol.serialize(pong);

        // Step 6: Verify pong can be deserialized
        final finalPong = TunnelMessageProtocol.deserialize(pongJson);
        expect(finalPong, isA<PongMessage>());
        expect(finalPong.id, equals(ping.id));
      });

      test('should simulate error handling flow', () {
        // Step 1: Create request that will cause error
        final request = TunnelRequestMessage(
          id: 'error-test-456',
          method: 'GET',
          path: '/api/nonexistent',
          headers: {'accept': 'application/json'},
        );

        // Step 2: Simulate error response
        final errorResponse = TunnelResponseMessage(
          id: request.id,
          status: 404,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'error': 'Not found',
            'message': 'The requested endpoint does not exist',
          }),
        );

        // Step 3: Verify error response structure
        expect(errorResponse.id, equals(request.id));
        expect(errorResponse.status, equals(404));

        final errorBody = jsonDecode(errorResponse.body);
        expect(errorBody['error'], equals('Not found'));

        // Step 4: Test serialization/deserialization of error
        final serialized = TunnelMessageProtocol.serialize(errorResponse);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized, isA<TunnelResponseMessage>());
        expect((deserialized as TunnelResponseMessage).status, equals(404));
      });
    });
  });
}

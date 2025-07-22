/// Integration test for message protocol between Dart and JavaScript implementations
/// Verifies that messages created in Dart can be understood by JavaScript and vice versa
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';

void main() {
  group('Message Protocol Integration', () {
    test('should create compatible message formats', () {
      // Test HTTP request message
      final httpRequest = HttpRequest(
        method: 'POST',
        path: '/api/chat',
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer token123',
        },
        body: '{"model": "llama2", "prompt": "Hello"}',
      );

      final requestMessage = TunnelMessageProtocol.createRequestMessage(
        httpRequest,
      );
      final serialized = TunnelMessageProtocol.serialize(requestMessage);

      // Verify the serialized format matches expected structure
      expect(serialized, contains('"type":"http_request"'));
      expect(serialized, contains('"method":"POST"'));
      expect(serialized, contains('"path":"/api/chat"'));
      expect(serialized, contains('"content-type":"application/json"'));
      expect(serialized, contains('"authorization":"Bearer token123"'));
      expect(
        serialized,
        contains('\\"model\\": \\"llama2\\"'),
      ); // JSON is escaped in the serialized string

      // Test deserialization
      final deserialized = TunnelMessageProtocol.deserialize(serialized);
      expect(deserialized, isA<TunnelRequestMessage>());

      final deserializedRequest = deserialized as TunnelRequestMessage;
      expect(deserializedRequest.method, equals('POST'));
      expect(deserializedRequest.path, equals('/api/chat'));
      expect(
        deserializedRequest.headers['content-type'],
        equals('application/json'),
      );
      expect(
        deserializedRequest.body,
        equals('{"model": "llama2", "prompt": "Hello"}'),
      );
    });

    test('should handle response messages correctly', () {
      final httpResponse = HttpResponse(
        status: 200,
        headers: {
          'content-type': 'application/json',
          'x-response-time': '150ms',
        },
        body: '{"response": "Hello! How can I help you today?"}',
      );

      final responseMessage = TunnelMessageProtocol.createResponseMessage(
        'req-123',
        httpResponse,
      );
      final serialized = TunnelMessageProtocol.serialize(responseMessage);

      // Verify serialized format
      expect(serialized, contains('"type":"http_response"'));
      expect(serialized, contains('"id":"req-123"'));
      expect(serialized, contains('"status":200'));
      expect(serialized, contains('"content-type":"application/json"'));
      expect(
        serialized,
        contains('\\"response\\": \\"Hello! How can I help you today?\\"'),
      ); // JSON is escaped in the serialized string

      // Test round-trip
      final deserialized = TunnelMessageProtocol.deserialize(serialized);
      expect(deserialized, isA<TunnelResponseMessage>());

      final deserializedResponse = deserialized as TunnelResponseMessage;
      expect(deserializedResponse.id, equals('req-123'));
      expect(deserializedResponse.status, equals(200));
      expect(deserializedResponse.headers['x-response-time'], equals('150ms'));
      expect(
        deserializedResponse.body,
        equals('{"response": "Hello! How can I help you today?"}'),
      );
    });

    test('should handle ping/pong messages', () {
      final ping = TunnelMessageProtocol.createPingMessage();
      final pong = TunnelMessageProtocol.createPongMessage(ping.id);

      final pingSerialized = TunnelMessageProtocol.serialize(ping);
      final pongSerialized = TunnelMessageProtocol.serialize(pong);

      // Verify ping format
      expect(pingSerialized, contains('"type":"ping"'));
      expect(pingSerialized, contains('"timestamp"'));

      // Verify pong format
      expect(pongSerialized, contains('"type":"pong"'));
      expect(pongSerialized, contains('"id":"${ping.id}"'));

      // Test deserialization
      final deserializedPing = TunnelMessageProtocol.deserialize(
        pingSerialized,
      );
      final deserializedPong = TunnelMessageProtocol.deserialize(
        pongSerialized,
      );

      expect(deserializedPing, isA<PingMessage>());
      expect(deserializedPong, isA<PongMessage>());
      expect((deserializedPong as PongMessage).id, equals(ping.id));
    });

    test('should handle error messages', () {
      final errorMessage = TunnelMessageProtocol.createErrorMessage(
        'req-456',
        'Connection timeout',
        504,
      );

      final serialized = TunnelMessageProtocol.serialize(errorMessage);

      expect(serialized, contains('"type":"error"'));
      expect(serialized, contains('"id":"req-456"'));
      expect(serialized, contains('"error":"Connection timeout"'));
      expect(serialized, contains('"code":504'));

      final deserialized = TunnelMessageProtocol.deserialize(serialized);
      expect(deserialized, isA<ErrorMessage>());

      final deserializedError = deserialized as ErrorMessage;
      expect(deserializedError.id, equals('req-456'));
      expect(deserializedError.error, equals('Connection timeout'));
      expect(deserializedError.code, equals(504));
    });

    test('should validate message compatibility', () {
      // Create messages that would be sent between JavaScript and Dart
      final testMessages = [
        // JavaScript-style request message JSON
        '{"type":"http_request","id":"js-req-123","method":"GET","path":"/api/models","headers":{"accept":"application/json"}}',

        // JavaScript-style response message JSON
        '{"type":"http_response","id":"js-req-123","status":200,"headers":{"content-type":"application/json"},"body":"{\\"models\\":[\\"llama2\\",\\"codellama\\"]}"}',

        // JavaScript-style ping message JSON
        '{"type":"ping","id":"js-ping-456","timestamp":"2025-01-15T10:30:00.000Z"}',

        // JavaScript-style error message JSON
        '{"type":"error","id":"js-req-789","error":"Model not found","code":404}',
      ];

      for (final messageJson in testMessages) {
        // Should be able to deserialize JavaScript-created messages
        expect(
          () => TunnelMessageProtocol.deserialize(messageJson),
          returnsNormally,
        );

        final message = TunnelMessageProtocol.deserialize(messageJson);
        expect(TunnelMessageProtocol.validateTunnelMessage(message), isTrue);

        // Should be able to re-serialize them
        final reSerialized = TunnelMessageProtocol.serialize(message);
        expect(reSerialized, isNotEmpty);

        // Should be able to deserialize our own serialization
        final reDeserialized = TunnelMessageProtocol.deserialize(reSerialized);
        expect(reDeserialized.type, equals(message.type));
        expect(reDeserialized.id, equals(message.id));
      }
    });
  });
}

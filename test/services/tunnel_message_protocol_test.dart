/// Unit tests for the tunnel message protocol
/// Tests message serialization, deserialization, validation, and edge cases
// ignore_for_file: unnecessary_type_check, dangling_library_doc_comments

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';

void main() {
  group('TunnelMessageProtocol', () {
    group('createRequestMessage', () {
      test('should create valid request message from HTTP request', () {
        final httpRequest = HttpRequest(
          method: 'POST',
          path: '/api/chat',
          headers: {'content-type': 'application/json'},
          body: '{"message": "hello"}',
        );

        final message = TunnelMessageProtocol.createRequestMessage(httpRequest);

        expect(message.type, equals(TunnelMessageTypes.httpRequest));
        expect(message.id, isNotEmpty);
        expect(message.method, equals('POST'));
        expect(message.path, equals('/api/chat'));
        expect(message.headers, equals({'content-type': 'application/json'}));
        expect(message.body, equals('{"message": "hello"}'));
      });

      test('should create request message without body', () {
        final httpRequest = HttpRequest(
          method: 'GET',
          path: '/api/status',
          headers: {},
        );

        final message = TunnelMessageProtocol.createRequestMessage(httpRequest);

        expect(message.type, equals(TunnelMessageTypes.httpRequest));
        expect(message.method, equals('GET'));
        expect(message.path, equals('/api/status'));
        expect(message.body, isNull);
      });

      test('should throw error for invalid HTTP request', () {
        final invalidRequest = HttpRequest(
          method: 'INVALID',
          path: '/api/test',
          headers: {},
        );

        expect(
          () => TunnelMessageProtocol.createRequestMessage(invalidRequest),
          throwsA(isA<MessageProtocolException>()),
        );
      });

      test('should throw error for empty path', () {
        final incompleteRequest = HttpRequest(
          method: 'GET',
          path: '',
          headers: {},
        );

        expect(
          () => TunnelMessageProtocol.createRequestMessage(incompleteRequest),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('createResponseMessage', () {
      test('should create valid response message', () {
        const requestId = 'test-request-id';
        final httpResponse = HttpResponse(
          status: 200,
          headers: {'content-type': 'application/json'},
          body: '{"result": "success"}',
        );

        final message = TunnelMessageProtocol.createResponseMessage(
          requestId,
          httpResponse,
        );

        expect(message.type, equals(TunnelMessageTypes.httpResponse));
        expect(message.id, equals(requestId));
        expect(message.status, equals(200));
        expect(message.headers, equals({'content-type': 'application/json'}));
        expect(message.body, equals('{"result": "success"}'));
      });

      test('should throw error for empty request ID', () {
        final httpResponse = HttpResponse(status: 200, headers: {}, body: 'OK');

        expect(
          () => TunnelMessageProtocol.createResponseMessage('', httpResponse),
          throwsA(isA<MessageProtocolException>()),
        );
      });

      test('should throw error for invalid HTTP response', () {
        final invalidResponse = HttpResponse(
          status: 999, // invalid status code
          headers: {},
          body: 'test',
        );

        expect(
          () => TunnelMessageProtocol.createResponseMessage(
            'test-id',
            invalidResponse,
          ),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('createPingMessage', () {
      test('should create valid ping message', () {
        final message = TunnelMessageProtocol.createPingMessage();

        expect(message.type, equals(TunnelMessageTypes.ping));
        expect(message.id, isNotEmpty);
        expect(message.timestamp, isNotEmpty);
        expect(() => DateTime.parse(message.timestamp), returnsNormally);
      });
    });

    group('createPongMessage', () {
      test('should create valid pong message', () {
        const pingId = 'ping-123';
        final message = TunnelMessageProtocol.createPongMessage(pingId);

        expect(message.type, equals(TunnelMessageTypes.pong));
        expect(message.id, equals(pingId));
        expect(message.timestamp, isNotEmpty);
        expect(() => DateTime.parse(message.timestamp), returnsNormally);
      });

      test('should throw error for empty ping ID', () {
        expect(
          () => TunnelMessageProtocol.createPongMessage(''),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('createErrorMessage', () {
      test('should create valid error message', () {
        const requestId = 'req-123';
        const error = 'Connection failed';
        const code = 500;

        final message = TunnelMessageProtocol.createErrorMessage(
          requestId,
          error,
          code,
        );

        expect(message.type, equals(TunnelMessageTypes.error));
        expect(message.id, equals(requestId));
        expect(message.error, equals(error));
        expect(message.code, equals(code));
      });

      test('should create error message without code', () {
        const requestId = 'req-123';
        const error = 'Connection failed';

        final message = TunnelMessageProtocol.createErrorMessage(
          requestId,
          error,
        );

        expect(message.type, equals(TunnelMessageTypes.error));
        expect(message.id, equals(requestId));
        expect(message.error, equals(error));
        expect(message.code, isNull);
      });

      test('should throw error for invalid parameters', () {
        expect(
          () => TunnelMessageProtocol.createErrorMessage('', 'error'),
          throwsA(isA<MessageProtocolException>()),
        );

        expect(
          () => TunnelMessageProtocol.createErrorMessage('req-123', ''),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('serialize and deserialize', () {
      test('should serialize and deserialize request message', () {
        final original = TunnelMessageProtocol.createRequestMessage(
          HttpRequest(
            method: 'POST',
            path: '/api/test',
            headers: {'content-type': 'application/json'},
            body: '{"test": true}',
          ),
        );

        final serialized = TunnelMessageProtocol.serialize(original);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized.type, equals(original.type));
        expect(deserialized.id, equals(original.id));
        if (deserialized is TunnelRequestMessage &&
            original is TunnelRequestMessage) {
          expect(deserialized.method, equals(original.method));
          expect(deserialized.path, equals(original.path));
          expect(deserialized.headers, equals(original.headers));
          expect(deserialized.body, equals(original.body));
        }
      });

      test('should serialize and deserialize response message', () {
        final original = TunnelMessageProtocol.createResponseMessage(
          'req-123',
          HttpResponse(
            status: 200,
            headers: {'content-type': 'text/plain'},
            body: 'OK',
          ),
        );

        final serialized = TunnelMessageProtocol.serialize(original);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized.type, equals(original.type));
        expect(deserialized.id, equals(original.id));
        if (deserialized is TunnelResponseMessage &&
            original is TunnelResponseMessage) {
          expect(deserialized.status, equals(original.status));
          expect(deserialized.headers, equals(original.headers));
          expect(deserialized.body, equals(original.body));
        }
      });

      test('should serialize and deserialize ping message', () {
        final original = TunnelMessageProtocol.createPingMessage();

        final serialized = TunnelMessageProtocol.serialize(original);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        expect(deserialized.type, equals(original.type));
        expect(deserialized.id, equals(original.id));
        if (deserialized is PingMessage && original is PingMessage) {
          expect(deserialized.timestamp, equals(original.timestamp));
        }
      });

      test('should throw error for invalid JSON', () {
        expect(
          () => TunnelMessageProtocol.deserialize('invalid json'),
          throwsA(isA<MessageProtocolException>()),
        );

        expect(
          () => TunnelMessageProtocol.deserialize(''),
          throwsA(isA<MessageProtocolException>()),
        );
      });

      test('should throw error for invalid message format', () {
        const invalidMessage = '{"type": "invalid", "id": "test"}';

        expect(
          () => TunnelMessageProtocol.deserialize(invalidMessage),
          throwsA(isA<MessageProtocolException>()),
        );
      });
    });

    group('validation methods', () {
      group('validateHttpRequest', () {
        test('should validate correct HTTP request', () {
          final validRequest = HttpRequest(
            method: 'GET',
            path: '/api/test',
            headers: {},
          );

          expect(
            TunnelMessageProtocol.validateHttpRequest(validRequest),
            isTrue,
          );
        });

        test('should reject invalid HTTP methods', () {
          final invalidRequest = HttpRequest(
            method: 'INVALID',
            path: '/api/test',
            headers: {},
          );

          expect(
            TunnelMessageProtocol.validateHttpRequest(invalidRequest),
            isFalse,
          );
        });

        test('should reject empty path', () {
          final invalidRequest = HttpRequest(
            method: 'GET',
            path: '',
            headers: {},
          );

          expect(
            TunnelMessageProtocol.validateHttpRequest(invalidRequest),
            isFalse,
          );
        });
      });

      group('validateHttpResponse', () {
        test('should validate correct HTTP response', () {
          final validResponse = HttpResponse(
            status: 200,
            headers: {},
            body: 'OK',
          );

          expect(
            TunnelMessageProtocol.validateHttpResponse(validResponse),
            isTrue,
          );
        });

        test('should reject invalid status codes', () {
          final invalidResponse = HttpResponse(
            status: 999,
            headers: {},
            body: 'OK',
          );

          expect(
            TunnelMessageProtocol.validateHttpResponse(invalidResponse),
            isFalse,
          );
        });

        test('should accept various valid status codes', () {
          final statusCodes = [100, 200, 201, 400, 401, 404, 500, 502, 503];

          for (final status in statusCodes) {
            final response = HttpResponse(
              status: status,
              headers: {},
              body: 'test',
            );

            expect(
              TunnelMessageProtocol.validateHttpResponse(response),
              isTrue,
            );
          }
        });
      });

      group('validateTunnelMessage', () {
        test('should validate all message types', () {
          final requestMessage = TunnelMessageProtocol.createRequestMessage(
            HttpRequest(method: 'GET', path: '/test', headers: {}),
          );

          final responseMessage = TunnelMessageProtocol.createResponseMessage(
            'req-123',
            HttpResponse(status: 200, headers: {}, body: 'OK'),
          );

          final pingMessage = TunnelMessageProtocol.createPingMessage();
          final pongMessage = TunnelMessageProtocol.createPongMessage(
            'ping-123',
          );
          final errorMessage = TunnelMessageProtocol.createErrorMessage(
            'req-123',
            'Error',
          );

          expect(
            TunnelMessageProtocol.validateTunnelMessage(requestMessage),
            isTrue,
          );
          expect(
            TunnelMessageProtocol.validateTunnelMessage(responseMessage),
            isTrue,
          );
          expect(
            TunnelMessageProtocol.validateTunnelMessage(pingMessage),
            isTrue,
          );
          expect(
            TunnelMessageProtocol.validateTunnelMessage(pongMessage),
            isTrue,
          );
          expect(
            TunnelMessageProtocol.validateTunnelMessage(errorMessage),
            isTrue,
          );
        });
      });
    });

    group('extract methods', () {
      test('should extract HTTP request from tunnel message', () {
        final original = HttpRequest(
          method: 'POST',
          path: '/api/test',
          headers: {'content-type': 'application/json'},
          body: '{"test": true}',
        );

        final tunnelMessage = TunnelMessageProtocol.createRequestMessage(
          original,
        );
        final extracted = TunnelMessageProtocol.extractHttpRequest(
          tunnelMessage,
        );

        expect(extracted.method, equals(original.method));
        expect(extracted.path, equals(original.path));
        expect(extracted.headers, equals(original.headers));
        expect(extracted.body, equals(original.body));
      });

      test('should extract HTTP response from tunnel message', () {
        final original = HttpResponse(
          status: 200,
          headers: {'content-type': 'text/plain'},
          body: 'OK',
        );

        final tunnelMessage = TunnelMessageProtocol.createResponseMessage(
          'req-123',
          original,
        );
        final extracted = TunnelMessageProtocol.extractHttpResponse(
          tunnelMessage,
        );

        expect(extracted.status, equals(original.status));
        expect(extracted.headers, equals(original.headers));
        expect(extracted.body, equals(original.body));
      });
    });

    group('edge cases', () {
      test('should handle empty headers', () {
        final request = TunnelMessageProtocol.createRequestMessage(
          HttpRequest(method: 'GET', path: '/test', headers: {}),
        );

        expect(request.headers, equals({}));
      });

      test('should handle missing optional body', () {
        final request = TunnelMessageProtocol.createRequestMessage(
          HttpRequest(method: 'GET', path: '/test', headers: {}),
        );

        expect(request.body, isNull);
      });

      test('should handle all HTTP methods', () {
        for (final method in HttpMethods.all) {
          final request = TunnelMessageProtocol.createRequestMessage(
            HttpRequest(method: method, path: '/test', headers: {}),
          );

          expect(request.method, equals(method));
          expect(TunnelMessageProtocol.validateTunnelMessage(request), isTrue);
        }
      });

      test('should handle large message bodies', () {
        final largeBody = 'x' * 10000;
        final request = TunnelMessageProtocol.createRequestMessage(
          HttpRequest(
            method: 'POST',
            path: '/test',
            headers: {'content-length': largeBody.length.toString()},
            body: largeBody,
          ),
        );

        final serialized = TunnelMessageProtocol.serialize(request);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        if (deserialized is TunnelRequestMessage) {
          expect(deserialized.body, equals(largeBody));
        }
      });

      test('should handle special characters in paths and headers', () {
        final request = TunnelMessageProtocol.createRequestMessage(
          HttpRequest(
            method: 'GET',
            path: '/api/test?param=value&other=测试',
            headers: {'x-custom-header': 'special-value-测试'},
          ),
        );

        final serialized = TunnelMessageProtocol.serialize(request);
        final deserialized = TunnelMessageProtocol.deserialize(serialized);

        if (deserialized is TunnelRequestMessage) {
          expect(deserialized.path, equals('/api/test?param=value&other=测试'));
          expect(
            deserialized.headers['x-custom-header'],
            equals('special-value-测试'),
          );
        }
      });

      test('should handle timestamp validation in ping/pong messages', () {
        final ping = PingMessage.create();
        final pong = PongMessage.fromPing(ping);

        expect(TunnelMessageProtocol.validateTunnelMessage(ping), isTrue);
        expect(TunnelMessageProtocol.validateTunnelMessage(pong), isTrue);

        // Test with custom timestamp
        final customPing = PingMessage(
          id: 'test-id',
          timestamp: DateTime.now().toIso8601String(),
        );

        expect(TunnelMessageProtocol.validateTunnelMessage(customPing), isTrue);
      });
    });
  });
}

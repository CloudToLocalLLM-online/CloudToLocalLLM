import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/tunnel_llm_request_handler.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/models/llm_communication_error.dart';

void main() {
  group('TunnelLLMRequestHandler', () {

    group('TunnelLLMRequest', () {
      test('should create from tunnel request message', () {
        final tunnelRequest = TunnelRequestMessage(
          id: 'test-id',
          method: 'POST',
          path: '/api/generate',
          headers: {'content-type': 'application/json'},
          body: '{"prompt": "Hello", "stream": false}',
        );

        final llmRequest = TunnelLLMRequest.fromTunnelRequest(tunnelRequest);

        expect(llmRequest.id, equals('test-id'));
        expect(llmRequest.type, equals(LLMRequestType.textGeneration));
        expect(llmRequest.method, equals('POST'));
        expect(llmRequest.path, equals('/api/generate'));
        expect(llmRequest.isStreaming, isFalse);
        expect(llmRequest.priority, equals(RequestPriority.high));
      });

      test('should detect streaming requests', () {
        final tunnelRequest = TunnelRequestMessage(
          id: 'test-id',
          method: 'POST',
          path: '/api/chat',
          headers: {'content-type': 'application/json'},
          body: '{"prompt": "Hello", "stream": true}',
        );

        final llmRequest = TunnelLLMRequest.fromTunnelRequest(tunnelRequest);

        expect(llmRequest.type, equals(LLMRequestType.streamingGeneration));
        expect(llmRequest.isStreaming, isTrue);
      });

      test('should infer correct request types', () {
        final testCases = [
          ('/api/generate', LLMRequestType.textGeneration),
          ('/api/chat', LLMRequestType.streamingGeneration),
          ('/api/tags', LLMRequestType.modelList),
          ('/v1/models', LLMRequestType.modelList),
          ('/api/pull', LLMRequestType.modelPull),
          ('/api/delete', LLMRequestType.modelDelete),
          ('/api/show', LLMRequestType.modelInfo),
          ('/health', LLMRequestType.healthCheck),
          ('/unknown', LLMRequestType.unknown),
        ];

        for (final testCase in testCases) {
          final path = testCase.$1;
          final expectedType = testCase.$2;

          final tunnelRequest = TunnelRequestMessage(
            id: 'test-id',
            method: 'GET',
            path: path,
            headers: {},
          );

          final llmRequest = TunnelLLMRequest.fromTunnelRequest(tunnelRequest);
          expect(llmRequest.type, equals(expectedType), reason: 'Failed for path: $path');
        }
      });

      test('should extract custom timeout from headers', () {
        final tunnelRequest = TunnelRequestMessage(
          id: 'test-id',
          method: 'POST',
          path: '/api/generate',
          headers: {
            'content-type': 'application/json',
            'x-request-timeout': '120',
          },
          body: '{"prompt": "Hello"}',
        );

        final llmRequest = TunnelLLMRequest.fromTunnelRequest(tunnelRequest);

        expect(llmRequest.customTimeout, equals(const Duration(seconds: 120)));
      });

      test('should extract preferred provider from headers', () {
        final tunnelRequest = TunnelRequestMessage(
          id: 'test-id',
          method: 'POST',
          path: '/api/generate',
          headers: {
            'content-type': 'application/json',
            'x-preferred-provider': 'ollama-local',
          },
          body: '{"prompt": "Hello"}',
        );

        final llmRequest = TunnelLLMRequest.fromTunnelRequest(tunnelRequest);

        expect(llmRequest.preferredProvider, equals('ollama-local'));
      });
    });

    group('TunnelLLMResponse', () {
      test('should create success response', () {
        final response = TunnelLLMResponse.success(
          requestId: 'test-id',
          body: '{"result": "Hello World"}',
          providerId: 'test-provider',
        );

        expect(response.requestId, equals('test-id'));
        expect(response.status, equals(200));
        expect(response.body, equals('{"result": "Hello World"}'));
        expect(response.providerId, equals('test-provider'));
        expect(response.headers['content-type'], equals('application/json'));
      });

      test('should create error response', () {
        final error = LLMCommunicationError.providerNotFound(
          requestId: 'test-id',
          providerId: 'missing-provider',
        );

        final response = TunnelLLMResponse.error(
          requestId: 'test-id',
          error: error,
        );

        expect(response.requestId, equals('test-id'));
        expect(response.status, equals(404));
        expect(response.error, equals(error));
        expect(response.headers['content-type'], equals('application/json'));
      });

      test('should convert to tunnel response message', () {
        final response = TunnelLLMResponse.success(
          requestId: 'test-id',
          body: '{"result": "success"}',
        );

        final tunnelResponse = response.toTunnelResponse();

        expect(tunnelResponse.id, equals('test-id'));
        expect(tunnelResponse.status, equals(200));
        expect(tunnelResponse.body, equals('{"result": "success"}'));
      });
    });


  });
}
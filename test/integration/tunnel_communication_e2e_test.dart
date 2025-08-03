/// End-to-End Tunnel Communication Tests
///
/// Tests complete request flow from web interface to LLM provider including:
/// - HTTP polling tunnel communication
/// - Different request types (chat, model operations, streaming)
/// - Timeout and error handling scenarios
/// - Provider routing and failover
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:cloudtolocalllm/services/http_polling_tunnel_client.dart';
import 'package:cloudtolocalllm/services/tunnel_llm_request_handler.dart';
import 'package:cloudtolocalllm/services/llm_provider_manager.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/langchain_integration_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/llm_error_handler.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/utils/tunnel_logger.dart';

void main() {
  group('End-to-End Tunnel Communication', () {
    late MockAuthService mockAuthService;
    late MockLLMProviderManager mockProviderManager;
    late MockLLMErrorHandler mockErrorHandler;
    late TunnelLogger logger;
    late HttpPollingTunnelClient tunnelClient;
    late TunnelLLMRequestHandler requestHandler;

    setUp(() {
      mockAuthService = MockAuthService();
      mockProviderManager = MockLLMProviderManager();
      mockErrorHandler = MockLLMErrorHandler();
      logger = TunnelLogger('E2ETest');

      // Set up authenticated state
      mockAuthService.setAuthenticated(true);
      mockAuthService.setAccessToken('test_token_123');

      // Set up available providers
      mockProviderManager.setAvailableProviders([
        createMockOllamaProvider(),
        createMockLMStudioProvider(),
      ]);

      tunnelClient = HttpPollingTunnelClient(
        authService: mockAuthService,
        logger: logger,
        providerManager: mockProviderManager,
      );

      requestHandler = TunnelLLMRequestHandler(
        providerManager: mockProviderManager,
        errorHandler: mockErrorHandler,
      );
    });

    tearDown(() {
      tunnelClient.dispose();
      requestHandler.dispose();
    });

    group('Chat Request Flow', () {
      test('should handle complete chat request flow', () async {
        // Simulate incoming chat request from web interface
        final chatRequest = TunnelRequestMessage(
          id: 'chat_request_001',
          method: 'POST',
          path: '/api/chat',
          headers: {
            'Content-Type': 'application/json',
            'X-Provider-Preference': 'ollama_11434',
          },
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'Hello, how are you?'}
            ],
            'stream': false,
          }),
        );

        // Mock successful provider response
        mockProviderManager.setChatResponse(
          'ollama_11434',
          'Hello! I\'m doing well, thank you for asking. How can I help you today?',
        );

        // Process the request
        final response = await requestHandler.handleLLMRequest(chatRequest);

        expect(response.status, equals(200));
        expect(response.requestId, equals('chat_request_001'));
        expect(response.providerId, equals('ollama_11434'));
        expect(response.error, isNull);

        final responseBody = jsonDecode(response.body);
        expect(responseBody['response'], contains('Hello! I\'m doing well'));
      });

      test('should handle chat request with provider failover', () async {
        final chatRequest = TunnelRequestMessage(
          id: 'chat_request_002',
          method: 'POST',
          path: '/api/chat',
          headers: {
            'Content-Type': 'application/json',
            'X-Provider-Preference': 'ollama_11434',
          },
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'What is the weather like?'}
            ],
          }),
        );

        // Primary provider fails
        mockProviderManager.setChatError(
          'ollama_11434',
          Exception('Ollama service unavailable'),
        );

        // Secondary provider succeeds
        mockProviderManager.setChatResponse(
          'lmstudio_1234',
          'I don\'t have access to real-time weather data, but I can help you with other questions.',
        );

        // Configure error handler for failover
        mockErrorHandler.setFailoverProvider('lmstudio_1234');

        final response = await requestHandler.handleLLMRequest(chatRequest);

        expect(response.status, equals(200));
        expect(response.providerId, equals('lmstudio_1234'));
        
        final responseBody = jsonDecode(response.body);
        expect(responseBody['response'], contains('don\'t have access to real-time weather'));
      });

      test('should handle chat request timeout', () async {
        final chatRequest = TunnelRequestMessage(
          id: 'chat_request_003',
          method: 'POST',
          path: '/api/chat',
          headers: {
            'Content-Type': 'application/json',
            'X-Request-Timeout': '5000', // 5 second timeout
          },
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'This should timeout'}
            ],
          }),
        );

        // Mock timeout scenario
        mockProviderManager.setChatTimeout('ollama_11434', Duration(seconds: 10));

        final response = await requestHandler.handleLLMRequest(chatRequest);

        expect(response.status, equals(408)); // Request Timeout
        expect(response.error, isNotNull);
        expect(response.error!.type.toString(), contains('timeout'));
      });
    });

    group('Streaming Request Flow', () {
      test('should handle streaming chat request', () async {
        final streamingRequest = TunnelRequestMessage(
          id: 'stream_request_001',
          method: 'POST',
          path: '/api/chat',
          headers: {
            'Content-Type': 'application/json',
            'X-Provider-Preference': 'ollama_11434',
          },
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'Tell me a short story'}
            ],
            'stream': true,
          }),
        );

        // Mock streaming response
        final streamChunks = [
          'Once upon a time,',
          ' there was a brave knight',
          ' who embarked on a quest',
          ' to find the lost treasure.',
          ' The end.'
        ];

        mockProviderManager.setStreamingResponse('ollama_11434', streamChunks);

        final responseChunks = <String>[];
        await for (final chunk in requestHandler.handleStreamingRequest(streamingRequest)) {
          responseChunks.add(chunk.body);
        }

        expect(responseChunks, hasLength(streamChunks.length));
        
        // Verify each chunk contains expected content
        for (int i = 0; i < streamChunks.length; i++) {
          final chunkData = jsonDecode(responseChunks[i]);
          expect(chunkData['chunk'], equals(streamChunks[i]));
        }
      });

      test('should handle streaming interruption', () async {
        final streamingRequest = TunnelRequestMessage(
          id: 'stream_request_002',
          method: 'POST',
          path: '/api/chat',
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'Start a story but fail midway'}
            ],
            'stream': true,
          }),
        );

        // Mock streaming failure after 2 chunks
        mockProviderManager.setStreamingFailure(
          'ollama_11434',
          ['Once upon', ' a time'],
          Exception('Connection lost'),
        );

        final responseChunks = <String>[];
        bool errorOccurred = false;

        try {
          await for (final chunk in requestHandler.handleStreamingRequest(streamingRequest)) {
            responseChunks.add(chunk.body);
          }
        } catch (e) {
          errorOccurred = true;
        }

        expect(errorOccurred, isTrue);
        expect(responseChunks, hasLength(2)); // Should have received 2 chunks before failure
      });
    });

    group('Model Operations', () {
      test('should handle model list request', () async {
        final modelListRequest = TunnelRequestMessage(
          id: 'model_list_001',
          method: 'GET',
          path: '/api/tags',
          headers: {'Accept': 'application/json'},
        );

        // Mock model list response
        mockProviderManager.setModelList('ollama_11434', [
          'llama2:latest',
          'codellama:latest',
          'mistral:latest',
        ]);

        final response = await requestHandler.handleLLMRequest(modelListRequest);

        expect(response.status, equals(200));
        
        final responseBody = jsonDecode(response.body);
        expect(responseBody['models'], hasLength(3));
        expect(responseBody['models'], contains('llama2:latest'));
        expect(responseBody['models'], contains('codellama:latest'));
        expect(responseBody['models'], contains('mistral:latest'));
      });

      test('should handle model info request', () async {
        final modelInfoRequest = TunnelRequestMessage(
          id: 'model_info_001',
          method: 'GET',
          path: '/api/show/llama2:latest',
          headers: {'Accept': 'application/json'},
        );

        // Mock model info response
        mockProviderManager.setModelInfo('ollama_11434', 'llama2:latest', {
          'name': 'llama2:latest',
          'size': 3825819519,
          'digest': 'sha256:abc123...',
          'details': {
            'format': 'gguf',
            'family': 'llama',
            'families': ['llama'],
            'parameter_size': '7B',
            'quantization_level': 'Q4_0',
          }
        });

        final response = await requestHandler.handleLLMRequest(modelInfoRequest);

        expect(response.status, equals(200));
        
        final responseBody = jsonDecode(response.body);
        expect(responseBody['name'], equals('llama2:latest'));
        expect(responseBody['size'], equals(3825819519));
        expect(responseBody['details']['parameter_size'], equals('7B'));
      });
    });

    group('Error Handling Scenarios', () {
      test('should handle malformed request', () async {
        final malformedRequest = TunnelRequestMessage(
          id: 'malformed_001',
          method: 'POST',
          path: '/api/chat',
          headers: {'Content-Type': 'application/json'},
          body: 'invalid json content',
        );

        final response = await requestHandler.handleLLMRequest(malformedRequest);

        expect(response.status, equals(400)); // Bad Request
        expect(response.error, isNotNull);
        expect(response.error!.type.toString(), contains('malformed'));
      });

      test('should handle provider not found', () async {
        final request = TunnelRequestMessage(
          id: 'no_provider_001',
          method: 'POST',
          path: '/api/chat',
          headers: {
            'Content-Type': 'application/json',
            'X-Provider-Preference': 'nonexistent_provider',
          },
          body: jsonEncode({
            'model': 'some-model',
            'messages': [
              {'role': 'user', 'content': 'Hello'}
            ],
          }),
        );

        final response = await requestHandler.handleLLMRequest(request);

        expect(response.status, equals(404)); // Not Found
        expect(response.error, isNotNull);
        expect(response.error!.type.toString(), contains('providerNotFound'));
      });

      test('should handle rate limiting', () async {
        final requests = List.generate(15, (index) => TunnelRequestMessage(
          id: 'rate_limit_$index',
          method: 'POST',
          path: '/api/chat',
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': 'llama2:latest',
            'messages': [
              {'role': 'user', 'content': 'Request $index'}
            ],
          }),
        ));

        // Process requests concurrently to trigger rate limiting
        final futures = requests.map((req) => requestHandler.handleLLMRequest(req));
        final responses = await Future.wait(futures, eagerError: false);

        // Some requests should be rate limited (429 status)
        final rateLimitedResponses = responses.where((r) => r.status == 429);
        expect(rateLimitedResponses, isNotEmpty);
      });
    });

    group('Performance and Load', () {
      test('should handle concurrent requests efficiently', () async {
        const concurrentRequests = 10;
        final stopwatch = Stopwatch()..start();

        // Create concurrent chat requests
        final requests = List.generate(concurrentRequests, (index) => 
          TunnelRequestMessage(
            id: 'concurrent_$index',
            method: 'POST',
            path: '/api/chat',
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'llama2:latest',
              'messages': [
                {'role': 'user', 'content': 'Concurrent request $index'}
              ],
            }),
          ),
        );

        // Mock responses for all requests
        for (int i = 0; i < concurrentRequests; i++) {
          mockProviderManager.setChatResponse(
            'ollama_11434',
            'Response to concurrent request $i',
          );
        }

        // Execute all requests concurrently
        final futures = requests.map((req) => requestHandler.handleLLMRequest(req));
        final responses = await Future.wait(futures);

        stopwatch.stop();

        // Verify all requests completed successfully
        expect(responses, hasLength(concurrentRequests));
        expect(responses.every((r) => r.status == 200), isTrue);

        // Performance check - should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      });
    });
  });
}

// Mock classes would be implemented here
// (Simplified for brevity - full implementation would include all mock methods)

class MockAuthService extends AuthService {
  bool _isAuthenticated = false;
  String? _accessToken;

  void setAuthenticated(bool authenticated) {
    _isAuthenticated = authenticated;
  }

  void setAccessToken(String token) {
    _accessToken = token;
  }

  @override
  String? getAccessToken() => _accessToken;

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(_isAuthenticated);
}

class MockLLMProviderManager extends LLMProviderManager {
  final List<dynamic> _providers = [];
  final Map<String, String> _chatResponses = {};
  final Map<String, Exception> _chatErrors = {};
  final Map<String, Duration> _chatTimeouts = {};

  MockLLMProviderManager() : super(
    discoveryService: ProviderDiscoveryService(),
    langchainService: LangChainIntegrationService(discoveryService: ProviderDiscoveryService()),
  );

  void setAvailableProviders(List<dynamic> providers) {
    _providers.clear();
    _providers.addAll(providers);
  }

  void setChatResponse(String providerId, String response) {
    _chatResponses[providerId] = response;
  }

  void setChatError(String providerId, Exception error) {
    _chatErrors[providerId] = error;
  }

  void setChatTimeout(String providerId, Duration timeout) {
    _chatTimeouts[providerId] = timeout;
  }

  void setStreamingResponse(String providerId, List<String> chunks) {
    // Mock implementation for streaming responses
  }

  void setStreamingFailure(String providerId, List<String> chunks, Exception error) {
    // Mock implementation for streaming failures
  }

  void setModelList(String providerId, List<String> models) {
    // Mock implementation for model list
  }

  void setModelInfo(String providerId, String modelName, Map<String, dynamic> info) {
    // Mock implementation for model info
  }

  // Additional mock methods would be implemented here
}

class MockLLMErrorHandler extends LLMErrorHandler {
  MockLLMErrorHandler() : super();

  void setFailoverProvider(String providerId) {
    // Mock implementation - no storage needed for tests
  }

  // Additional mock methods would be implemented here
}

dynamic createMockOllamaProvider() {
  return {
    'id': 'ollama_11434',
    'name': 'Ollama',
    'type': 'ollama',
    'baseUrl': 'http://localhost:11434',
    'port': 11434,
  };
}

dynamic createMockLMStudioProvider() {
  return {
    'id': 'lmstudio_1234',
    'name': 'LM Studio',
    'type': 'lmStudio',
    'baseUrl': 'http://localhost:1234',
    'port': 1234,
  };
}

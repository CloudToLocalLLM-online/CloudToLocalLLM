# LLM Testing Guide for CloudToLocalLLM

This guide provides comprehensive documentation for testing patterns, utilities, and best practices for the LLM integration components in CloudToLocalLLM.

## Testing Architecture

### Test Categories

1. **Unit Tests** (`test/services/`)
   - Provider Discovery Service tests
   - LangChain Integration Service tests
   - Tunnel LLM Request Handler tests
   - Individual component isolation testing

2. **Integration Tests** (`test/integration/`)
   - End-to-end tunnel communication tests
   - Provider failover scenarios
   - Cross-service interaction testing

3. **End-to-End Tests** (`test/e2e/`)
   - Complete user workflow testing
   - Real provider integration testing
   - Performance and load testing

## Testing Patterns

### Mock Provider Pattern

Use consistent mock providers across tests:

```dart
// Standard mock Ollama provider
ProviderInfo createMockOllamaProvider() {
  return ProviderInfo(
    id: 'ollama_11434',
    name: 'Ollama',
    type: ProviderType.ollama,
    baseUrl: 'http://localhost:11434',
    port: 11434,
    capabilities: {
      'chat': true,
      'completion': true,
      'streaming': true,
    },
    status: ProviderStatus.available,
    lastSeen: DateTime.now(),
    availableModels: ['llama2:latest', 'codellama:latest'],
    version: '0.1.17',
  );
}
```

### HTTP Client Mocking Pattern

Use the MockHttpClient pattern for consistent HTTP mocking:

```dart
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final Map<String, Exception> _exceptions = {};

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  void setException(String url, Exception exception) {
    _exceptions[url] = exception;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    
    if (_exceptions.containsKey(url)) {
      throw _exceptions[url]!;
    }
    
    if (_responses.containsKey(url)) {
      final response = _responses[url]!;
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    
    throw const SocketException('Connection refused');
  }
}
```

### Error Scenario Testing Pattern

Test error scenarios systematically:

```dart
group('Error Scenarios', () {
  test('should handle connection failure', () async {
    mockHttpClient.setException(
      'http://localhost:11434/api/version',
      const SocketException('Connection refused'),
    );

    final result = await service.detectProvider();
    expect(result, isNull);
  });

  test('should handle malformed response', () async {
    mockHttpClient.setResponse(
      'http://localhost:11434/api/version',
      http.Response('Invalid JSON', 200),
    );

    final result = await service.detectProvider();
    expect(result, isNull);
  });

  test('should handle timeout', () async {
    // Configure timeout scenario
    mockHttpClient.setResponse(
      'http://localhost:11434/api/version',
      http.Response('{"version": "0.1.17"}', 200),
    );

    // Test with very short timeout
    final result = await service.detectProvider(timeout: Duration(milliseconds: 1));
    expect(result, isNull);
  });
});
```

### Failover Testing Pattern

Test provider failover scenarios:

```dart
test('should failover to secondary provider', () async {
  // Primary provider fails
  mockProviderManager.setProviderError(
    'primary_provider',
    Exception('Primary provider failed'),
  );

  // Secondary provider succeeds
  mockProviderManager.setProviderResponse(
    'secondary_provider',
    'Success response from backup',
  );

  final result = await service.processWithFailover(
    ['primary_provider', 'secondary_provider'],
    request,
  );

  expect(result.providerId, equals('secondary_provider'));
  expect(result.body, contains('Success response from backup'));
});
```

## Test Naming Conventions

### Test File Naming
- Unit tests: `{service_name}_test.dart`
- Integration tests: `{feature_name}_integration_test.dart`
- End-to-end tests: `{workflow_name}_e2e_test.dart`

### Test Group Naming
- Feature groups: `group('Feature Name', () { ... })`
- Scenario groups: `group('Error Scenarios', () { ... })`
- Method groups: `group('methodName()', () { ... })`

### Test Case Naming
Use descriptive names that explain the scenario:
- `'should detect healthy Ollama instance'`
- `'should handle connection failure gracefully'`
- `'should failover to secondary provider when primary fails'`
- `'should timeout after specified duration'`

## Mock Data Standards

### Standard Provider IDs
- Ollama: `'ollama_11434'`
- LM Studio: `'lmstudio_1234'`
- OpenAI Compatible: `'openai_8080'`

### Standard Model Names
- Ollama: `['llama2:latest', 'codellama:latest', 'mistral:latest']`
- LM Studio: `['Meta-Llama-3-8B-Instruct', 'CodeLlama-7B-Instruct']`
- OpenAI Compatible: `['gpt-3.5-turbo', 'gpt-4']`

### Standard Response Times
- Fast response: `100ms`
- Normal response: `500ms`
- Slow response: `2000ms`
- Timeout threshold: `5000ms`

## Testing Utilities

### Test Helper Functions

```dart
// Create standard test request
TunnelRequestMessage createChatRequest({
  String? id,
  String? providerId,
  String? model,
  String? message,
  bool streaming = false,
}) {
  return TunnelRequestMessage(
    id: id ?? 'test_request_${DateTime.now().millisecondsSinceEpoch}',
    method: 'POST',
    path: '/api/chat',
    headers: {
      'Content-Type': 'application/json',
      if (providerId != null) 'X-Provider-Preference': providerId,
    },
    body: jsonEncode({
      'model': model ?? 'llama2:latest',
      'messages': [
        {'role': 'user', 'content': message ?? 'Test message'}
      ],
      'stream': streaming,
    }),
  );
}

// Verify response structure
void verifySuccessResponse(TunnelLLMResponse response, {
  required String requestId,
  String? providerId,
}) {
  expect(response.requestId, equals(requestId));
  expect(response.status, equals(200));
  expect(response.error, isNull);
  if (providerId != null) {
    expect(response.providerId, equals(providerId));
  }
}

// Verify error response
void verifyErrorResponse(TunnelLLMResponse response, {
  required String requestId,
  required int expectedStatus,
  required String errorType,
}) {
  expect(response.requestId, equals(requestId));
  expect(response.status, equals(expectedStatus));
  expect(response.error, isNotNull);
  expect(response.error!.type.toString(), contains(errorType));
}
```

## Performance Testing Guidelines

### Load Testing
- Test with 10-50 concurrent requests
- Measure response times under load
- Verify no memory leaks during extended testing

### Timeout Testing
- Test various timeout scenarios (1s, 5s, 30s)
- Verify proper cleanup on timeout
- Test timeout handling in streaming scenarios

### Resource Management Testing
- Verify proper disposal of resources
- Test connection pool management
- Monitor memory usage during tests

## Continuous Integration

### Test Execution Order
1. Unit tests (fastest)
2. Integration tests
3. End-to-end tests (slowest)

### Test Categories for CI
- **Smoke Tests**: Basic functionality verification
- **Regression Tests**: Prevent breaking changes
- **Performance Tests**: Ensure acceptable performance
- **Security Tests**: Validate security measures

### Test Environment Setup
```yaml
# Example CI configuration
test:
  stage: test
  script:
    - flutter test test/unit/
    - flutter test test/services/
    - flutter test test/integration/
    - flutter test test/e2e/ --timeout=300s
  coverage: '/lines......: \d+\.\d+%/'
```

## Debugging Test Failures

### Common Issues
1. **Async timing issues**: Use `await` properly, consider `pumpAndSettle()`
2. **Mock setup**: Verify mocks are configured before test execution
3. **Resource cleanup**: Ensure proper disposal in `tearDown()`
4. **State isolation**: Reset state between tests

### Debugging Tools
- Use `debugPrint()` for test debugging
- Enable verbose logging: `flutter test --verbose`
- Use `flutter test --coverage` for coverage analysis
- Profile tests: `flutter test --profile`

## Best Practices

1. **Test Independence**: Each test should be independent and not rely on other tests
2. **Clear Assertions**: Use descriptive assertion messages
3. **Mock Isolation**: Use mocks to isolate units under test
4. **Error Testing**: Test both success and failure scenarios
5. **Performance Awareness**: Keep tests fast and efficient
6. **Documentation**: Document complex test scenarios
7. **Maintenance**: Regularly update tests as code evolves

## Test Coverage Goals

- **Unit Tests**: >90% line coverage
- **Integration Tests**: >80% feature coverage
- **End-to-End Tests**: >70% user workflow coverage

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/provider_discovery_service_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests only
flutter test test/integration/

# Run with specific timeout
flutter test --timeout=60s
```

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/tunnel_config.dart' as setup_config;
import 'package:cloudtolocalllm/models/tunnel_validation_result.dart';

void main() {
  group('TunnelConfigurationService', () {
    // Note: Full service tests would require mocking AuthService and SimpleTunnelClient
    // For now, we'll focus on testing the models and basic functionality

    // Service tests would go here with proper mocking
  });

  group('SetupTunnelConfig', () {
    test('should create valid default configuration', () {
      final config = setup_config.SetupTunnelConfig.defaultConfig(
        userId: 'test-user',
        authToken: 'test-token',
      );

      expect(config.isValid, true);
      expect(config.userId, 'test-user');
      expect(config.authToken, 'test-token');
      expect(config.enableCloudProxy, true);
    });

    test('should create development configuration', () {
      final config = setup_config.SetupTunnelConfig.development(
        userId: 'test-user',
        authToken: 'test-token',
      );

      expect(config.isValid, true);
      expect(config.cloudProxyUrl, contains('localhost'));
      expect(config.connectionTimeout, 10);
    });

    test('should convert WebSocket URL correctly', () {
      final config = setup_config.SetupTunnelConfig(
        userId: 'test-user',
        cloudProxyUrl: 'https://api.example.com/ws',
        localOllamaUrl: 'http://localhost:11434',
        authToken: 'test-token',
      );

      expect(config.webSocketUrl, 'wss://api.example.com/ws');
    });

    test('should include authentication in connection headers', () {
      final config = setup_config.SetupTunnelConfig.defaultConfig(
        userId: 'test-user',
        authToken: 'test-token',
      );

      final headers = config.connectionHeaders;
      expect(headers['Authorization'], 'Bearer test-token');
      expect(headers['User-Agent'], contains('CloudToLocalLLM'));
    });
  });

  group('TunnelValidationResult', () {
    test('should create successful result', () {
      final result = TunnelValidationResult.success(
        'Connection successful',
        latency: 150,
      );

      expect(result.isSuccess, true);
      expect(result.message, 'Connection successful');
      expect(result.latency, 150);
    });

    test('should create failed result', () {
      final result = TunnelValidationResult.failure('Connection failed');

      expect(result.isSuccess, false);
      expect(result.message, 'Connection failed');
      expect(result.latency, isNull);
    });

    test('should calculate success rate correctly', () {
      final tests = [
        ValidationTest.success('Test 1', 'Passed'),
        ValidationTest.failure('Test 2', 'Failed'),
        ValidationTest.success('Test 3', 'Passed'),
      ];

      final result = TunnelValidationResult.success(
        'Partial success',
        tests: tests,
      );

      expect(result.successRate, closeTo(0.67, 0.01));
      expect(result.successfulTestCount, 2);
      expect(result.failedTestCount, 1);
    });
  });
}

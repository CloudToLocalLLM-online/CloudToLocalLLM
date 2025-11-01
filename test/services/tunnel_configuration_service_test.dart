import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/tunnel_config.dart';
import 'package:cloudtolocalllm/models/tunnel_validation_result.dart';

void main() {
  group('TunnelConfigurationService', () {
    // Note: Full service tests would require mocking AuthService and SimpleTunnelClient
    // For now, we'll focus on testing the models and basic functionality
  });

  group('TunnelConfig', () {
    test('should create a valid configuration', () {
      const config = TunnelConfig(
        userId: 'test-user',
        authToken: 'test-token',
        cloudProxyUrl: 'wss://example.com',
        localBackendUrl: 'http://localhost:11434',
      );

      expect(config.userId, 'test-user');
      expect(config.authToken, 'test-token');
      expect(config.cloudProxyUrl, 'wss://example.com');
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

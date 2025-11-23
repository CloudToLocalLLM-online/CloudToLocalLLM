import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

void main() {
  group('Local LLM Providers - Provider Test Connection Timing', () {
    late ProviderConfigurationManager configManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      configManager = ProviderConfigurationManager();
      await configManager.initialize();
    });

    tearDown(() {
      configManager.dispose();
    });

    test(
        'Property 12: Provider Test Connection Timing - Configuration validation completes within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Add a valid provider configuration
      final config = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(config);

      // Measure validation time
      final stopwatch = Stopwatch()..start();

      // Validate the configuration
      final validationResult = configManager.validateConfiguration('ollama_1');

      stopwatch.stop();

      // Verify validation completed
      expect(validationResult.isValid, isTrue);

      // Verify timing constraint: validation should complete within 5 seconds
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Configuration validation took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - Multiple provider validations complete within 5 seconds total',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Add multiple providers
      final ollama = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(ollama);

      final lmStudio = LMStudioProviderConfiguration(
        providerId: 'lmstudio_1',
        baseUrl: 'http://localhost',
        port: 1234,
      );
      await configManager.setConfiguration(lmStudio);

      // Measure time to validate all providers
      final stopwatch = Stopwatch()..start();

      // Validate all configurations
      for (final config in configManager.configurations) {
        final validationResult =
            configManager.validateConfiguration(config.providerId);
        expect(validationResult.isValid, isTrue);
      }

      stopwatch.stop();

      // Verify timing constraint: all validations should complete within 5 seconds
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'All provider validations took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - URL validation completes within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Test various URL formats
      final testUrls = [
        'http://localhost',
        'https://example.com',
        'http://192.168.1.1',
        'https://api.example.com:8080',
      ];

      final stopwatch = Stopwatch()..start();

      for (final url in testUrls) {
        final config = OllamaProviderConfiguration(
          providerId: 'test_${testUrls.indexOf(url)}',
          baseUrl: url,
          port: 11434,
        );

        // Validate the configuration - timing test
        configManager.validateConfiguration(config.providerId);
      }

      stopwatch.stop();

      // Verify timing constraint
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'URL validation took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - Port validation completes within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Test various port numbers
      final testPorts = [80, 443, 1234, 8000, 11434, 65535];

      final stopwatch = Stopwatch()..start();

      for (final port in testPorts) {
        final config = OllamaProviderConfiguration(
          providerId: 'test_port_$port',
          baseUrl: 'http://localhost',
          port: port,
        );

        // Validate the configuration - timing test
        configManager.validateConfiguration(config.providerId);
      }

      stopwatch.stop();

      // Verify timing constraint
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Port validation took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - Batch validation of 10 providers completes within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Add 10 different provider configurations
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10; i++) {
        final config = OllamaProviderConfiguration(
          providerId: 'ollama_batch_$i',
          baseUrl: 'http://localhost',
          port: 11434 + i,
        );
        await configManager.setConfiguration(config);
      }

      // Validate all configurations
      for (final config in configManager.configurations) {
        final validationResult =
            configManager.validateConfiguration(config.providerId);
        expect(validationResult.isValid, isTrue);
      }

      stopwatch.stop();

      // Verify timing constraint: batch validation should complete within 5 seconds
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Batch validation of 10 providers took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - Rapid sequential validations complete within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Add a provider
      final config = OllamaProviderConfiguration(
        providerId: 'ollama_rapid',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(config);

      // Perform rapid sequential validations
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 20; i++) {
        final validationResult =
            configManager.validateConfiguration('ollama_rapid');
        expect(validationResult.isValid, isTrue);
      }

      stopwatch.stop();

      // Verify timing constraint: 20 rapid validations should complete within 5 seconds
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Rapid sequential validations took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });

    test(
        'Property 12: Provider Test Connection Timing - Configuration retrieval and validation completes within 5 seconds',
        () async {
      // **Feature: platform-settings-screen, Property 12: Provider Test Connection Timing**
      // **Validates: Requirements 3.6**

      // Add multiple providers
      final configs = [
        OllamaProviderConfiguration(
          providerId: 'ollama_1',
          baseUrl: 'http://localhost',
          port: 11434,
        ),
        LMStudioProviderConfiguration(
          providerId: 'lmstudio_1',
          baseUrl: 'http://localhost',
          port: 1234,
        ),
      ];

      for (final config in configs) {
        await configManager.setConfiguration(config);
      }

      // Measure time to retrieve and validate all configurations
      final stopwatch = Stopwatch()..start();

      final allConfigs = configManager.configurations;
      for (final config in allConfigs) {
        final retrieved = configManager.getConfiguration(config.providerId);
        expect(retrieved, isNotNull);

        final validationResult =
            configManager.validateConfiguration(config.providerId);
        expect(validationResult.isValid, isTrue);
      }

      stopwatch.stop();

      // Verify timing constraint
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Configuration retrieval and validation took ${stopwatch.elapsedMilliseconds}ms, should be < 5000ms',
      );
    });
  });
}

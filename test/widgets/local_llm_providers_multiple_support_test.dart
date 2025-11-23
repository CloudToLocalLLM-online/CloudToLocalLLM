import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

void main() {
  group('Local LLM Providers - Multiple Provider Support', () {
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
        'Property 11: Multiple Provider Support - System supports adding multiple LangChain-compatible providers',
        () async {
      // **Feature: platform-settings-screen, Property 11: Multiple Provider Support**
      // **Validates: Requirements 3.3**

      // Add Ollama provider
      final ollamaConfig = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(ollamaConfig);

      // Add LM Studio provider
      final lmStudioConfig = LMStudioProviderConfiguration(
        providerId: 'lmstudio_1',
        baseUrl: 'http://localhost',
        port: 1234,
      );
      await configManager.setConfiguration(lmStudioConfig);

      // Add OpenAI Compatible provider
      final openaiConfig = OpenAICompatibleProviderConfiguration(
        providerId: 'openai_1',
        baseUrl: 'http://localhost',
        port: 8000,
        apiKey: 'test-key',
      );
      await configManager.setConfiguration(openaiConfig);

      // Verify all providers are stored
      expect(configManager.configurations.length, equals(3));

      // Verify each provider type is present
      final providerTypes =
          configManager.configurations.map((c) => c.providerType).toSet();
      expect(providerTypes, contains('ollama'));
      expect(providerTypes, contains('lmstudio'));
      expect(providerTypes, contains('openai_compatible'));
    });

    test(
        'Property 11: Multiple Provider Support - Each provider maintains independent configuration',
        () async {
      // **Feature: platform-settings-screen, Property 11: Multiple Provider Support**
      // **Validates: Requirements 3.3**

      // Add multiple Ollama providers with different configurations
      final ollama1 = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
        maxConcurrentRequests: 5,
      );
      await configManager.setConfiguration(ollama1);

      final ollama2 = OllamaProviderConfiguration(
        providerId: 'ollama_2',
        baseUrl: 'http://remote-server',
        port: 11434,
        maxConcurrentRequests: 10,
      );
      await configManager.setConfiguration(ollama2);

      // Verify both providers exist with different configurations
      final config1 = configManager.getConfiguration('ollama_1');
      final config2 = configManager.getConfiguration('ollama_2');

      expect(config1, isNotNull);
      expect(config2, isNotNull);

      final ollamaConfig1 = config1 as OllamaProviderConfiguration;
      final ollamaConfig2 = config2 as OllamaProviderConfiguration;

      expect(ollamaConfig1.baseUrl, equals('http://localhost'));
      expect(ollamaConfig2.baseUrl, equals('http://remote-server'));
      expect(ollamaConfig1.maxConcurrentRequests, equals(5));
      expect(ollamaConfig2.maxConcurrentRequests, equals(10));
    });

    test(
        'Property 11: Multiple Provider Support - Can retrieve all providers of specific type',
        () async {
      // **Feature: platform-settings-screen, Property 11: Multiple Provider Support**
      // **Validates: Requirements 3.3**

      // Add multiple providers of different types
      final ollama1 = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(ollama1);

      final ollama2 = OllamaProviderConfiguration(
        providerId: 'ollama_2',
        baseUrl: 'http://remote',
        port: 11434,
      );
      await configManager.setConfiguration(ollama2);

      final lmStudio = LMStudioProviderConfiguration(
        providerId: 'lmstudio_1',
        baseUrl: 'http://localhost',
        port: 1234,
      );
      await configManager.setConfiguration(lmStudio);

      // Retrieve all Ollama providers
      final ollamaProviders = configManager.getConfigurationsByType('ollama');

      expect(ollamaProviders.length, equals(2));
      expect(
        ollamaProviders.every((p) => p.providerType == 'ollama'),
        isTrue,
      );

      // Retrieve all LM Studio providers
      final lmStudioProviders =
          configManager.getConfigurationsByType('lmstudio');

      expect(lmStudioProviders.length, equals(1));
      expect(lmStudioProviders.first.providerType, equals('lmstudio'));
    });

    test(
        'Property 11: Multiple Provider Support - Adding provider does not affect existing providers',
        () async {
      // **Feature: platform-settings-screen, Property 11: Multiple Provider Support**
      // **Validates: Requirements 3.3**

      // Add first provider
      final ollama = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(ollama);

      // Store original configuration
      final originalConfig = configManager.getConfiguration('ollama_1');

      // Add second provider
      final lmStudio = LMStudioProviderConfiguration(
        providerId: 'lmstudio_1',
        baseUrl: 'http://localhost',
        port: 1234,
      );
      await configManager.setConfiguration(lmStudio);

      // Verify first provider is unchanged
      final updatedConfig = configManager.getConfiguration('ollama_1');

      expect(updatedConfig, isNotNull);
      expect(updatedConfig!.providerId, equals(originalConfig!.providerId));
      expect(updatedConfig.baseUrl, equals(originalConfig.baseUrl));
      expect(updatedConfig.providerType, equals(originalConfig.providerType));
    });

    test(
        'Property 11: Multiple Provider Support - Can remove one provider without affecting others',
        () async {
      // **Feature: platform-settings-screen, Property 11: Multiple Provider Support**
      // **Validates: Requirements 3.3**

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

      // Verify both exist
      expect(configManager.configurations.length, equals(2));

      // Remove one provider
      await configManager.removeConfiguration('ollama_1');

      // Verify only LM Studio remains
      expect(configManager.configurations.length, equals(1));
      expect(
          configManager.configurations.first.providerId, equals('lmstudio_1'));
      expect(configManager.getConfiguration('ollama_1'), isNull);
    });
  });
}

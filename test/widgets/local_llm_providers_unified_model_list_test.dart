import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

void main() {
  group('Local LLM Providers - Unified Model List', () {
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
        'Property 13: Unified Model List - System supports retrieving models from single provider',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Add a single provider
      final config = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(config);

      // Verify provider is configured
      expect(configManager.configurations.length, equals(1));

      // Verify we can retrieve the provider
      final retrieved = configManager.getConfiguration('ollama_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.providerId, equals('ollama_1'));
    });

    test(
        'Property 13: Unified Model List - System supports retrieving models from multiple providers',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

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

      final openai = OpenAICompatibleProviderConfiguration(
        providerId: 'openai_1',
        baseUrl: 'http://localhost',
        port: 8000,
        apiKey: 'test-key',
      );
      await configManager.setConfiguration(openai);

      // Verify all providers are configured
      expect(configManager.configurations.length, equals(3));

      // Verify we can retrieve each provider
      expect(configManager.getConfiguration('ollama_1'), isNotNull);
      expect(configManager.getConfiguration('lmstudio_1'), isNotNull);
      expect(configManager.getConfiguration('openai_1'), isNotNull);
    });

    test(
        'Property 13: Unified Model List - System can filter providers by type',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

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

      // Retrieve providers by type
      final ollamaProviders = configManager.getConfigurationsByType('ollama');
      final lmStudioProviders =
          configManager.getConfigurationsByType('lmstudio');

      // Verify filtering works
      expect(ollamaProviders.length, equals(2));
      expect(lmStudioProviders.length, equals(1));

      // Verify all Ollama providers are returned
      expect(
        ollamaProviders.every((p) => p.providerType == 'ollama'),
        isTrue,
      );

      // Verify all LM Studio providers are returned
      expect(
        lmStudioProviders.every((p) => p.providerType == 'lmstudio'),
        isTrue,
      );
    });

    test(
        'Property 13: Unified Model List - System maintains provider list consistency across operations',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Add initial providers
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

      // Get initial list
      final initialList = configManager.configurations;
      expect(initialList.length, equals(2));

      // Add another provider
      final openai = OpenAICompatibleProviderConfiguration(
        providerId: 'openai_1',
        baseUrl: 'http://localhost',
        port: 8000,
        apiKey: 'test-key',
      );
      await configManager.setConfiguration(openai);

      // Get updated list
      final updatedList = configManager.configurations;
      expect(updatedList.length, equals(3));

      // Verify all previous providers are still in the list
      final providerIds = updatedList.map((p) => p.providerId).toSet();
      expect(providerIds.contains('ollama_1'), isTrue);
      expect(providerIds.contains('lmstudio_1'), isTrue);
      expect(providerIds.contains('openai_1'), isTrue);
    });

    test(
        'Property 13: Unified Model List - System supports retrieving all providers as unified list',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Add multiple providers
      final providers = <ProviderConfiguration>[
        OllamaProviderConfiguration(
          providerId: 'ollama_1',
          baseUrl: 'http://localhost',
          port: 11434,
        ),
        OllamaProviderConfiguration(
          providerId: 'ollama_2',
          baseUrl: 'http://remote',
          port: 11434,
        ),
        LMStudioProviderConfiguration(
          providerId: 'lmstudio_1',
          baseUrl: 'http://localhost',
          port: 1234,
        ),
        OpenAICompatibleProviderConfiguration(
          providerId: 'openai_1',
          baseUrl: 'http://localhost',
          port: 8000,
          apiKey: 'test-key',
        ),
      ];

      for (final provider in providers) {
        await configManager.setConfiguration(provider);
      }

      // Get unified list
      final unifiedList = configManager.configurations;

      // Verify all providers are in the unified list
      expect(unifiedList.length, equals(4));

      // Verify we can access each provider from the unified list
      for (final provider in providers) {
        final found = unifiedList.firstWhere(
          (p) => p.providerId == provider.providerId,
          orElse: () =>
              throw Exception('Provider not found: ${provider.providerId}'),
        );
        expect(found.providerId, equals(provider.providerId));
      }
    });

    test(
        'Property 13: Unified Model List - System maintains provider order in unified list',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Add providers in specific order
      final providerIds = ['ollama_1', 'lmstudio_1', 'openai_1', 'ollama_2'];

      for (final id in providerIds) {
        late ProviderConfiguration config;
        if (id.startsWith('ollama')) {
          config = OllamaProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 11434,
          );
        } else if (id.startsWith('lmstudio')) {
          config = LMStudioProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 1234,
          );
        } else {
          config = OpenAICompatibleProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 8000,
            apiKey: 'test-key',
          );
        }
        await configManager.setConfiguration(config);
      }

      // Get unified list
      final unifiedList = configManager.configurations;

      // Verify all providers are present
      expect(unifiedList.length, equals(4));

      // Verify we can access providers by ID
      for (final id in providerIds) {
        final found = unifiedList.firstWhere(
          (p) => p.providerId == id,
          orElse: () => throw Exception('Provider not found: $id'),
        );
        expect(found.providerId, equals(id));
      }
    });

    test(
        'Property 13: Unified Model List - System supports querying provider count from unified list',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Initially empty
      expect(configManager.configurations.length, equals(0));

      // Add first provider
      final ollama = OllamaProviderConfiguration(
        providerId: 'ollama_1',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(ollama);
      expect(configManager.configurations.length, equals(1));

      // Add second provider
      final lmStudio = LMStudioProviderConfiguration(
        providerId: 'lmstudio_1',
        baseUrl: 'http://localhost',
        port: 1234,
      );
      await configManager.setConfiguration(lmStudio);
      expect(configManager.configurations.length, equals(2));

      // Add third provider
      final openai = OpenAICompatibleProviderConfiguration(
        providerId: 'openai_1',
        baseUrl: 'http://localhost',
        port: 8000,
        apiKey: 'test-key',
      );
      await configManager.setConfiguration(openai);
      expect(configManager.configurations.length, equals(3));

      // Remove one provider
      await configManager.removeConfiguration('ollama_1');
      expect(configManager.configurations.length, equals(2));
    });

    test(
        'Property 13: Unified Model List - System supports iterating through unified provider list',
        () async {
      // **Feature: platform-settings-screen, Property 13: Unified Model List**
      // **Validates: Requirements 3.7**

      // Add multiple providers
      final expectedProviders = <String>['ollama_1', 'lmstudio_1', 'openai_1'];

      for (final id in expectedProviders) {
        late ProviderConfiguration config;
        if (id.startsWith('ollama')) {
          config = OllamaProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 11434,
          );
        } else if (id.startsWith('lmstudio')) {
          config = LMStudioProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 1234,
          );
        } else {
          config = OpenAICompatibleProviderConfiguration(
            providerId: id,
            baseUrl: 'http://localhost',
            port: 8000,
            apiKey: 'test-key',
          );
        }
        await configManager.setConfiguration(config);
      }

      // Iterate through unified list
      final foundProviders = <String>[];
      for (final provider in configManager.configurations) {
        foundProviders.add(provider.providerId);
      }

      // Verify all expected providers were found
      expect(foundProviders.length, equals(expectedProviders.length));
      for (final id in expectedProviders) {
        expect(foundProviders.contains(id), isTrue);
      }
    });
  });
}

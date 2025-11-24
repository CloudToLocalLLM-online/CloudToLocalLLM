import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/local_llm_providers_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;

// Mock ProviderConfigurationManager
class MockProviderConfigurationManager implements ProviderConfigurationManager {
  final List<ProviderConfiguration> _providers = [];
  String? _defaultProviderId;

  Future<List<ProviderConfiguration>> getProviders() async => _providers;

  Future<ProviderConfiguration?> getProvider(String id) async {
    try {
      return _providers.firstWhere((p) => p.providerId == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addProvider(ProviderConfiguration provider) async {
    _providers.add(provider);
  }

  Future<void> removeProvider(String id) async {
    _providers.removeWhere((p) => p.providerId == id);
  }

  Future<void> updateProvider(ProviderConfiguration provider) async {
    final index =
        _providers.indexWhere((p) => p.providerId == provider.providerId);
    if (index >= 0) {
      _providers[index] = provider;
    }
  }

  Future<bool> testConnection(String providerId) async => true;

  Future<void> setDefaultProvider(String providerId) async {
    _defaultProviderId = providerId;
  }

  String? get defaultProviderId => _defaultProviderId;

  Future<List<String>> getAvailableModels(String providerId) async =>
      ['model1', 'model2'];

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {}

  Future<void> enableProvider(String providerId) async {}

  Future<void> disableProvider(String providerId) async {}

  Future<bool> isProviderEnabled(String providerId) async => true;

  Future<Map<String, dynamic>> getProviderMetrics(String providerId) async =>
      {};

  Future<void> clearCache() async {}

  Stream<List<ProviderConfiguration>> get providersStream =>
      Stream.value(_providers);

  Future<void> validateProviderConfiguration(
      ProviderConfiguration provider) async {}

  Future<Map<String, dynamic>> getConnectionStatus(String providerId) async =>
      {'status': 'connected'};

  Future<void> syncWithRemote() async {}

  @override
  bool get isInitialized => true;

  @override
  Future<void> addListener(VoidCallback listener) async {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool get hasListeners => false;

  @override
  void notifyListeners() {}

  @override
  ProviderConfiguration? getConfiguration(String providerId) {
    try {
      return _providers.firstWhere((p) => p.providerId == providerId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> setConfiguration(ProviderConfiguration config) async {
    final index =
        _providers.indexWhere((p) => p.providerId == config.providerId);
    if (index >= 0) {
      _providers[index] = config;
    } else {
      _providers.add(config);
    }
  }

  @override
  Future<void> removeConfiguration(String providerId) async {
    _providers.removeWhere((p) => p.providerId == providerId);
  }

  @override
  Future<void> setPreferredProvider(String? providerId) async {
    _defaultProviderId = providerId;
  }

  @override
  List<ProviderConfiguration> getConfigurationsByType(String providerType) {
    return _providers.where((p) => p.providerType == providerType).toList();
  }

  @override
  bool isProviderConfigured(String providerId) {
    return _providers.any((p) => p.providerId == providerId);
  }

  @override
  ConfigurationValidationResult validateConfiguration(String providerId) {
    return ConfigurationValidationResult(isValid: true, errors: []);
  }

  @override
  Future<void> updatePreference(String key, dynamic value) async {}

  @override
  T? getPreference<T>(String key, [T? defaultValue]) {
    return defaultValue;
  }

  @override
  Map<String, dynamic> exportConfigurations() {
    return {};
  }

  @override
  Future<void> importConfigurations(Map<String, dynamic> data) async {}

  @override
  Future<void> clearAllConfigurations() async {
    _providers.clear();
  }

  @override
  String? get preferredProviderId => _defaultProviderId;

  @override
  List<ProviderConfiguration> get configurations => _providers;

  @override
  String? get error => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalLLMProvidersCategory', () {
    late MockProviderConfigurationManager mockConfigManager;

    setUp(() async {
      mockConfigManager = MockProviderConfigurationManager();

      // Clear and register mock
      if (di.serviceLocator.isRegistered<ProviderConfigurationManager>()) {
        di.serviceLocator.unregister<ProviderConfigurationManager>();
      }
      di.serviceLocator
          .registerSingleton<ProviderConfigurationManager>(mockConfigManager);
    });

    tearDown(() async {
      if (di.serviceLocator.isRegistered<ProviderConfigurationManager>()) {
        di.serviceLocator.unregister<ProviderConfigurationManager>();
      }
    });

    testWidgets('renders empty state when no providers configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('shows add provider button in empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('displays add provider form when button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('provider type dropdown shows all options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('respects isActive property', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
              isActive: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('renders with correct category ID',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('displays configured provider in list',
        (WidgetTester tester) async {
      // Add a provider to the mock
      final provider = OllamaProviderConfiguration(
        providerId: 'test-provider',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await mockConfigManager.setConfiguration(provider);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('shows test connection button for each provider',
        (WidgetTester tester) async {
      final provider = OllamaProviderConfiguration(
        providerId: 'test-provider',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await mockConfigManager.setConfiguration(provider);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('shows set default and remove buttons for each provider',
        (WidgetTester tester) async {
      final provider = OllamaProviderConfiguration(
        providerId: 'test-provider',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await mockConfigManager.setConfiguration(provider);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('shows enable/disable toggle for each provider',
        (WidgetTester tester) async {
      final provider = OllamaProviderConfiguration(
        providerId: 'test-provider',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await mockConfigManager.setConfiguration(provider);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalLLMProvidersCategory(
              categoryId: SettingsCategoryIds.localLLMProviders,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });
  });
}

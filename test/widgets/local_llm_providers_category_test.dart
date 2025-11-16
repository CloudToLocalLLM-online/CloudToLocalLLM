import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/widgets/settings/local_llm_providers_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

void main() {
  group('LocalLLMProvidersCategory', () {
    late ProviderConfigurationManager configManager;

    setUp(() async {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});

      // Initialize configuration manager
      configManager = ProviderConfigurationManager();
      await configManager.initialize();
    });

    tearDown(() {
      configManager.dispose();
    });

    testWidgets('renders empty state when no providers configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for empty state message
      expect(find.text('No Providers Configured'), findsOneWidget);
      expect(
          find.text('Add a local LLM provider to get started'), findsOneWidget);
    });

    testWidgets('shows add provider button in empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for add provider button
      expect(find.text('Add Provider'), findsOneWidget);
    });

    testWidgets('displays add provider form when button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap add provider button
      await tester.tap(find.text('Add Provider'));
      await tester.pumpAndSettle();

      // Check for form elements
      expect(find.text('Add New Provider'), findsOneWidget);
      expect(find.text('Provider Type'), findsOneWidget);
      expect(find.text('Provider Name'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
    });

    testWidgets('provider type dropdown shows all options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap add provider button
      await tester.tap(find.text('Add Provider'));
      await tester.pumpAndSettle();

      // Tap provider type dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();

      // Check for provider options
      expect(find.text('Ollama'), findsOneWidget);
      expect(find.text('LM Studio'), findsOneWidget);
      expect(find.text('OpenAI Compatible'), findsOneWidget);
    });

    testWidgets('respects isActive property', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
                isActive: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should still render
      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('renders with correct category ID',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the widget renders
      expect(find.byType(LocalLLMProvidersCategory), findsOneWidget);
    });

    testWidgets('displays configured provider in list',
        (WidgetTester tester) async {
      // Add a test provider
      final testConfig = OllamaProviderConfiguration(
        providerId: 'test_ollama',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(testConfig);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for configured providers section
      expect(find.text('Configured Providers'), findsOneWidget);
      expect(find.text('OLLAMA'), findsOneWidget);
      expect(find.text('http://localhost:11434'), findsOneWidget);
    });

    testWidgets('shows test connection button for each provider',
        (WidgetTester tester) async {
      // Add a test provider
      final testConfig = OllamaProviderConfiguration(
        providerId: 'test_ollama',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(testConfig);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for test connection button
      expect(find.text('Test Connection'), findsOneWidget);
    });

    testWidgets('shows set default and remove buttons for each provider',
        (WidgetTester tester) async {
      // Add a test provider
      final testConfig = OllamaProviderConfiguration(
        providerId: 'test_ollama',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(testConfig);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for action buttons
      expect(find.text('Set Default'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('shows enable/disable toggle for each provider',
        (WidgetTester tester) async {
      // Add a test provider
      final testConfig = OllamaProviderConfiguration(
        providerId: 'test_ollama',
        baseUrl: 'http://localhost',
        port: 11434,
      );
      await configManager.setConfiguration(testConfig);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProviderConfigurationManager>.value(
              value: configManager,
              child: LocalLLMProvidersCategory(
                categoryId: SettingsCategoryIds.localLLMProviders,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for switch widget
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}

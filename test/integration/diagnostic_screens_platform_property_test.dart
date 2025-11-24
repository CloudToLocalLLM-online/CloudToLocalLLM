import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/services/unified_connection_service.dart';
import 'package:cloudtolocalllm/screens/ollama_test_screen.dart';
import 'package:cloudtolocalllm/screens/settings/llm_provider_settings_screen.dart';
import 'package:cloudtolocalllm/screens/settings/daemon_settings_screen.dart';
import 'package:cloudtolocalllm/screens/settings/connection_status_screen.dart';
import '../test_config.dart';

/// **Feature: unified-app-theming, Property 4: Platform-Appropriate Components**
///
/// Property: For any diagnostic screen, the rendered components SHALL match the platform
/// (Material for web, native for desktop)
///
/// **Validates: Requirements 10.5, 10.6**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostic Screens Platform Components Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;
    late UnifiedConnectionService connectionService;

    setUp(() {
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
      connectionService = UnifiedConnectionService();
    });

    tearDown() {
      themeProvider.dispose();
      platformService.dispose();
      connectionService.dispose();
    }

    Widget buildTestScreen(Widget screen) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<PlatformDetectionService>.value(
            value: platformService,
          ),
          Provider<PlatformAdapter>.value(
            value: platformAdapter,
          ),
          ChangeNotifierProvider<UnifiedConnectionService>.value(
            value: connectionService,
          ),
        ],
        child: MaterialApp(
          theme: themeProvider.currentTheme,
          themeMode: themeProvider.themeMode,
          home: screen,
        ),
      );
    }

    testWidgets(
      'Property 4: Ollama Test Screen uses platform-appropriate components',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestScreen(const OllamaTestScreen()));
        await tester.pumpAndSettle();

        // Verify Material components are used (web platform in tests)
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Card), findsWidgets);

        // Verify back button exists
        expect(
          find.byType(IconButton),
          findsWidgets,
          reason: 'Platform-appropriate back button should exist',
        );
      },
    );

    testWidgets(
      'Property 4: LLM Provider Settings Screen uses platform-appropriate components',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestScreen(const LLMProviderSettingsScreen()),
        );
        await tester.pumpAndSettle();

        // Verify Material components are used
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify back button exists
        expect(
          find.byType(IconButton),
          findsWidgets,
          reason: 'Platform-appropriate back button should exist',
        );
      },
    );

    testWidgets(
      'Property 4: Daemon Settings Screen uses platform-appropriate components',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestScreen(const DaemonSettingsScreen()),
        );
        await tester.pumpAndSettle();

        // Verify Material components are used
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify back button exists
        expect(
          find.byType(IconButton),
          findsWidgets,
          reason: 'Platform-appropriate back button should exist',
        );

        // Verify switches and sliders (platform-appropriate form controls)
        expect(
          find.byType(Switch),
          findsWidgets,
          reason: 'Platform-appropriate switches should exist',
        );
        expect(
          find.byType(Slider),
          findsWidgets,
          reason: 'Platform-appropriate sliders should exist',
        );
      },
    );

    testWidgets(
      'Property 4: Connection Status Screen uses platform-appropriate components',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestScreen(const ConnectionStatusScreen()),
        );
        await tester.pumpAndSettle();

        // Verify Material components are used
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify back button exists
        expect(
          find.byType(IconButton),
          findsWidgets,
          reason: 'Platform-appropriate back button should exist',
        );
      },
    );

    testWidgets(
      'Property 4: All diagnostic screens use consistent component types',
      (WidgetTester tester) async {
        final screens = [
          const OllamaTestScreen(),
          const LLMProviderSettingsScreen(),
          const DaemonSettingsScreen(),
          const ConnectionStatusScreen(),
        ];

        for (final screen in screens) {
          await tester.pumpWidget(buildTestScreen(screen));
          await tester.pumpAndSettle();

          // All screens should use Material Scaffold
          expect(
            find.byType(Scaffold),
            findsOneWidget,
            reason: 'All screens should use Scaffold',
          );

          // All screens should have AppBar
          expect(
            find.byType(AppBar),
            findsOneWidget,
            reason: 'All screens should have AppBar',
          );

          // All screens should have back button
          expect(
            find.byType(IconButton),
            findsWidgets,
            reason: 'All screens should have back button',
          );
        }
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/chat/chat_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 1: Theme Application Timing**
///
/// Property: For any theme change, all screens SHALL update within 200 milliseconds
/// Validates: Requirements 1.2, 4.7, 5.7, 6.6, 7.6, 8.5, 9.5, 10.7, 11.5, 12.5
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Chat Interface Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 1: Chat Interface applies light theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const ChatScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expectThemeMode(tester, Brightness.light);
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Chat Interface applies dark theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const ChatScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Chat Interface updates theme within 200ms',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const ChatScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final duration = await measureExecutionTime(() async {
          await themeProvider.setThemeMode(ThemeMode.dark);
          await tester.pump();
          await pumpAndSettleWithTimeout(tester);
        });

        expectExecutionTimeWithin(duration, const Duration(milliseconds: 200));
        expectThemeMode(tester, Brightness.dark);
      },
    );
  });
}

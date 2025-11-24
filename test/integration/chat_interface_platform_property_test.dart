import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/chat/chat_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 4: Platform-Appropriate Components**
///
/// Property: For any screen, the rendered components SHALL match the platform
/// Validates: Requirements 2.4, 2.5, 2.6, 2.7
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Chat Interface Platform Components Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;
    late MockAuthService authService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
      authService = createMockAuthService(authenticated: true);
    });

    testWidgets(
      'Property 4: Chat Interface uses Material components on web platform',
      (WidgetTester tester) async {
        expect(platformService.isWeb, isTrue);

        await tester.pumpWidget(
          createAuthenticatedTestApp(
            const ChatScreen(),
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 4: Chat Interface components remain consistent across themes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const ChatScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            platformAdapter: platformAdapter,
            authService: authService,
            themeMode: ThemeMode.light,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        await themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pump();
        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);
      },
    );
  });
}

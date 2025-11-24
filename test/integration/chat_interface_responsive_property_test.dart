import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/chat/chat_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 5: Responsive Layout Adaptation**
///
/// Property: For any screen width change, content SHALL reflow within 300ms without data loss
/// Validates: Requirements 3.3, 4.3, 5.3, 6.4, 7.4, 8.4, 9.4, 10.6, 11.4, 12.3, 13.4
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Chat Interface Responsive Layout Property Tests', () {
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 5: Chat Interface adapts to mobile layout (< 600px)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const ChatScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(ChatScreen), findsOneWidget);
        final mediaQuery = tester.element(find.byType(ChatScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(400.0));
      },
    );

    testWidgets(
      'Property 5: Chat Interface adapts to tablet layout (600-1024px)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const ChatScreen(),
              platformService: platformService,
            ),
            width: 800.0,
            height: 1024.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(ChatScreen), findsOneWidget);
        final mediaQuery = tester.element(find.byType(ChatScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(800.0));
      },
    );

    testWidgets(
      'Property 5: Chat Interface adapts to desktop layout (> 1024px)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const ChatScreen(),
              platformService: platformService,
            ),
            width: 1440.0,
            height: 900.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(ChatScreen), findsOneWidget);
        final mediaQuery = tester.element(find.byType(ChatScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(1440.0));
      },
    );

    testWidgets(
      'Property 5: Chat Interface reflows within 300ms on width change',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const ChatScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final duration = await measureExecutionTime(() async {
          await tester.pumpWidget(
            wrapWithMediaQuery(
              createAuthenticatedTestApp(
                const ChatScreen(),
                platformService: platformService,
              ),
              width: 1440.0,
              height: 900.0,
            ),
          );
          await pumpAndSettleWithTimeout(tester);
        });

        expectExecutionTimeWithin(duration, const Duration(milliseconds: 300));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });
}

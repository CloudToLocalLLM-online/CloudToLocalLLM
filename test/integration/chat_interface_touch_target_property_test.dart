import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/chat/chat_screen.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 6: Mobile Touch Target Size**
///
/// Property: For any mobile screen, all touch targets SHALL be at least 44x44 pixels
/// Validates: Requirements 4.4, 13.6
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Chat Interface Touch Target Property Tests', () {
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 6: Chat Interface touch targets meet minimum size on mobile',
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

        // Find interactive widgets
        final interactiveTypes = [
          IconButton,
          ElevatedButton,
          TextButton,
          FloatingActionButton,
        ];

        // Verify touch targets meet minimum size
        for (final widgetType in interactiveTypes) {
          final finder = find.byType(widgetType);
          if (finder.evaluate().isNotEmpty) {
            for (final element in finder.evaluate()) {
              final renderBox = element.renderObject as RenderBox?;
              if (renderBox != null) {
                final size = renderBox.size;
                expect(
                  meetsTouchTargetSize(size),
                  isTrue,
                  reason:
                      '$widgetType has size ${size.width}x${size.height}, expected >= 44x44',
                );
              }
            }
          }
        }
      },
    );

    testWidgets(
      'Property 6: Chat Interface maintains touch target size across orientations',
      (WidgetTester tester) async {
        // Portrait
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

        final portraitButtons = find.byType(IconButton);
        if (portraitButtons.evaluate().isNotEmpty) {
          final portraitSize = getWidgetSize(tester, portraitButtons.first);
          if (portraitSize != null) {
            expect(meetsTouchTargetSize(portraitSize), isTrue);
          }
        }

        // Landscape
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const ChatScreen(),
              platformService: platformService,
            ),
            width: 800.0,
            height: 400.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final landscapeButtons = find.byType(IconButton);
        if (landscapeButtons.evaluate().isNotEmpty) {
          final landscapeSize = getWidgetSize(tester, landscapeButtons.first);
          if (landscapeSize != null) {
            expect(meetsTouchTargetSize(landscapeSize), isTrue);
          }
        }
      },
    );
  });
}

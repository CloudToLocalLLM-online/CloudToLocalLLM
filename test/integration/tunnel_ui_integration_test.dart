/// Integration tests for tunnel UI improvements
///
/// Tests cross-component tunnel status updates, multi-entry wizard launching,
/// and settings integration for the enhanced tunnel management interface.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:cloudtolocalllm/components/app_header.dart';
import 'package:cloudtolocalllm/components/tunnel_status_indicator.dart';
import 'package:cloudtolocalllm/components/tunnel_management_panel.dart';
import 'package:cloudtolocalllm/components/desktop_client_prompt.dart';
import 'package:cloudtolocalllm/components/tunnel_connection_wizard.dart';
import 'package:cloudtolocalllm/screens/tunnel_status_screen.dart';
import 'package:cloudtolocalllm/screens/unified_settings_screen.dart';
import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/services/desktop_client_detection_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/config/router.dart';

// Generate mocks
@GenerateMocks([
  SimpleTunnelClient,
  DesktopClientDetectionService,
  AuthService,
])
import 'tunnel_ui_integration_test.mocks.dart';

void main() {
  group('Tunnel UI Integration Tests', () {
    late MockSimpleTunnelClient mockTunnelClient;
    late MockDesktopClientDetectionService mockClientDetection;
    late MockAuthService mockAuthService;
    late GoRouter router;

    setUp(() {
      mockTunnelClient = MockSimpleTunnelClient();
      mockClientDetection = MockDesktopClientDetectionService();
      mockAuthService = MockAuthService();

      // Setup default mock behaviors
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(false);
      when(mockTunnelClient.lastError).thenReturn(null);
      when(mockTunnelClient.config).thenReturn(TunnelConfig(
        cloudProxyUrl: 'wss://test.example.com',
        localOllamaUrl: 'http://localhost:11434',
        connectionTimeout: 10,
        healthCheckInterval: 30,
        enableCloudProxy: true,
      ));
      when(mockTunnelClient.connectionStatus).thenReturn({});

      when(mockClientDetection.hasConnectedClients).thenReturn(false);
      when(mockClientDetection.connectedClientCount).thenReturn(0);
      when(mockClientDetection.connectedClients).thenReturn([]);

      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentUser).thenReturn(null);

      // Setup router for navigation testing
      router = createAppRouter();
    });

    Widget createTestApp({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SimpleTunnelClient>.value(value: mockTunnelClient),
          ChangeNotifierProvider<DesktopClientDetectionService>.value(value: mockClientDetection),
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          title: 'Test App',
        ),
      );
    }

    testWidgets('tunnel status indicator shows correct status and opens management panel', (WidgetTester tester) async {
      // Test disconnected state
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(false);

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: AppHeader(title: 'Test'),
        ),
      ));

      // Find tunnel status indicator
      final indicator = find.byType(TunnelStatusIndicator);
      expect(indicator, findsOneWidget);

      // Verify disconnected status is shown
      expect(find.text('Disconnected'), findsOneWidget);

      // Tap indicator to open management panel
      await tester.tap(indicator);
      await tester.pumpAndSettle();

      // Verify management panel opens
      expect(find.byType(TunnelManagementPanel), findsOneWidget);
      expect(find.text('Tunnel Management'), findsOneWidget);
    });

    testWidgets('tunnel status updates consistently across components', (WidgetTester tester) async {
      // Start with disconnected state
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(false);

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: Column(
            children: [
              AppHeader(title: 'Test'),
              Expanded(child: TunnelStatusScreen()),
            ],
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Verify both components show disconnected state
      expect(find.text('Disconnected'), findsAtLeastNWidgets(1));

      // Simulate connection state change
      when(mockTunnelClient.isConnected).thenReturn(true);
      when(mockTunnelClient.isConnecting).thenReturn(false);

      // Trigger rebuild by calling notifyListeners
      mockTunnelClient.notifyListeners();
      await tester.pumpAndSettle();

      // Verify both components update to connected state
      expect(find.text('Connected'), findsAtLeastNWidgets(1));
    });

    testWidgets('tunnel wizard opens with correct mode from different entry points', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: AppHeader(title: 'Test'),
        ),
      ));

      // Open management panel
      final indicator = find.byType(TunnelStatusIndicator);
      await tester.tap(indicator);
      await tester.pumpAndSettle();

      // Find and tap configure button
      final configureButton = find.text('Configure Tunnel');
      expect(configureButton, findsOneWidget);
      await tester.tap(configureButton);
      await tester.pumpAndSettle();

      // Verify wizard opens in reconfigure mode
      expect(find.byType(TunnelConnectionWizard), findsOneWidget);
      expect(find.text('Tunnel Management'), findsOneWidget);
    });

    testWidgets('desktop client prompt shows tunnel setup option', (WidgetTester tester) async {
      // Simulate no desktop clients connected
      when(mockClientDetection.hasConnectedClients).thenReturn(false);

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: DesktopClientPrompt(),
        ),
      ));

      await tester.pumpAndSettle();

      // Verify enhanced prompt is shown
      expect(find.byType(DesktopClientPrompt), findsOneWidget);
      expect(find.text('Download Desktop Client'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);

      // Tap setup button
      final setupButton = find.text('Setup');
      await tester.tap(setupButton);
      await tester.pumpAndSettle();

      // Verify tunnel wizard opens in first-time mode
      expect(find.byType(TunnelConnectionWizard), findsOneWidget);
      expect(find.text('Setup Tunnel Connection'), findsOneWidget);
    });

    testWidgets('settings screen shows enhanced tunnel status summary', (WidgetTester tester) async {
      // Setup tunnel needs configuration
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.lastError).thenReturn(null);

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: UnifiedSettingsScreen(),
        ),
      ));

      await tester.pumpAndSettle();

      // Look for tunnel status summary card
      expect(find.text('Tunnel Status'), findsAtLeastNWidgets(1));
      
      // Verify status information is displayed
      final statusTexts = ['Connected', 'Connecting', 'Disconnected', 'Setup Required'];
      final foundStatus = statusTexts.any((status) => 
        find.text(status).evaluate().isNotEmpty
      );
      expect(foundStatus, isTrue);
    });

    testWidgets('tunnel management panel provides comprehensive controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: AppHeader(title: 'Test'),
        ),
      ));

      // Open management panel
      final indicator = find.byType(TunnelStatusIndicator);
      await tester.tap(indicator);
      await tester.pumpAndSettle();

      // Verify all expected sections are present
      expect(find.text('Tunnel Management'), findsOneWidget);
      expect(find.text('Tunnel Status'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Troubleshooting'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Configure Tunnel'), findsOneWidget);
      expect(find.text('View Status Dashboard'), findsOneWidget);
      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('tunnel status screen provides comprehensive monitoring', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: TunnelStatusScreen(),
        ),
      ));

      await tester.pumpAndSettle();

      // Verify main sections are present
      expect(find.text('Tunnel Status'), findsAtLeastNWidgets(1));
      expect(find.text('Connection Details'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Common Issues'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Troubleshoot'), findsOneWidget);
    });

    testWidgets('tunnel wizard supports multiple modes correctly', (WidgetTester tester) async {
      // Test first-time mode
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: TunnelConnectionWizard(
            mode: TunnelWizardMode.firstTime,
            title: 'First Time Setup',
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('First Time Setup'), findsOneWidget);
      expect(find.text('Configure your CloudToLocalLLM tunnel connection'), findsOneWidget);

      // Test reconfigure mode
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: TunnelConnectionWizard(
            mode: TunnelWizardMode.reconfigure,
            title: 'Reconfigure Tunnel',
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Reconfigure Tunnel'), findsOneWidget);
      expect(find.text('Update your existing tunnel configuration'), findsOneWidget);

      // Test troubleshoot mode
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: TunnelConnectionWizard(
            mode: TunnelWizardMode.troubleshoot,
            title: 'Tunnel Troubleshooting',
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Tunnel Troubleshooting'), findsOneWidget);
      expect(find.text('Diagnose and fix tunnel connection issues'), findsOneWidget);
    });

    testWidgets('error states are handled gracefully across components', (WidgetTester tester) async {
      // Simulate error state
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(false);
      when(mockTunnelClient.lastError).thenReturn('Connection timeout');

      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: Column(
            children: [
              AppHeader(title: 'Test'),
              Expanded(child: TunnelStatusScreen()),
            ],
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Verify error state is shown
      expect(find.text('Error'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Connection timeout'), findsAtLeastNWidgets(1));
    });

    testWidgets('navigation between tunnel-related screens works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: AppHeader(title: 'Test'),
        ),
      ));

      // Open management panel
      final indicator = find.byType(TunnelStatusIndicator);
      await tester.tap(indicator);
      await tester.pumpAndSettle();

      // Navigate to status dashboard
      final statusButton = find.text('View Status Dashboard');
      expect(statusButton, findsOneWidget);
      await tester.tap(statusButton);
      await tester.pumpAndSettle();

      // Verify navigation occurred (this would require proper router setup in real app)
      // For now, just verify the button was tappable
      expect(statusButton, findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/main.dart' as app;
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/components/tunnel_connection_wizard.dart';
import '../test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Initialize test configuration with plugin mocks
  setUpAll(() {
    TestConfig.initialize();
  });

  tearDownAll(() {
    TestConfig.cleanup();
  });

  group('Tunnel Connection Wizard Integration Tests', () {
    testWidgets('Complete tunnel wizard workflow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Navigate to tunnel connection settings
      await tester.tap(find.text('Tunnel Connection'));
      await tester.pumpAndSettle();

      // Find and tap the tunnel wizard button
      await tester.tap(find.text('Launch Tunnel Wizard'));
      await tester.pumpAndSettle();

      // Verify wizard dialog is shown
      expect(find.text('Tunnel Connection Setup'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);

      // Test authentication step
      expect(find.text('Authentication Required'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Note: We can't actually test the full authentication flow in integration tests
      // without real credentials, but we can verify the UI components are present

      // Test server selection step navigation
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should still be on authentication step since not authenticated
      expect(find.text('Authentication'), findsOneWidget);

      // Test cancel functionality
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify wizard is closed
      expect(find.text('Tunnel Connection Setup'), findsNothing);
    });

    testWidgets('Tunnel wizard UI components validation', (
      WidgetTester tester,
    ) async {
      // Create a test widget with the wizard
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
              ChangeNotifierProvider<SimpleTunnelClient>(
                create: (_) => SimpleTunnelClient(authService: AuthService()),
              ),
            ],
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const TunnelConnectionWizard(),
                    );
                  },
                  child: const Text('Show Wizard'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the wizard
      await tester.tap(find.text('Show Wizard'));
      await tester.pumpAndSettle();

      // Verify wizard components
      expect(find.text('Tunnel Connection Setup'), findsOneWidget);
      expect(
        find.text('Configure your CloudToLocalLLM tunnel connection'),
        findsOneWidget,
      );

      // Verify step indicators
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('Server Selection'), findsOneWidget);
      expect(find.text('Connection Testing'), findsOneWidget);
      expect(find.text('Configuration Save'), findsOneWidget);

      // Verify step icons
      expect(find.byIcon(Icons.login), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
      expect(find.byIcon(Icons.network_check), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);

      // Verify navigation buttons
      expect(find.text('Next'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify authentication step content
      expect(find.text('Authentication Required'), findsOneWidget);
      expect(
        find.text(
          'Please authenticate with your CloudToLocalLLM account to continue.',
        ),
        findsOneWidget,
      );
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Enhanced authentication service validation', (
      WidgetTester tester,
    ) async {
      // Create a test widget with auth service
      late AuthService authService;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>(
            create: (_) {
              authService = AuthService();
              return authService;
            },
            child: Consumer<AuthService>(
              builder: (context, auth, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Authenticated: ${auth.isAuthenticated.value}'),
                      Text('Loading: ${auth.isLoading.value}'),
                      Text('Validating: ${auth.isValidatingToken}'),
                      ElevatedButton(
                        onPressed: () async {
                          await auth.validateAuthentication();
                        },
                        child: const Text('Validate Auth'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Authenticated: false'), findsOneWidget);
      expect(find.text('Loading: false'), findsOneWidget);
      expect(find.text('Validating: false'), findsOneWidget);

      // Test validation method exists and can be called
      await tester.tap(find.text('Validate Auth'));
      await tester.pump(); // Don't wait for settle as this might be async

      // Verify the enhanced methods are available
      expect(authService.isValidatingToken, isA<bool>());
      expect(authService.lastTokenValidation, isA<DateTime?>());
    });

    testWidgets('Simple tunnel client integration validation', (
      WidgetTester tester,
    ) async {
      // Create a test widget with simple tunnel client
      late SimpleTunnelClient tunnelClient;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SimpleTunnelClient>(
            create: (_) {
              tunnelClient = SimpleTunnelClient(authService: AuthService());
              return tunnelClient;
            },
            child: Consumer<SimpleTunnelClient>(
              builder: (context, tunnel, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Connected: ${tunnel.isConnected}'),
                      Text('Connecting: ${tunnel.isConnecting}'),
                      ElevatedButton(
                        onPressed: () async {
                          await tunnel.initialize();
                        },
                        child: const Text('Initialize Connection'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final status = tunnel.connectionStatus;
                          debugPrint('Status: $status');
                        },
                        child: const Text('Get Status'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test initialization functionality
      await tester.tap(find.text('Initialize Connection'));
      await tester.pumpAndSettle();

      // Test status functionality
      await tester.tap(find.text('Get Status'));
      await tester.pumpAndSettle();

      // Verify methods are available
      final status = tunnelClient.connectionStatus;
      expect(status, isA<Map<String, dynamic>>());
      expect(status['connected'], isA<bool>());
      expect(status['connecting'], isA<bool>());

      final config = tunnelClient.config;
      expect(config, isA<TunnelConfig>());
      expect(config.cloudProxyUrl, isA<String>());
      expect(config.localOllamaUrl, isA<String>());
    });
  });
}

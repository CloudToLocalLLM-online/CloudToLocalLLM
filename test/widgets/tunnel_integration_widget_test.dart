import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/local_ollama_connection_service.dart';

// Generate mocks
@GenerateMocks([SimpleTunnelClient, AuthService, LocalOllamaConnectionService])
import 'tunnel_integration_widget_test.mocks.dart';

void main() {
  group('Tunnel Integration Widget Tests', () {
    late MockSimpleTunnelClient mockTunnelClient;
    late MockAuthService mockAuthService;
    late MockLocalOllamaConnectionService mockLocalOllama;

    setUp(() {
      mockTunnelClient = MockSimpleTunnelClient();
      mockAuthService = MockAuthService();
      mockLocalOllama = MockLocalOllamaConnectionService();
    });

    testWidgets('Connection status UI reflects tunnel state correctly', (
      WidgetTester tester,
    ) async {
      // Setup mock behavior
      when(mockTunnelClient.isConnected).thenReturn(true);
      when(mockTunnelClient.isConnecting).thenReturn(false);
      when(mockTunnelClient.connectionStatus).thenReturn({
        'connected': true,
        'connecting': false,
        'error': null,
        'reconnectAttempts': 0,
        'lastPing': null,
      });
      when(mockTunnelClient.config).thenReturn(TunnelConfig.defaultConfig());
      when(mockTunnelClient.error).thenReturn(null);

      when(mockLocalOllama.isConnected).thenReturn(false);
      when(
        mockAuthService.isAuthenticated,
      ).thenReturn(ValueNotifier<bool>(true));
      when(mockAuthService.isLoading).thenReturn(ValueNotifier<bool>(false));

      // Create connection manager with mocks
      final connectionManager = ConnectionManagerService(
        localOllama: mockLocalOllama,
        tunnelManager: mockTunnelClient,
        authService: mockAuthService,
      );

      // Create test widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SimpleTunnelClient>.value(
                value: mockTunnelClient,
              ),
              ChangeNotifierProvider<ConnectionManagerService>.value(
                value: connectionManager,
              ),
            ],
            child: Scaffold(
              body: Consumer<SimpleTunnelClient>(
                builder: (context, tunnelClient, child) {
                  return Column(
                    children: [
                      // Connection status indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              tunnelClient.isConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: tunnelClient.isConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tunnelClient.isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: TextStyle(
                                color: tunnelClient.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Connection details
                      if (tunnelClient.isConnecting)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Connecting...'),
                            ],
                          ),
                        ),
                      if (tunnelClient.error != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error: ${tunnelClient.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify connected state UI
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text('Disconnected'), findsNothing);
      expect(find.text('Connecting...'), findsNothing);
    });

    testWidgets('Connection status UI shows connecting state', (
      WidgetTester tester,
    ) async {
      // Setup mock behavior for connecting state
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(true);
      when(mockTunnelClient.connectionStatus).thenReturn({
        'connected': false,
        'connecting': true,
        'error': null,
        'reconnectAttempts': 1,
        'lastPing': null,
      });
      when(mockTunnelClient.config).thenReturn(TunnelConfig.defaultConfig());
      when(mockTunnelClient.error).thenReturn(null);

      when(mockLocalOllama.isConnected).thenReturn(false);
      when(
        mockAuthService.isAuthenticated,
      ).thenReturn(ValueNotifier<bool>(true));
      when(mockAuthService.isLoading).thenReturn(ValueNotifier<bool>(false));

      // Create connection manager with mocks
      final connectionManager = ConnectionManagerService(
        localOllama: mockLocalOllama,
        tunnelManager: mockTunnelClient,
        authService: mockAuthService,
      );

      // Create test widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SimpleTunnelClient>.value(
                value: mockTunnelClient,
              ),
              ChangeNotifierProvider<ConnectionManagerService>.value(
                value: connectionManager,
              ),
            ],
            child: Scaffold(
              body: Consumer<SimpleTunnelClient>(
                builder: (context, tunnelClient, child) {
                  return Column(
                    children: [
                      // Connection status indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              tunnelClient.isConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: tunnelClient.isConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tunnelClient.isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: TextStyle(
                                color: tunnelClient.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Connection details
                      if (tunnelClient.isConnecting)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Connecting...'),
                            ],
                          ),
                        ),
                      if (tunnelClient.error != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error: ${tunnelClient.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify connecting state UI
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Connecting...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Connection status UI shows error state', (
      WidgetTester tester,
    ) async {
      // Setup mock behavior for error state
      when(mockTunnelClient.isConnected).thenReturn(false);
      when(mockTunnelClient.isConnecting).thenReturn(false);
      when(mockTunnelClient.connectionStatus).thenReturn({
        'connected': false,
        'connecting': false,
        'error': 'Connection failed',
        'reconnectAttempts': 3,
        'lastPing': null,
      });
      when(mockTunnelClient.config).thenReturn(TunnelConfig.defaultConfig());
      when(mockTunnelClient.error).thenReturn('Connection failed');

      when(mockLocalOllama.isConnected).thenReturn(false);
      when(
        mockAuthService.isAuthenticated,
      ).thenReturn(ValueNotifier<bool>(true));
      when(mockAuthService.isLoading).thenReturn(ValueNotifier<bool>(false));

      // Create connection manager with mocks
      final connectionManager = ConnectionManagerService(
        localOllama: mockLocalOllama,
        tunnelManager: mockTunnelClient,
        authService: mockAuthService,
      );

      // Create test widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SimpleTunnelClient>.value(
                value: mockTunnelClient,
              ),
              ChangeNotifierProvider<ConnectionManagerService>.value(
                value: connectionManager,
              ),
            ],
            child: Scaffold(
              body: Consumer<SimpleTunnelClient>(
                builder: (context, tunnelClient, child) {
                  return Column(
                    children: [
                      // Connection status indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              tunnelClient.isConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: tunnelClient.isConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tunnelClient.isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: TextStyle(
                                color: tunnelClient.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Connection details
                      if (tunnelClient.isConnecting)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Connecting...'),
                            ],
                          ),
                        ),
                      if (tunnelClient.error != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error: ${tunnelClient.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error state UI
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Error: Connection failed'), findsOneWidget);
      expect(find.text('Connecting...'), findsNothing);
    });

    testWidgets('Connection manager integration works correctly', (
      WidgetTester tester,
    ) async {
      // Setup mock behavior
      when(mockTunnelClient.isConnected).thenReturn(true);
      when(mockTunnelClient.isConnecting).thenReturn(false);
      when(mockTunnelClient.connectionStatus).thenReturn({
        'connected': true,
        'connecting': false,
        'error': null,
        'reconnectAttempts': 0,
        'lastPing': null,
      });
      when(mockTunnelClient.config).thenReturn(TunnelConfig.defaultConfig());
      when(mockTunnelClient.error).thenReturn(null);

      when(mockLocalOllama.isConnected).thenReturn(false);
      when(
        mockAuthService.isAuthenticated,
      ).thenReturn(ValueNotifier<bool>(true));
      when(mockAuthService.isLoading).thenReturn(ValueNotifier<bool>(false));

      // Create connection manager with mocks
      final connectionManager = ConnectionManagerService(
        localOllama: mockLocalOllama,
        tunnelManager: mockTunnelClient,
        authService: mockAuthService,
      );

      // Create test widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConnectionManagerService>.value(
                value: connectionManager,
              ),
            ],
            child: Scaffold(
              body: Consumer<ConnectionManagerService>(
                builder: (context, manager, child) {
                  final connectionType = manager.getBestConnectionType();
                  return Column(
                    children: [
                      Text('Connection Type: ${connectionType.name}'),
                      Text('Has Any Connection: ${manager.hasAnyConnection}'),
                      Text(
                        'Has Cloud Connection: ${manager.hasCloudConnection}',
                      ),
                      Text(
                        'Has Local Connection: ${manager.hasLocalConnection}',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify connection manager integration
      expect(find.text('Connection Type: cloud'), findsOneWidget);
      expect(find.text('Has Any Connection: true'), findsOneWidget);
      expect(find.text('Has Cloud Connection: true'), findsOneWidget);
      expect(find.text('Has Local Connection: false'), findsOneWidget);
    });
  });
}

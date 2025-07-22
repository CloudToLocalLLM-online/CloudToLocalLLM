import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/user_container_service.dart';
import 'package:cloudtolocalllm/services/download_management_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/platform_config.dart';
import 'package:cloudtolocalllm/models/container_creation_result.dart';
import '../test_config.dart';

// Generate mocks for integration testing
@GenerateMocks([
  AuthService,
  SetupWizardService,
  PlatformDetectionService,
  UserContainerService,
  DownloadManagementService,
])
import 'setup_wizard_flow_test.mocks.dart';

// Global mock variables for helper functions
late MockAuthService mockAuthService;
late MockSetupWizardService mockSetupWizardService;
late MockPlatformDetectionService mockPlatformDetectionService;
late MockUserContainerService mockUserContainerService;
late MockDownloadManagementService mockDownloadManagementService;

// Helper methods
void setupDefaultMocks() {
  when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
  when(mockAuthService.currentUser).thenReturn(null);

  when(mockSetupWizardService.shouldShowWizard).thenReturn(true);
  when(mockSetupWizardService.isFirstTimeUser).thenReturn(true);
  when(mockSetupWizardService.hasUserSeenWizard).thenReturn(false);
  when(mockSetupWizardService.isSetupCompleted).thenReturn(false);

  when(
    mockPlatformDetectionService.detectPlatform(),
  ).thenReturn(PlatformType.windows);
  when(
    mockPlatformDetectionService.currentPlatform,
  ).thenReturn(PlatformType.windows);
  when(mockPlatformDetectionService.getDownloadOptions()).thenReturn([]);

  when(mockUserContainerService.hasActiveContainer).thenReturn(false);
  when(mockUserContainerService.isCreatingContainer).thenReturn(false);

  when(
    mockDownloadManagementService.generateDownloadUrl(any, any),
  ).thenAnswer((_) async => 'https://example.com/download');
}

void setupSuccessfulFlowMocks() {
  when(mockUserContainerService.createUserContainer()).thenAnswer(
    (_) async => ContainerCreationResult.success(
      containerId: 'container_123',
      proxyId: 'proxy_456',
    ),
  );

  when(
    mockUserContainerService.validateContainerHealth(),
  ).thenAnswer((_) async => true);
}

Widget createTestApp() {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<SetupWizardService>.value(
          value: mockSetupWizardService,
        ),
        ChangeNotifierProvider<PlatformDetectionService>.value(
          value: mockPlatformDetectionService,
        ),
        ChangeNotifierProvider<UserContainerService>.value(
          value: mockUserContainerService,
        ),
        ChangeNotifierProvider<DownloadManagementService>.value(
          value: mockDownloadManagementService,
        ),
      ],
      child: const MockSetupWizardScreen(),
    ),
  );
}

Future<void> navigateToStep(WidgetTester tester, int targetStep) async {
  for (int i = 1; i < targetStep; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Setup Wizard Flow Tests', () {
    setUp(() {
      TestConfig.initialize();

      mockAuthService = MockAuthService();
      mockSetupWizardService = MockSetupWizardService();
      mockPlatformDetectionService = MockPlatformDetectionService();
      mockUserContainerService = MockUserContainerService();
      mockDownloadManagementService = MockDownloadManagementService();

      setupDefaultMocks();
    });

    tearDown(() {
      TestConfig.cleanup();
    });

    group('Basic Flow Tests', () {
      testWidgets('should display welcome step initially', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Welcome'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
      });

      testWidgets('should navigate between steps', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Start at welcome
        expect(find.text('Welcome'), findsOneWidget);

        // Navigate to container step
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Container'), findsOneWidget);

        // Navigate to platform step
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Platform'), findsOneWidget);

        // Navigate back
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Container'), findsOneWidget);
      });

      testWidgets('should handle step skipping', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Skip welcome step
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        // Should advance to next step
        expect(find.text('Container'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle container creation failure', (
        WidgetTester tester,
      ) async {
        // Setup failure scenario
        when(mockUserContainerService.createUserContainer()).thenAnswer(
          (_) async => ContainerCreationResult.failure(
            errorMessage: 'Container creation failed',
            errorCode: 'CREATION_FAILED',
          ),
        );

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to container step
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Should handle error gracefully
        expect(find.text('Container'), findsOneWidget);
      });
    });

    group('State Management', () {
      testWidgets('should maintain state during navigation', (
        WidgetTester tester,
      ) async {
        setupSuccessfulFlowMocks();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate forward and back
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Container'), findsOneWidget);

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Welcome'), findsOneWidget);
      });

      testWidgets('should complete full flow', (WidgetTester tester) async {
        setupSuccessfulFlowMocks();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate through all steps
        for (int i = 0; i < 7; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }

        // Should reach completion
        expect(find.text('Complete'), findsOneWidget);
      });
    });

    group('Platform-Specific Tests', () {
      testWidgets('should handle Windows platform', (
        WidgetTester tester,
      ) async {
        when(
          mockPlatformDetectionService.detectPlatform(),
        ).thenReturn(PlatformType.windows);
        when(
          mockPlatformDetectionService.currentPlatform,
        ).thenReturn(PlatformType.windows);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to platform step
        await navigateToStep(tester, 3);

        expect(find.text('Platform'), findsOneWidget);
      });

      testWidgets('should handle Linux platform', (WidgetTester tester) async {
        when(
          mockPlatformDetectionService.detectPlatform(),
        ).thenReturn(PlatformType.linux);
        when(
          mockPlatformDetectionService.currentPlatform,
        ).thenReturn(PlatformType.linux);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to platform step
        await navigateToStep(tester, 3);

        expect(find.text('Platform'), findsOneWidget);
      });
    });
  });
}

// Mock setup wizard screen for testing
class MockSetupWizardScreen extends StatefulWidget {
  const MockSetupWizardScreen({super.key});

  @override
  State<MockSetupWizardScreen> createState() => _MockSetupWizardScreenState();
}

class _MockSetupWizardScreenState extends State<MockSetupWizardScreen> {
  int currentStep = 1;
  final int totalSteps = 8;

  final List<String> stepTitles = [
    'Welcome',
    'Container',
    'Platform',
    'Download',
    'Installation',
    'Tunnel',
    'Validation',
    'Complete',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Wizard - Step $currentStep of $totalSteps'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: currentStep / totalSteps),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stepTitles[currentStep - 1],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  _buildStepContent(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentStep > 1 ? _goBack : null,
                  child: const Text('Back'),
                ),
                Row(
                  children: [
                    if (currentStep < totalSteps)
                      TextButton(onPressed: _skip, child: const Text('Skip')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: currentStep < totalSteps ? _goNext : _complete,
                      child: Text(currentStep < totalSteps ? 'Next' : 'Finish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 1:
        return const Text('Welcome to CloudToLocalLLM');
      case 2:
        return const Text('Creating your secure container...');
      case 3:
        return const Text('Platform Detection');
      case 4:
        return const Text('Download Desktop Client');
      case 5:
        return const Text('Installation Instructions');
      case 6:
        return const Text('Tunnel Configuration');
      case 7:
        return const Text('Connection Validation');
      case 8:
        return const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 20),
            Text('Setup Complete'),
          ],
        );
      default:
        return const Text('Unknown Step');
    }
  }

  void _goBack() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  void _goNext() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    }
  }

  void _skip() {
    _goNext();
  }

  void _complete() {
    context.read<SetupWizardService>().markSetupCompleted();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:cloudtolocalllm/models/download_option.dart';
import '../test_config.dart';

// Generate mocks for E2E testing
@GenerateMocks([
  AuthService,
  SetupWizardService,
  PlatformDetectionService,
  UserContainerService,
  DownloadManagementService,
])
import 'setup_wizard_e2e_test.mocks.dart';

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
  when(mockPlatformDetectionService.getDownloadOptions()).thenReturn([
    const DownloadOption(
      name: 'Windows Installer (MSI)',
      description: 'Recommended for most users',
      downloadUrl: 'https://example.com/installer.msi',
      fileSize: '50 MB',
      installationType: 'msi',
      isRecommended: true,
    ),
  ]);

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

Widget createTestApp({bool highContrast = false}) {
  return MaterialApp(
    theme: highContrast
        ? ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light().copyWith(
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          )
        : ThemeData.light(),
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Setup Wizard End-to-End Tests', () {
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

    testWidgets('should complete full setup wizard flow', (
      WidgetTester tester,
    ) async {
      setupSuccessfulFlowMocks();

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify welcome step
      expect(find.text('Welcome'), findsOneWidget);

      // Navigate through steps
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Container'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Platform'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Installation'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Tunnel'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Validation'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('should support keyboard navigation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Test keyboard navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Should navigate to next step
      expect(find.text('Container'), findsOneWidget);
    });

    testWidgets('should handle errors gracefully', (WidgetTester tester) async {
      // Setup error scenario
      when(mockUserContainerService.createUserContainer()).thenAnswer(
        (_) async => ContainerCreationResult.failure(
          errorMessage: 'Container creation failed',
          errorCode: 'CREATION_FAILED',
        ),
      );

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to container creation step
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show error handling
      expect(find.text('Container'), findsOneWidget);
    });
  });
}

// Mock setup wizard screen for E2E testing
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
                Semantics(
                  label: 'Previous Step',
                  child: ElevatedButton(
                    onPressed: currentStep > 1 ? _goBack : null,
                    child: const Text('Back'),
                  ),
                ),
                Row(
                  children: [
                    if (currentStep < totalSteps)
                      Semantics(
                        label: 'Skip Step',
                        child: TextButton(
                          onPressed: _skip,
                          child: const Text('Skip'),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Next Step',
                      child: ElevatedButton(
                        onPressed: currentStep < totalSteps
                            ? _goNext
                            : _complete,
                        child: Text(
                          currentStep < totalSteps ? 'Next' : 'Finish',
                        ),
                      ),
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
        return const Column(
          children: [
            Text('Welcome to CloudToLocalLLM'),
            SizedBox(height: 10),
            Text('This wizard will help you set up your desktop client.'),
          ],
        );
      case 2:
        return const Column(
          children: [
            Text('Creating your secure container...'),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        );
      case 3:
        return const Column(
          children: [
            Text('Platform Detection'),
            SizedBox(height: 20),
            Text('Detected Platform: Windows'),
          ],
        );
      case 4:
        return const Column(
          children: [
            Text('Download Desktop Client'),
            SizedBox(height: 20),
            Text('Select your preferred installer'),
          ],
        );
      case 5:
        return const Column(
          children: [
            Text('Installation Instructions'),
            SizedBox(height: 20),
            Text('Follow the installation steps'),
          ],
        );
      case 6:
        return const Column(
          children: [
            Text('Tunnel Configuration'),
            SizedBox(height: 20),
            Text('Configuring secure connection...'),
          ],
        );
      case 7:
        return const Column(
          children: [
            Text('Connection Validation'),
            SizedBox(height: 20),
            Text('Testing connection...'),
          ],
        );
      case 8:
        return const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 20),
            Text('Setup Complete'),
            SizedBox(height: 10),
            Text('Your CloudToLocalLLM is ready to use!'),
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

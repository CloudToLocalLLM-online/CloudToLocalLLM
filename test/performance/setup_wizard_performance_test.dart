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

import '../test_config.dart';

// Generate mocks for performance testing
@GenerateMocks([
  AuthService,
  SetupWizardService,
  PlatformDetectionService,
  UserContainerService,
  DownloadManagementService,
])
import 'setup_wizard_performance_test.mocks.dart';

// Global mock variables
late MockAuthService mockAuthService;
late MockSetupWizardService mockSetupWizardService;
late MockPlatformDetectionService mockPlatformDetectionService;
late MockUserContainerService mockUserContainerService;
late MockDownloadManagementService mockDownloadManagementService;

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
      child: const PerformanceTestSetupWizardScreen(),
    ),
  );
}

void main() {
  group('Setup Wizard Performance Tests', () {
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

    testWidgets('should load initial screen quickly', (
      WidgetTester tester,
    ) async {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds / 1000, lessThan(2));
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('should navigate between steps quickly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds / 1000, lessThan(3));
    });
  });
}

class PerformanceTestSetupWizardScreen extends StatefulWidget {
  const PerformanceTestSetupWizardScreen({super.key});

  @override
  State<PerformanceTestSetupWizardScreen> createState() =>
      _PerformanceTestSetupWizardScreenState();
}

class _PerformanceTestSetupWizardScreenState
    extends State<PerformanceTestSetupWizardScreen> {
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
        title: Text('Performance Test - Step $currentStep of $totalSteps'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: currentStep / totalSteps),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Text(
                stepTitles[currentStep - 1],
                style: Theme.of(context).textTheme.headlineMedium,
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
                ElevatedButton(
                  onPressed: currentStep < totalSteps ? _goNext : _complete,
                  child: Text(currentStep < totalSteps ? 'Next' : 'Finish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _complete() {
    context.read<SetupWizardService>().markSetupCompleted();
  }
}

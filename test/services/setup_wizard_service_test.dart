import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/desktop_client_detection_service.dart';
import 'package:cloudtolocalllm/models/setup_error.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([AuthService, DesktopClientDetectionService])
import 'setup_wizard_service_test.mocks.dart';

void main() {
  group('SetupWizardService', () {
    late SetupWizardService setupWizardService;
    late MockAuthService mockAuthService;
    late MockDesktopClientDetectionService mockClientDetectionService;

    setUp(() {
      TestConfig.initialize();

      mockAuthService = MockAuthService();
      mockClientDetectionService = MockDesktopClientDetectionService();

      // Setup default mock behaviors
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(false));
      when(mockAuthService.currentUser).thenReturn(null);
      when(mockClientDetectionService.hasConnectedClients).thenReturn(false);
      when(mockClientDetectionService.connectedClientCount).thenReturn(0);

      setupWizardService = SetupWizardService(
        authService: mockAuthService,
        clientDetectionService: mockClientDetectionService,
      );
    });

    tearDown(() {
      setupWizardService.dispose();
      TestConfig.cleanup();
    });

    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(setupWizardService.isSetupCompleted, false);
        expect(setupWizardService.hasUserSeenWizard, false);
        expect(setupWizardService.shouldShowWizard, false);
        expect(setupWizardService.isFirstTimeUser, false);
        expect(setupWizardService.isInitialized, true);
      });

      test('should initialize error handling services', () {
        expect(setupWizardService.errorRecoveryService, isNotNull);
        expect(setupWizardService.troubleshootingService, isNotNull);
        expect(setupWizardService.analyticsService, isNotNull);
      });
    });

    group('Setup State Management', () {
      test('should mark wizard as seen', () async {
        expect(setupWizardService.hasUserSeenWizard, false);

        await setupWizardService.markWizardSeen();

        expect(setupWizardService.hasUserSeenWizard, true);
      });

      test('should mark setup as completed', () async {
        expect(setupWizardService.isSetupCompleted, false);
        expect(setupWizardService.shouldShowWizard, false);

        await setupWizardService.markSetupCompleted();

        expect(setupWizardService.isSetupCompleted, true);
        expect(setupWizardService.hasUserSeenWizard, true);
        expect(setupWizardService.shouldShowWizard, false);
      });

      test('should reset setup state', () async {
        // First mark as completed
        await setupWizardService.markSetupCompleted();
        expect(setupWizardService.isSetupCompleted, true);

        // Then reset
        await setupWizardService.resetSetupState();

        expect(setupWizardService.isSetupCompleted, false);
        expect(setupWizardService.hasUserSeenWizard, false);
        expect(setupWizardService.shouldShowWizard, false);
        expect(setupWizardService.isFirstTimeUser, false);
      });
    });

    group('Wizard Visibility Logic', () {
      test('should show wizard for first-time authenticated user', () async {
        // Mock authenticated user
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));

        // Simulate first-time user (hasn't seen wizard)
        expect(setupWizardService.hasUserSeenWizard, false);

        // Trigger auth state change
        setupWizardService.showWizard();

        expect(setupWizardService.shouldShowWizard, true);
      });

      test('should not show wizard for returning user', () async {
        // Mark user as having seen wizard
        await setupWizardService.markWizardSeen();

        // Mock authenticated user
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));

        expect(setupWizardService.shouldShowWizard, false);
      });

      test('should allow manual wizard access from settings', () {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));

        expect(setupWizardService.canAccessFromSettings, true);

        setupWizardService.showWizardFromSettings();

        expect(setupWizardService.shouldShowWizard, true);
      });
    });

    group('Setup Progress Tracking', () {
      test('should return correct setup progress information', () {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
        when(mockClientDetectionService.hasConnectedClients).thenReturn(true);
        when(mockClientDetectionService.connectedClientCount).thenReturn(2);

        final progress = setupWizardService.getSetupProgress();

        expect(progress['isSetupCompleted'], false);
        expect(progress['hasUserSeenWizard'], false);
        expect(progress['isAuthenticated'], true);
        expect(progress['hasConnectedClients'], true);
        expect(progress['connectedClientCount'], 2);
      });
    });

    group('Error Handling', () {
      test('should handle setup error with recovery', () async {
        final exception = Exception('Test error');

        final result = await setupWizardService.handleSetupError(
          exception,
          setupStep: 'test_step',
          context: {'test': 'context'},
        );

        expect(result, isNotNull);
        expect(result.shouldRetry, isA<bool>());
      });

      test('should execute setup operation with retry', () async {
        var callCount = 0;

        final result = await setupWizardService.executeSetupOperation<String>(
          'test_operation',
          () async {
            callCount++;
            if (callCount == 1) {
              throw Exception('First attempt fails');
            }
            return 'success';
          },
          maxRetries: 2,
          setupStep: 'test_step',
        );

        expect(result, 'success');
        expect(callCount, 2);
      });

      test('should start troubleshooting session', () {
        final error = SetupError.platformDetectionFailed(
          details: 'Test error',
          setupStep: 'platform_detection',
        );

        final session = setupWizardService.startTroubleshooting(error);

        expect(session, isNotNull);
        expect(session.error, error);
      });

      test('should get contextual help for setup step', () {
        final guides = setupWizardService.getContextualHelp(
          'platform_detection',
          platform: 'windows',
        );

        expect(guides, isA<List>());
      });
    });

    group('Setup Session Management', () {
      test('should complete setup session successfully', () async {
        await setupWizardService.completeSetupSession(
          success: true,
          finalStep: 'validation',
          context: {'test': 'context'},
        );

        expect(setupWizardService.isSetupCompleted, true);
      });

      test('should complete setup session with failure', () async {
        await setupWizardService.completeSetupSession(
          success: false,
          finalStep: 'container_creation',
          context: {'error': 'test_error'},
        );

        expect(setupWizardService.isSetupCompleted, false);
      });

      test('should get setup analytics summary', () {
        final analytics = setupWizardService.getSetupAnalytics();

        expect(analytics, isNotNull);
      });

      test('should reset error recovery state', () {
        setupWizardService.resetErrorRecovery();

        // Should not throw and should reset internal state
        expect(() => setupWizardService.resetErrorRecovery(), returnsNormally);
      });
    });

    group('Listener Management', () {
      test('should handle auth state changes', () async {
        final authNotifier = ValueNotifier<bool>(false);
        when(mockAuthService.isAuthenticated).thenReturn(authNotifier);

        // Create new service to test listener setup
        final service = SetupWizardService(
          authService: mockAuthService,
          clientDetectionService: mockClientDetectionService,
        );

        // Simulate auth state change
        authNotifier.value = true;

        // Allow async operations to complete
        await Future.delayed(Duration.zero);

        service.dispose();
      });

      test('should handle client detection changes', () async {
        // Create new service to test listener setup
        final service = SetupWizardService(
          authService: mockAuthService,
          clientDetectionService: mockClientDetectionService,
        );

        // Simulate client detection change
        when(mockClientDetectionService.hasConnectedClients).thenReturn(true);

        // Allow async operations to complete
        await Future.delayed(Duration.zero);

        service.dispose();
      });
    });

    group('Disposal', () {
      test('should dispose properly without errors', () {
        expect(() => setupWizardService.dispose(), returnsNormally);
      });
    });
  });
}

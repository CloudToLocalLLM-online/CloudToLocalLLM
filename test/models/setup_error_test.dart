import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/setup_error.dart';
import '../test_config.dart';

void main() {
  group('SetupError', () {
    setUp(() {
      TestConfig.initialize();
    });

    tearDown(() {
      TestConfig.cleanup();
    });

    group('Factory Constructors', () {
      test(
        'should create error from exception with platform detection classification',
        () {
          final exception = Exception('platform detection failed');

          final error = SetupError.fromException(
            exception,
            setupStep: 'platform_detection',
            context: {'userAgent': 'test'},
          );

          expect(error.type, SetupErrorType.platformDetection);
          expect(error.code, 'PLATFORM_DETECTION_FAILED');
          expect(
            error.userFriendlyMessage,
            'Unable to detect your operating system',
          );
          expect(error.isRetryable, true);
          expect(error.setupStep, 'platform_detection');
          expect(error.context['userAgent'], 'test');
        },
      );

      test(
        'should create error from exception with container creation classification',
        () {
          final exception = Exception('container creation failed');

          final error = SetupError.fromException(
            exception,
            setupStep: 'container_creation',
          );

          expect(error.type, SetupErrorType.containerCreation);
          expect(error.code, 'CONTAINER_CREATION_FAILED');
          expect(
            error.userFriendlyMessage,
            'Failed to create your secure container',
          );
          expect(error.isRetryable, true);
          expect(error.suggestedRetryDelay, const Duration(seconds: 30));
        },
      );

      test(
        'should create error from exception with download classification',
        () {
          final exception = Exception('download failed');

          final error = SetupError.fromException(
            exception,
            setupStep: 'download',
          );

          expect(error.type, SetupErrorType.downloadFailure);
          expect(error.code, 'DOWNLOAD_FAILED');
          expect(error.userFriendlyMessage, 'Download failed');
          expect(error.isRetryable, true);
          expect(error.suggestedRetryDelay, const Duration(seconds: 10));
        },
      );

      test(
        'should create error from exception with network classification',
        () {
          final exception = Exception('network connection timeout');

          final error = SetupError.fromException(
            exception,
            setupStep: 'network_test',
          );

          expect(error.type, SetupErrorType.networkError);
          expect(error.code, 'NETWORK_ERROR');
          expect(error.userFriendlyMessage, 'Network connection problem');
          expect(error.isRetryable, true);
          expect(error.suggestedRetryDelay, const Duration(seconds: 15));
        },
      );

      test(
        'should create error from exception with authentication classification',
        () {
          final exception = Exception('unauthorized access');

          final error = SetupError.fromException(
            exception,
            setupStep: 'auth_check',
          );

          expect(error.type, SetupErrorType.authentication);
          expect(error.code, 'AUTH_ERROR');
          expect(error.userFriendlyMessage, 'Authentication failed');
          expect(error.isRetryable, false);
        },
      );

      test(
        'should create error from exception with unknown classification',
        () {
          final exception = Exception('some random error');

          final error = SetupError.fromException(
            exception,
            setupStep: 'unknown_step',
          );

          expect(error.type, SetupErrorType.unknown);
          expect(error.code, 'UNKNOWN_ERROR');
          expect(error.userFriendlyMessage, 'An unexpected error occurred');
          expect(error.isRetryable, true);
          expect(error.suggestedRetryDelay, const Duration(seconds: 10));
        },
      );
    });

    group('Specific Error Factory Methods', () {
      test('should create platform detection failed error', () {
        final error = SetupError.platformDetectionFailed(
          details: 'User agent parsing failed',
          setupStep: 'platform_detection',
          context: {'userAgent': 'unknown'},
        );

        expect(error.type, SetupErrorType.platformDetection);
        expect(error.code, 'PLATFORM_DETECTION_FAILED');
        expect(error.technicalDetails, 'User agent parsing failed');
        expect(
          error.userFriendlyMessage,
          'Unable to detect your operating system',
        );
        expect(
          error.actionableGuidance,
          'Please select your platform manually from the options below',
        );
        expect(error.isRetryable, true);
        expect(error.troubleshootingSteps, contains('Try refreshing the page'));
        expect(
          error.troubleshootingSteps,
          contains('Use manual platform selection'),
        );
      });

      test('should create container creation failed error', () {
        final error = SetupError.containerCreationFailed(
          details: 'Docker daemon not available',
          setupStep: 'container_creation',
          context: {'dockerVersion': 'unknown'},
        );

        expect(error.type, SetupErrorType.containerCreation);
        expect(error.code, 'CONTAINER_CREATION_FAILED');
        expect(error.technicalDetails, 'Docker daemon not available');
        expect(
          error.userFriendlyMessage,
          'Failed to create your secure container',
        );
        expect(
          error.actionableGuidance,
          'We\'ll try again automatically, or you can retry manually',
        );
        expect(error.isRetryable, true);
        expect(error.suggestedRetryDelay, const Duration(seconds: 30));
        expect(
          error.troubleshootingSteps,
          contains('Check internet connection'),
        );
      });

      test('should create download failed error', () {
        final error = SetupError.downloadFailed(
          details: 'HTTP 404 Not Found',
          setupStep: 'download',
          platform: 'windows',
          context: {'url': 'https://example.com/download'},
        );

        expect(error.type, SetupErrorType.downloadFailure);
        expect(error.code, 'DOWNLOAD_FAILED');
        expect(error.technicalDetails, 'HTTP 404 Not Found');
        expect(
          error.userFriendlyMessage,
          'Failed to download the desktop client',
        );
        expect(
          error.actionableGuidance,
          'Try downloading again or use an alternative download method',
        );
        expect(error.isRetryable, true);
        expect(
          error.troubleshootingSteps,
          contains('Try the alternative windows package'),
        );
        expect(error.context['platform'], 'windows');
      });

      test('should create tunnel configuration failed error', () {
        final error = SetupError.tunnelConfigurationFailed(
          details: 'Port 8080 already in use',
          setupStep: 'tunnel_setup',
          context: {'port': 8080},
        );

        expect(error.type, SetupErrorType.tunnelConfiguration);
        expect(error.code, 'TUNNEL_CONFIG_FAILED');
        expect(error.technicalDetails, 'Port 8080 already in use');
        expect(
          error.userFriendlyMessage,
          'Failed to configure the connection tunnel',
        );
        expect(
          error.actionableGuidance,
          'Check your network settings and try again',
        );
        expect(error.isRetryable, true);
        expect(error.suggestedRetryDelay, const Duration(seconds: 20));
        expect(error.troubleshootingSteps, contains('Check firewall settings'));
      });

      test('should create connection validation failed error', () {
        final error = SetupError.connectionValidationFailed(
          details: 'Desktop client not responding',
          setupStep: 'validation',
          context: {'timeout': 30},
        );

        expect(error.type, SetupErrorType.connectionValidation);
        expect(error.code, 'CONNECTION_VALIDATION_FAILED');
        expect(error.technicalDetails, 'Desktop client not responding');
        expect(
          error.userFriendlyMessage,
          'Unable to verify the connection is working',
        );
        expect(
          error.actionableGuidance,
          'Check that the desktop client is running and try again',
        );
        expect(error.isRetryable, true);
        expect(error.suggestedRetryDelay, const Duration(seconds: 15));
        expect(
          error.troubleshootingSteps,
          contains('Ensure desktop client is running'),
        );
      });
    });

    group('Error Properties', () {
      test('should provide correct error icon for each type', () {
        expect(SetupError.platformDetectionFailed().getErrorIcon(), '');
        expect(SetupError.containerCreationFailed().getErrorIcon(), '�');
        expect(SetupError.downloadFailed().getErrorIcon(), '⬇');
        expect(SetupError.tunnelConfigurationFailed().getErrorIcon(), '');
        expect(SetupError.connectionValidationFailed().getErrorIcon(), '');

        final authError = SetupError.fromException(Exception('auth error'));
        expect(authError.getErrorIcon(), ''); // Default for unknown
      });

      test('should provide correct error color for each type', () {
        final authError = SetupError.fromException(Exception('unauthorized'));
        expect(authError.getErrorColor(), 'red');

        final networkError = SetupError.fromException(
          Exception('network timeout'),
        );
        expect(networkError.getErrorColor(), 'orange');

        final configError = SetupError.fromException(Exception('config error'));
        expect(configError.getErrorColor(), 'red'); // Default
      });

      test('should identify critical errors correctly', () {
        final authError = SetupError.fromException(Exception('unauthorized'));
        expect(authError.isCritical, true);

        final networkError = SetupError.fromException(
          Exception('network error'),
        );
        expect(networkError.isCritical, false);

        final downloadError = SetupError.downloadFailed();
        expect(downloadError.isCritical, false);
      });
    });

    group('Troubleshooting Guide', () {
      test('should generate detailed troubleshooting guide', () {
        final error = SetupError.platformDetectionFailed(
          details: 'User agent parsing failed',
          setupStep: 'platform_detection',
        );

        final guide = error.getDetailedTroubleshootingGuide();

        expect(guide, contains('## Troubleshooting Guide'));
        expect(guide, contains(' Unable to detect your operating system'));
        expect(guide, contains('**What to try:**'));
        expect(guide, contains('1. Try refreshing the page'));
        expect(guide, contains('**Retry:**'));
        expect(guide, contains('**Technical Details:**'));
        expect(guide, contains('User agent parsing failed'));
      });

      test('should handle troubleshooting guide without technical details', () {
        final error = SetupError.platformDetectionFailed(
          setupStep: 'platform_detection',
        );

        final guide = error.getDetailedTroubleshootingGuide();

        expect(guide, contains('## Troubleshooting Guide'));
        expect(guide, isNot(contains('**Technical Details:**')));
      });

      test('should handle troubleshooting guide for non-retryable errors', () {
        final error = SetupError.fromException(
          Exception('auth error'),
          setupStep: 'authentication',
        );

        final guide = error.getDetailedTroubleshootingGuide();

        expect(guide, contains('## Troubleshooting Guide'));
        expect(guide, isNot(contains('**Retry:**')));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final error = SetupError.platformDetectionFailed(
          details: 'Test details',
          setupStep: 'platform_detection',
          context: {'test': 'value'},
        );

        final json = error.toJson();

        expect(json['type'], 'platformDetection');
        expect(json['code'], 'PLATFORM_DETECTION_FAILED');
        expect(json['message'], 'Platform detection failed');
        expect(json['technicalDetails'], 'Test details');
        expect(
          json['userFriendlyMessage'],
          'Unable to detect your operating system',
        );
        expect(
          json['actionableGuidance'],
          'Please select your platform manually from the options below',
        );
        expect(json['troubleshootingSteps'], isA<List>());
        expect(json['isRetryable'], true);
        expect(json['suggestedRetryDelay'], isA<int>());
        expect(json['setupStep'], 'platform_detection');
        expect(json['context'], {'test': 'value'});
        expect(json['timestamp'], isA<String>());
        expect(json['isCritical'], false);
      });

      test('should deserialize from JSON correctly', () {
        final originalError = SetupError.platformDetectionFailed(
          details: 'Test details',
          setupStep: 'platform_detection',
          context: {'test': 'value'},
        );

        final json = originalError.toJson();
        final deserializedError = SetupError.fromJson(json);

        expect(deserializedError.type, originalError.type);
        expect(deserializedError.code, originalError.code);
        expect(deserializedError.message, originalError.message);
        expect(
          deserializedError.technicalDetails,
          originalError.technicalDetails,
        );
        expect(
          deserializedError.userFriendlyMessage,
          originalError.userFriendlyMessage,
        );
        expect(
          deserializedError.actionableGuidance,
          originalError.actionableGuidance,
        );
        expect(
          deserializedError.troubleshootingSteps,
          originalError.troubleshootingSteps,
        );
        expect(deserializedError.isRetryable, originalError.isRetryable);
        expect(deserializedError.setupStep, originalError.setupStep);
        expect(deserializedError.context, originalError.context);
      });

      test('should handle JSON with missing optional fields', () {
        final json = {
          'type': 'unknown',
          'code': 'TEST_ERROR',
          'message': 'Test message',
          'userFriendlyMessage': 'Test user message',
          'actionableGuidance': 'Test guidance',
          'isRetryable': true,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final error = SetupError.fromJson(json);

        expect(error.type, SetupErrorType.unknown);
        expect(error.code, 'TEST_ERROR');
        expect(error.technicalDetails, null);
        expect(error.troubleshootingSteps, isEmpty);
        expect(error.suggestedRetryDelay, null);
        expect(error.setupStep, null);
        expect(error.context, isEmpty);
      });
    });

    group('Equality and Hash Code', () {
      test('should implement equality correctly', () {
        final timestamp = DateTime.now();

        final error1 = SetupError(
          type: SetupErrorType.platformDetection,
          code: 'TEST_ERROR',
          message: 'Test message',
          userFriendlyMessage: 'Test user message',
          actionableGuidance: 'Test guidance',
          isRetryable: true,
          timestamp: timestamp,
        );

        final error2 = SetupError(
          type: SetupErrorType.platformDetection,
          code: 'TEST_ERROR',
          message: 'Test message',
          userFriendlyMessage: 'Test user message',
          actionableGuidance: 'Test guidance',
          isRetryable: true,
          timestamp: timestamp,
        );

        expect(error1 == error2, true);
        expect(error1.hashCode == error2.hashCode, true);
      });

      test('should handle inequality correctly', () {
        final error1 = SetupError.platformDetectionFailed();
        final error2 = SetupError.containerCreationFailed();

        expect(error1 == error2, false);
        expect(error1.hashCode == error2.hashCode, false);
      });
    });

    group('String Representation', () {
      test('should provide meaningful string representation', () {
        final error = SetupError.platformDetectionFailed(
          setupStep: 'platform_detection',
        );

        final str = error.toString();

        expect(str, contains('SetupError'));
        expect(str, contains('platformDetection'));
        expect(str, contains('PLATFORM_DETECTION_FAILED'));
        expect(str, contains('Unable to detect your operating system'));
        expect(str, contains('platform_detection'));
        expect(str, contains('retryable: true'));
      });
    });
  });

  group('SetupRetryState', () {
    group('Initial State', () {
      test('should create initial retry state correctly', () {
        final state = SetupRetryState.initial();

        expect(state.attemptCount, 0);
        expect(state.lastAttempt, null);
        expect(state.nextAttempt, null);
        expect(state.currentDelay, const Duration(seconds: 1));
        expect(state.isBackedOff, false);
        expect(state.hasReachedMaxAttempts, false);
        expect(state.lastError, null);
        expect(state.canRetry, true);
        expect(state.timeUntilNextRetry, null);
      });
    });

    group('Retry Progression', () {
      test('should progress retry attempts with exponential backoff', () {
        var state = SetupRetryState.initial();

        // First retry
        state = state.nextRetryAttempt(maxAttempts: 3);
        expect(state.attemptCount, 1);
        expect(state.currentDelay, const Duration(seconds: 1));
        expect(state.isBackedOff, false);
        expect(state.hasReachedMaxAttempts, false);
        expect(state.canRetry, false); // Should wait for delay

        // Second retry
        state = state.nextRetryAttempt(maxAttempts: 3);
        expect(state.attemptCount, 2);
        expect(state.currentDelay, const Duration(seconds: 2));
        expect(state.isBackedOff, true);
        expect(state.hasReachedMaxAttempts, false);

        // Third retry (max reached)
        state = state.nextRetryAttempt(maxAttempts: 3);
        expect(state.attemptCount, 3);
        expect(state.currentDelay, const Duration(seconds: 4));
        expect(state.isBackedOff, true);
        expect(state.hasReachedMaxAttempts, true);
        expect(state.canRetry, false);
        expect(state.nextAttempt, null);
      });

      test('should use error suggested delay when available', () {
        final error = SetupError.containerCreationFailed();
        var state = SetupRetryState.initial();

        state = state.nextRetryAttempt(maxAttempts: 3, error: error);

        expect(state.currentDelay, const Duration(seconds: 30));
        expect(state.lastError, error);
      });

      test('should respect maximum delay', () {
        var state = SetupRetryState.initial();

        // Progress through many attempts to test max delay
        for (int i = 0; i < 10; i++) {
          state = state.nextRetryAttempt(
            maxAttempts: 15,
            baseDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
          );
        }

        expect(state.currentDelay.inSeconds, lessThanOrEqualTo(30));
      });
    });

    group('Retry Timing', () {
      test('should calculate time until next retry correctly', () {
        var state = SetupRetryState.initial();
        state = state.nextRetryAttempt(maxAttempts: 3);

        final timeUntilRetry = state.timeUntilNextRetry;
        expect(timeUntilRetry, isNotNull);
        expect(timeUntilRetry!.inSeconds, greaterThan(0));
      });

      test('should return zero duration when retry time has passed', () {
        var state = SetupRetryState.initial();

        // Create a state with next attempt in the past
        state = SetupRetryState(
          attemptCount: 1,
          lastAttempt: DateTime.now().subtract(const Duration(minutes: 1)),
          nextAttempt: DateTime.now().subtract(const Duration(seconds: 30)),
          currentDelay: const Duration(seconds: 1),
          hasReachedMaxAttempts: false,
        );

        expect(state.canRetry, true);
        expect(state.timeUntilNextRetry, Duration.zero);
      });
    });

    group('State Reset', () {
      test('should reset to initial state', () {
        var state = SetupRetryState.initial();

        // Progress through some attempts
        state = state.nextRetryAttempt(maxAttempts: 3);
        state = state.nextRetryAttempt(maxAttempts: 3);

        expect(state.attemptCount, 2);
        expect(state.isBackedOff, true);

        // Reset
        state = state.reset();

        expect(state.attemptCount, 0);
        expect(state.lastAttempt, null);
        expect(state.nextAttempt, null);
        expect(state.currentDelay, const Duration(seconds: 1));
        expect(state.isBackedOff, false);
        expect(state.hasReachedMaxAttempts, false);
        expect(state.lastError, null);
        expect(state.canRetry, true);
      });
    });

    group('String Representation', () {
      test('should provide meaningful string representation', () {
        var state = SetupRetryState.initial();
        state = state.nextRetryAttempt(maxAttempts: 3);

        final str = state.toString();

        expect(str, contains('SetupRetryState'));
        expect(str, contains('attempts: 1'));
        expect(str, contains('canRetry:'));
        expect(str, contains('delay:'));
      });
    });
  });
}

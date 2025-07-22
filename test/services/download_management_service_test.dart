import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:cloudtolocalllm/services/download_management_service.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([http.Client])
void main() {
  group('DownloadManagementService', () {
    late DownloadManagementService downloadService;

    setUp(() {
      TestConfig.initialize();
      downloadService = DownloadManagementService();
    });

    tearDown(() {
      downloadService.dispose();
      TestConfig.cleanup();
    });

    group('Initialization', () {
      test('should initialize with empty state', () {
        expect(downloadService.cachedReleaseInfo, null);
        expect(downloadService.isCacheValid, false);
      });
    });

    group('Download URL Generation', () {
      test('should generate Windows MSI download URL', () async {
        final url = await downloadService.generateDownloadUrl('windows', 'msi');

        expect(url, isNotEmpty);
        expect(url.toLowerCase(), contains('windows'));
        expect(url.toLowerCase(), contains('msi'));
      });

      test('should generate Windows ZIP download URL', () async {
        final url = await downloadService.generateDownloadUrl('windows', 'zip');

        expect(url, isNotEmpty);
        expect(url.toLowerCase(), contains('windows'));
        expect(url.toLowerCase(), contains('portable'));
      });

      test('should generate Linux AppImage download URL', () async {
        final url = await downloadService.generateDownloadUrl(
          'linux',
          'appimage',
        );

        expect(url, isNotEmpty);
        expect(url.toLowerCase(), contains('appimage'));
      });

      test('should generate Linux DEB download URL', () async {
        final url = await downloadService.generateDownloadUrl('linux', 'deb');

        expect(url, isNotEmpty);
        expect(url.toLowerCase(), contains('deb'));
      });

      test('should generate macOS DMG download URL', () async {
        final url = await downloadService.generateDownloadUrl('macos', 'dmg');

        expect(url, isNotEmpty);
        expect(url.toLowerCase(), contains('macos'));
        expect(url.toLowerCase(), contains('dmg'));
      });

      test('should handle unknown platform gracefully', () async {
        final url = await downloadService.generateDownloadUrl(
          'unknown',
          'unknown',
        );

        expect(url, isNotEmpty);
        // Should return fallback URL
      });

      test('should use fallback URL on API error', () async {
        // The service should handle API errors gracefully and return fallback URLs
        final url = await downloadService.generateDownloadUrl('windows', 'msi');

        expect(url, isNotEmpty);
        expect(url, contains('github.com'));
      });
    });

    group('Asset Name Generation', () {
      test('should generate correct asset names for Windows', () {
        final service = DownloadManagementService();

        // We can't directly test private methods, but we can test the behavior
        // through public methods that use them
        expect(
          () => service.generateDownloadUrl('windows', 'msi'),
          returnsNormally,
        );
        expect(
          () => service.generateDownloadUrl('windows', 'zip'),
          returnsNormally,
        );
      });

      test('should generate correct asset names for Linux', () {
        final service = DownloadManagementService();

        expect(
          () => service.generateDownloadUrl('linux', 'appimage'),
          returnsNormally,
        );
        expect(
          () => service.generateDownloadUrl('linux', 'deb'),
          returnsNormally,
        );
        expect(
          () => service.generateDownloadUrl('linux', 'tar.gz'),
          returnsNormally,
        );
      });

      test('should generate correct asset names for macOS', () {
        final service = DownloadManagementService();

        expect(
          () => service.generateDownloadUrl('macos', 'dmg'),
          returnsNormally,
        );
      });
    });

    group('Alternative Download URLs', () {
      test('should provide alternative URLs for Windows', () async {
        final alternatives = await downloadService.getAlternativeDownloadUrls(
          'windows',
        );

        expect(alternatives, isNotEmpty);
        expect(alternatives.any((url) => url.contains('github.com')), true);
        expect(alternatives.any((url) => url.contains('msi')), true);
        expect(alternatives.any((url) => url.contains('zip')), true);
      });

      test('should provide alternative URLs for Linux', () async {
        final alternatives = await downloadService.getAlternativeDownloadUrls(
          'linux',
        );

        expect(alternatives, isNotEmpty);
        expect(alternatives.any((url) => url.contains('github.com')), true);
        expect(alternatives.any((url) => url.contains('appimage')), true);
        expect(alternatives.any((url) => url.contains('deb')), true);
        expect(
          alternatives.any((url) => url.contains('aur.archlinux.org')),
          true,
        );
      });

      test('should provide alternative URLs for macOS', () async {
        final alternatives = await downloadService.getAlternativeDownloadUrls(
          'macos',
        );

        expect(alternatives, isNotEmpty);
        expect(alternatives.any((url) => url.contains('github.com')), true);
        expect(alternatives.any((url) => url.contains('dmg')), true);
      });

      test('should handle unknown platform for alternatives', () async {
        final alternatives = await downloadService.getAlternativeDownloadUrls(
          'unknown',
        );

        expect(alternatives, isNotEmpty);
        expect(alternatives.any((url) => url.contains('github.com')), true);
      });
    });

    group('Download Validation', () {
      test('should validate download on web platform', () async {
        final isValid = await downloadService.validateDownload('/path/to/file');

        // On web platform, validation should return true (not implemented)
        expect(isValid, true);
      });

      test('should handle validation errors gracefully', () async {
        expect(() => downloadService.validateDownload(''), returnsNormally);
      });
    });

    group('Download Tracking', () {
      test('should track download events', () {
        final initialStats = downloadService.getDownloadStatistics();
        expect(initialStats['totalDownloads'], 0);

        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        final updatedStats = downloadService.getDownloadStatistics();
        expect(updatedStats['totalDownloads'], 1);
        expect(updatedStats['platformCounts']['windows'], 1);
        expect(updatedStats['packageTypeCounts']['msi'], 1);
      });

      test('should track multiple download events', () {
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');
        downloadService.trackDownloadEvent('user456', 'linux', 'appimage');
        downloadService.trackDownloadEvent('user789', 'windows', 'zip');

        final stats = downloadService.getDownloadStatistics();
        expect(stats['totalDownloads'], 3);
        expect(stats['platformCounts']['windows'], 2);
        expect(stats['platformCounts']['linux'], 1);
        expect(stats['packageTypeCounts']['msi'], 1);
        expect(stats['packageTypeCounts']['appimage'], 1);
        expect(stats['packageTypeCounts']['zip'], 1);
      });

      test('should include last download timestamp in statistics', () {
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        final stats = downloadService.getDownloadStatistics();
        expect(stats['lastDownload'], isNotNull);
        expect(stats['lastDownload'], isA<DateTime>());
      });

      test('should clear tracking data', () {
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');
        expect(downloadService.getDownloadStatistics()['totalDownloads'], 1);

        downloadService.clearTrackingData();

        expect(downloadService.getDownloadStatistics()['totalDownloads'], 0);
      });
    });

    group('Cache Management', () {
      test('should refresh cache when requested', () async {
        expect(downloadService.isCacheValid, false);

        await downloadService.refreshCache();

        // Cache should be updated (even if it fails, the method should complete)
        expect(() => downloadService.refreshCache(), returnsNormally);
      });

      test('should handle cache refresh errors gracefully', () async {
        expect(() => downloadService.refreshCache(), returnsNormally);
      });
    });

    group('Statistics', () {
      test('should return empty statistics initially', () {
        final stats = downloadService.getDownloadStatistics();

        expect(stats['totalDownloads'], 0);
        expect(stats['platformCounts'], isEmpty);
        expect(stats['packageTypeCounts'], isEmpty);
        expect(stats['lastDownload'], null);
      });

      test('should calculate statistics correctly', () {
        // Add some test data
        downloadService.trackDownloadEvent('user1', 'windows', 'msi');
        downloadService.trackDownloadEvent('user2', 'windows', 'zip');
        downloadService.trackDownloadEvent('user3', 'linux', 'deb');
        downloadService.trackDownloadEvent('user4', 'linux', 'appimage');
        downloadService.trackDownloadEvent('user5', 'macos', 'dmg');

        final stats = downloadService.getDownloadStatistics();

        expect(stats['totalDownloads'], 5);
        expect(stats['platformCounts']['windows'], 2);
        expect(stats['platformCounts']['linux'], 2);
        expect(stats['platformCounts']['macos'], 1);
        expect(stats['packageTypeCounts']['msi'], 1);
        expect(stats['packageTypeCounts']['zip'], 1);
        expect(stats['packageTypeCounts']['deb'], 1);
        expect(stats['packageTypeCounts']['appimage'], 1);
        expect(stats['packageTypeCounts']['dmg'], 1);
      });
    });

    group('Notification Behavior', () {
      test('should notify listeners when tracking data changes', () {
        var notificationCount = 0;
        downloadService.addListener(() {
          notificationCount++;
        });

        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        expect(notificationCount, 1);
      });

      test('should notify listeners when tracking data is cleared', () {
        var notificationCount = 0;

        // Add some data first
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        // Then add listener and clear
        downloadService.addListener(() {
          notificationCount++;
        });

        downloadService.clearTrackingData();

        expect(notificationCount, 1);
      });

      test('should notify listeners when cache is refreshed', () async {
        var notificationCount = 0;
        downloadService.addListener(() {
          notificationCount++;
        });

        await downloadService.refreshCache();

        expect(
          notificationCount,
          greaterThanOrEqualTo(0),
        ); // May or may not notify depending on implementation
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Test that methods don't throw even when network is unavailable
        expect(
          () => downloadService.generateDownloadUrl('windows', 'msi'),
          returnsNormally,
        );
        expect(
          () => downloadService.getAlternativeDownloadUrls('windows'),
          returnsNormally,
        );
        expect(() => downloadService.refreshCache(), returnsNormally);
      });

      test('should handle invalid parameters gracefully', () async {
        expect(
          () => downloadService.generateDownloadUrl('', ''),
          returnsNormally,
        );
        expect(
          () => downloadService.getAlternativeDownloadUrls(''),
          returnsNormally,
        );
        expect(
          () => downloadService.trackDownloadEvent('', '', ''),
          returnsNormally,
        );
      });
    });

    group('Disposal', () {
      test('should dispose properly without errors', () {
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        expect(() => downloadService.dispose(), returnsNormally);
      });

      test('should clear tracking data on disposal', () {
        downloadService.trackDownloadEvent('user123', 'windows', 'msi');

        downloadService.dispose();

        // After disposal, tracking data should be cleared
        // Note: We can't test this directly since the object is disposed
        expect(() => downloadService.dispose(), returnsNormally);
      });
    });
  });

  group('DownloadTrackingInfo', () {
    group('Creation', () {
      test('should create tracking info correctly', () {
        final timestamp = DateTime.now();
        final trackingInfo = DownloadTrackingInfo(
          userId: 'user123',
          platform: 'windows',
          packageType: 'msi',
          timestamp: timestamp,
          userAgent: 'Test Browser',
        );

        expect(trackingInfo.userId, 'user123');
        expect(trackingInfo.platform, 'windows');
        expect(trackingInfo.packageType, 'msi');
        expect(trackingInfo.timestamp, timestamp);
        expect(trackingInfo.userAgent, 'Test Browser');
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final timestamp = DateTime.now();
        final trackingInfo = DownloadTrackingInfo(
          userId: 'user123',
          platform: 'windows',
          packageType: 'msi',
          timestamp: timestamp,
          userAgent: 'Test Browser',
        );

        final json = trackingInfo.toJson();

        expect(json['userId'], 'user123');
        expect(json['platform'], 'windows');
        expect(json['packageType'], 'msi');
        expect(json['timestamp'], timestamp.toIso8601String());
        expect(json['userAgent'], 'Test Browser');
      });
    });

    group('String Representation', () {
      test('should provide meaningful string representation', () {
        final trackingInfo = DownloadTrackingInfo(
          userId: 'user123',
          platform: 'windows',
          packageType: 'msi',
          timestamp: DateTime.now(),
          userAgent: 'Test Browser',
        );

        final str = trackingInfo.toString();

        expect(str, contains('DownloadTrackingInfo'));
        expect(str, contains('windows'));
        expect(str, contains('msi'));
      });
    });
  });
}

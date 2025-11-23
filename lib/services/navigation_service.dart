/// Navigation Service
///
/// Handles navigation to external URLs and admin center access.
library;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Navigation Service for handling app navigation
class NavigationService extends ChangeNotifier {
  /// Navigate to Admin Center with session token
  Future<void> navigateToAdminCenter({required String token}) async {
    try {
      final adminCenterUrl = AppConfig.adminCenterUrl;

      if (adminCenterUrl.isEmpty) {
        throw Exception('Admin Center URL is not configured');
      }

      // Add token as query parameter
      final urlWithToken = Uri.parse(adminCenterUrl).replace(
        queryParameters: {
          'token': token,
        },
      ).toString();

      // Launch URL
      final uri = Uri.parse(urlWithToken);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch Admin Center URL: $urlWithToken');
      }
    } catch (e) {
      debugPrint('[NavigationService] Error navigating to Admin Center: $e');
      rethrow;
    }
  }

  /// Navigate to external URL
  Future<void> navigateToUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch URL: $url');
      }
    } catch (e) {
      debugPrint('[NavigationService] Error navigating to URL: $e');
      rethrow;
    }
  }
}

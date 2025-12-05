import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'download_screen.dart';
import 'documentation_screen.dart';
import '../home_screen.dart';

// Re-export HomepageScreen for use in router.dart's home route
export 'homepage_screen.dart';

// This file contains the route configuration for the marketing screens,
// which will be lazy-loaded to improve initial application performance.

final marketingRoutes = [
  GoRoute(
    path: '/download',
    name: 'download',
    builder: (context, state) {
      // Only available on web platform
      if (kIsWeb) {
        return const DownloadScreen();
      } else {
        // Redirect desktop users to main app
        return const HomeScreen();
      }
    },
  ),
  GoRoute(
    path: '/docs',
    name: 'docs',
    builder: (context, state) {
      // Only available on web platform
      if (kIsWeb) {
        return const DocumentationScreen();
      } else {
        // Redirect desktop users to main app
        return const HomeScreen();
      }
    },
  ),
];

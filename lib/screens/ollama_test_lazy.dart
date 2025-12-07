import 'package:go_router/go_router.dart';

import 'ollama_test_screen.dart';

// This file contains the route configuration for the Ollama test screen,
// which will be lazy-loaded to improve initial application performance.

final ollamaTestRoutes = [
  GoRoute(
    path: '/ollama-test',
    name: 'ollama-test',
    builder: (context, state) => const OllamaTestScreen(),
  ),
];

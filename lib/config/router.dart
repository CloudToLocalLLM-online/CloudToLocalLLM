import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Web-specific import for URL parsing (modern web APIs)
import 'package:web/web.dart' as web;
import '../services/auth_service.dart';
import '../services/connection_manager_service.dart';
import '../services/streaming_chat_service.dart';
import '../services/tunnel_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/ollama_test_screen.dart';
import '../di/locator.dart' as di;

// No web-specific imports needed - using platform-safe approach

import '../screens/settings/llm_provider_settings_screen.dart';
import '../screens/settings/daemon_settings_screen.dart';
import '../screens/settings/connection_status_screen.dart';
import '../screens/unified_settings_screen.dart';

// Admin screens
import '../screens/admin/admin_panel_screen.dart';
import '../screens/admin/admin_data_flush_screen.dart';

// Marketing screens (web-only)
import '../screens/marketing/homepage_screen.dart';
import '../screens/marketing/download_screen.dart';
import '../screens/marketing/documentation_screen.dart';

/// Utility function to get the current hostname in web environment
String _getCurrentHostname() {
  if (kIsWeb) {
    try {
      // Use Uri.base as the primary method for hostname detection
      final currentUrl = Uri.base.toString();
      final uri = Uri.parse(currentUrl);
      return uri.host;
    } catch (e) {
      // If Uri.base fails, return empty string
      return '';
    }
  }
  return '';
}

/// Check if current hostname indicates app subdomain
bool _isAppSubdomain() {
  if (!kIsWeb) return false;

  final hostname = _getCurrentHostname();
  final isApp =
      hostname.startsWith('app.') || hostname == 'app.cloudtolocalllm.online';

  debugPrint('[Router] Hostname: $hostname, isApp: $isApp');
  return isApp;
}

/// Check if authenticated services are loaded
/// Returns true if all critical authenticated services are registered
bool _checkAuthenticatedServicesLoaded() {
  try {
    // Check for critical authenticated services
    // These services are registered only after authentication
    final hasConnectionManager =
        di.serviceLocator.isRegistered<ConnectionManagerService>();
    final hasStreamingChat =
        di.serviceLocator.isRegistered<StreamingChatService>();
    final hasTunnelService = di.serviceLocator.isRegistered<TunnelService>();

    // All critical services must be registered
    final allServicesLoaded =
        hasConnectionManager && hasStreamingChat && hasTunnelService;

    if (!allServicesLoaded) {
      debugPrint(
        '[Router] Authenticated services check: ConnectionManager=$hasConnectionManager, StreamingChat=$hasStreamingChat, TunnelService=$hasTunnelService',
      );
    }

    return allServicesLoaded;
  } catch (e) {
    debugPrint('[Router] Error checking authenticated services: $e');
    return false;
  }
}

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    required AuthService authService,
  }) {
    // Store authService for use in route builders
    final authServiceRef = authService;
      // For web, get the full URL including query parameters to preserve callback data
      // This ensures Auth0 callback parameters are available to the router
    String initialLocation;
    if (kIsWeb) {
      try {
        // Use Uri.base to get the full current URL with query parameters
        final currentUri = Uri.base;
        initialLocation = currentUri.path;
        if (currentUri.hasQuery) {
          initialLocation += '?${currentUri.query}';
        }
        debugPrint('[Router] Initial location with query params: $initialLocation');
      } catch (e) {
        debugPrint('[Router] Error getting current URI: $e');
        initialLocation = '/';
      }
    } else {
      initialLocation = '/';
    }

    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: authService,
      routes: [
        // Home route - platform-specific routing
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) {
            debugPrint('[Router] ===== NEW HOME ROUTE BUILDER START =====');
            debugPrint('[Router] 🔥🔥🔥 THIS IS THE NEW CODE - TIME: ${DateTime.now()} 🔥🔥🔥');

            // First check if user is already authenticated with Auth0
            bool isAlreadyAuthenticated = false;
            bool hasCallbackParams = false;

            if (kIsWeb) {
              try {
                // Check if Auth0 client is ready and user is authenticated
                debugPrint('[Router] Checking Auth0 authentication status...');
                isAlreadyAuthenticated = authServiceRef.auth0Service.isAuthenticated;
                debugPrint('[Router] Auth0 isAuthenticated: $isAlreadyAuthenticated');

                if (!isAlreadyAuthenticated) {
                  // Not authenticated, check for callback parameters
                  debugPrint('[Router] Not authenticated, checking for callback URL...');
                  debugPrint('[Router] Current URL: ${Uri.base.toString()}');
                  hasCallbackParams = authServiceRef.auth0Service.isCallbackUrl();
                  debugPrint('[Router] isCallbackUrl() returned: $hasCallbackParams');
                }
              } catch (e) {
                debugPrint('[Router] Error checking auth status: $e');
                debugPrint('[Router] Error stack: ${e.toString()}');
              }
            }

            debugPrint('[Router] isAlreadyAuthenticated: $isAlreadyAuthenticated, hasCallbackParams: $hasCallbackParams');

            // Decision tree for routing:
            // 1. If already authenticated -> show main app
            // 2. If callback parameters -> process callback
            // 3. Otherwise -> show login screen

            if (isAlreadyAuthenticated) {
              debugPrint('[Router] User already authenticated, showing main app');
              // Verify authenticated services are loaded before showing HomeScreen
              final hasAuthenticatedServices = _checkAuthenticatedServicesLoaded();
              if (!hasAuthenticatedServices) {
                debugPrint('[Router] Authenticated services not yet loaded, showing loading screen');
                return const LoadingScreen(message: 'Loading application modules...');
              }
              debugPrint('[Router] Showing home screen for authenticated user');
              return const HomeScreen();
            }

            // If we have callback parameters, redirect to callback route
            if (hasCallbackParams) {
              debugPrint('[Router] Home route detected callback params, redirecting to callback');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/callback');
                }
              });
              return const LoadingScreen(message: 'Processing authentication...');
            }

            // Web: Domain detection handled by redirect logic
            // Desktop: Chat interface
            if (kIsWeb) {
              // Use robust hostname detection
              final isAppSubdomain = _isAppSubdomain();

              if (isAppSubdomain) {
                final isAuthLoading = authService.isLoading.value;
                final isAuthenticated = authService.isAuthenticated.value;
                debugPrint(
                  '[Router] Route builder called - isLoading: $isAuthLoading, isAuthenticated: $isAuthenticated',
                );

                // If authentication is still loading, show loading screen
                if (isAuthLoading) {
                  debugPrint('[Router] Showing loading screen');
                  return const LoadingScreen(
                    message: 'Checking authentication...',
                  );
                }

                if (isAuthenticated) {
                  // Verify authenticated services are loaded before showing HomeScreen
                  // This ensures modules are only loaded after authentication
                  final hasAuthenticatedServices = _checkAuthenticatedServicesLoaded();
                  if (!hasAuthenticatedServices) {
                    debugPrint(
                      '[Router] Authenticated services not yet loaded, showing loading screen',
                    );
                    return const LoadingScreen(
                      message: 'Loading application modules...',
                    );
                  }
                  debugPrint('[Router] Showing home screen');
                  return const HomeScreen();
                } else {
                  debugPrint('[Router] Showing login screen');
                  return const LoginScreen();
                }
              } else {
                // Root domain - show marketing homepage
                return const HomepageScreen();
              }
            } else {
              // For desktop, home is the chat interface
              return const HomeScreen();
            }
          },
        ),

        // Chat route - main app interface (accessible via app subdomain)
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) {
            // Verify authenticated services are loaded before showing HomeScreen
            final isAuthenticated = authService.isAuthenticated.value;
            if (isAuthenticated) {
              final hasAuthenticatedServices = _checkAuthenticatedServicesLoaded();
              if (!hasAuthenticatedServices) {
                return const LoadingScreen(
                  message: 'Loading application modules...',
                );
              }
            }
            return const HomeScreen();
          },
        ),

        // Download route - web-only marketing page
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

        // Documentation route - web-only
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

        // Login route
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Auth callback route (web only)
        GoRoute(
          path: '/callback',
          name: 'callback',
          builder: (context, state) {
            // For desktop platforms, redirect immediately to prevent callback loop
            if (!kIsWeb) {
              debugPrint(
                '[Router] Desktop platform accessing callback route - redirecting to login',
              );
              // Use a post-frame callback to redirect after the current build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/login');
                }
              });
              // Return a simple loading screen while redirecting
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Redirecting...'),
                    ],
                  ),
                ),
              );
            }
            // Pass the state with query parameters to CallbackScreen
            debugPrint(
              '[Router] Building CallbackScreen with query params: ${state.uri.queryParameters}',
            );
            return const CallbackScreen();
          },
        ),

        // Loading route
        GoRoute(
          path: '/loading',
          name: 'loading',
          builder: (context, state) {
            final message =
                state.uri.queryParameters['message'] ?? 'Loading...';
            return LoadingScreen(message: message);
          },
        ),

        // Ollama test route
        GoRoute(
          path: '/ollama-test',
          name: 'ollama-test',
          builder: (context, state) => const OllamaTestScreen(),
        ),

        // Settings route - unified settings interface with sidebar layout
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const UnifiedSettingsScreen(),
        ),

        // Settings with specific section
        GoRoute(
          path: '/settings/downloads',
          name: 'settings-downloads',
          builder: (context, state) =>
              const UnifiedSettingsScreen(initialSection: 'downloads'),
        ),

        // Tunnel Settings route (legacy/advanced tunnel configuration)
        GoRoute(
          path: '/settings/tunnel',
          name: 'tunnel-settings',
          builder: (context, state) =>
              const UnifiedSettingsScreen(initialSection: 'tunnel-connection'),
        ),

        // LLM Provider Settings route
        GoRoute(
          path: '/settings/llm-provider',
          name: 'llm-provider-settings',
          builder: (context, state) => const LLMProviderSettingsScreen(),
        ),

        // Daemon Settings route
        GoRoute(
          path: '/settings/daemon',
          name: 'daemon-settings',
          builder: (context, state) {
            debugPrint("[Router] Building DaemonSettingsScreen");
            return const DaemonSettingsScreen();
          },
        ),

        // Connection Status route
        GoRoute(
          path: '/settings/connection-status',
          name: 'connection-status',
          builder: (context, state) {
            debugPrint("[Router] Building ConnectionStatusScreen");
            return const ConnectionStatusScreen();
          },
        ),

        // Admin Panel route (requires admin privileges)
        GoRoute(
          path: '/admin',
          name: 'admin-panel',
          builder: (context, state) {
            debugPrint("[AdminPanel] Building AdminPanelScreen");
            return const AdminPanelScreen();
          },
        ),

        // Admin Data Flush route (requires admin privileges)
        GoRoute(
          path: '/admin/data-flush',
          name: 'admin-data-flush',
          builder: (context, state) {
            debugPrint("[Router] Building AdminDataFlushScreen");
            return const AdminDataFlushScreen();
          },
        ),
      ],

      // Redirect logic for authentication and domain-based routing
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated.value;
        final isAuthLoading = authService.isLoading.value;
        final isLoggingIn = state.matchedLocation == '/login';
        final isCallback = state.matchedLocation == '/callback';
        final isLoading = state.matchedLocation == '/loading';
        final isHomepage = state.matchedLocation == '/' && kIsWeb;
        final isDownload = state.matchedLocation == '/download' && kIsWeb;
        final isDocs = state.matchedLocation == '/docs' && kIsWeb;

        // Check for Auth0 callback parameters in URL (code and state)
        // Use both state.uri and Uri.base to catch all cases
        final stateUri = state.uri;
        final baseUri = kIsWeb ? Uri.base : stateUri;

        // Debug logging for callback detection
        debugPrint('[Router] Checking callback params...');
        debugPrint('[Router] stateUri: ${stateUri.toString()}');
        debugPrint('[Router] stateUri.queryParameters: ${stateUri.queryParameters}');
        debugPrint('[Router] baseUri: ${baseUri.toString()}');
        debugPrint('[Router] baseUri.queryParameters: ${baseUri.queryParameters}');

        // For web, get query parameters from current browser location
        Map<String, String> queryParams;
        if (kIsWeb) {
          try {
            // Use web.window.location.href to get current URL with query params
            final currentUrl = Uri.parse(web.window.location.href);
            queryParams = currentUrl.queryParameters;
            debugPrint('[Router] Current browser URL: ${web.window.location.href}');
            debugPrint('[Router] Parsed query params: $queryParams');
          } catch (e) {
            debugPrint('[Router] Error parsing current URL: $e');
            queryParams = stateUri.queryParameters.isNotEmpty
                ? stateUri.queryParameters
                : (baseUri.queryParameters.isNotEmpty ? baseUri.queryParameters : {});
          }
        } else {
          queryParams = stateUri.queryParameters.isNotEmpty
              ? stateUri.queryParameters
              : (baseUri.queryParameters.isNotEmpty ? baseUri.queryParameters : {});
        }

        final hasCallbackParams = kIsWeb &&
            (queryParams.containsKey('code') || queryParams.containsKey('state'));

        debugPrint('[Router] hasCallbackParams: $hasCallbackParams');
        debugPrint('[Router] queryParams keys: ${queryParams.keys.toList()}');

        // Use robust hostname detection
        final isAppSubdomain = _isAppSubdomain();

        debugPrint('[Router] Redirect check: ${state.matchedLocation}');
        debugPrint('[Router] Full URI: ${stateUri.toString()}');
        debugPrint('[Router] Query params: $queryParams');
        debugPrint(
          '[Router] Auth state: $isAuthenticated, Auth loading: $isAuthLoading, App subdomain: $isAppSubdomain',
        );
        debugPrint(
          '[Router] Route flags: isLoggingIn: $isLoggingIn, isCallback: $isCallback, isLoading: $isLoading, isHomepage: $isHomepage, hasCallbackParams: $hasCallbackParams',
        );

        // CRITICAL: If we have callback parameters but we're not on /callback route, redirect there
        if (hasCallbackParams && !isCallback && kIsWeb) {
          debugPrint(
            '[Router] Detected Auth0 callback parameters, redirecting to /callback',
          );
          // Preserve query parameters when redirecting to callback
          final callbackUri = Uri(
            path: '/callback',
            queryParameters: queryParams.cast<String, dynamic>(),
          );
          debugPrint('[Router] Redirecting to: ${callbackUri.toString()}');
          return callbackUri.toString();
        }

        // Allow access to marketing pages on web root domain without authentication
        if (kIsWeb && !isAppSubdomain && (isHomepage || isDownload || isDocs)) {
          debugPrint('[Router] Allowing access to marketing page');
          return null;
        }

        // If authentication is still loading, defer redirect decisions
        if (isAuthLoading && !isCallback) {
          debugPrint('[Router] Auth still loading - deferring redirect');
          return null; // Stay on current route until auth loading completes
        }

        // Allow access to login, callback, and loading pages
        if (isLoggingIn || isCallback || isLoading) {
          debugPrint('[Router] Allowing access to auth/loading page');
          return null;
        }

        // For callback route, handle platform-specific logic
        if (isCallback) {
          if (kIsWeb) {
            debugPrint('[Router] Allowing access to callback page (web)');
            return null;
          } else {
            // Desktop platforms should not use callback route
            debugPrint(
              '[Router] Desktop callback route accessed - redirecting based on auth state',
            );
            if (isAuthenticated) {
              return '/';
            } else {
              return '/login';
            }
          }
        }

        // For desktop, require authentication (web auth handled in route builder)
        if (!kIsWeb && !isAuthenticated && !isAuthLoading) {
          debugPrint(
            '[Router] Redirecting desktop to login - user not authenticated',
          );
          return '/login';
        }

        // Allow access to protected routes
        debugPrint('[Router] Allowing access to protected route');
        return null;
      },

      // Error handling
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'The page "${state.matchedLocation}" could not be found.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

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
import '../screens/admin/admin_data_flush_screen.dart';
import '../screens/admin/admin_center_screen.dart';

// Marketing screens (web-only)
import '../screens/marketing/homepage_screen.dart';
import '../screens/marketing/download_screen.dart';
import '../screens/marketing/documentation_screen.dart';

const _callbackStorageKey = 'auth0_callback_params';
const _callbackForwardedKey = 'auth0_callback_forwarded';

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

    debugPrint(
      '[Router] Authenticated services loading status: ConnectionManager=$hasConnectionManager, StreamingChat=$hasStreamingChat, TunnelService=$hasTunnelService, allLoaded=$allServicesLoaded',
    );

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
        debugPrint(
          '[Router] Initial location with query params: $initialLocation',
        );
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

            // Check if user is already authenticated with Auth0
            bool isAlreadyAuthenticated = false;

            if (kIsWeb) {
              try {
                // Check if Auth0 client is ready and user is authenticated
                debugPrint('[Router] Checking Auth0 authentication status...');
                isAlreadyAuthenticated =
                    authServiceRef.auth0Service.isAuthenticated;
                debugPrint(
                  '[Router] Auth0 isAuthenticated: $isAlreadyAuthenticated',
                );
              } catch (e) {
                debugPrint('[Router] Error checking auth status: $e');
                debugPrint('[Router] Error stack: ${e.toString()}');
              }
            }

            debugPrint(
              '[Router] isAlreadyAuthenticated: $isAlreadyAuthenticated',
            );

            // Decision tree for routing:
            // 1. If already authenticated -> show main app
            // 2. Otherwise -> show login screen

            if (isAlreadyAuthenticated) {
              debugPrint(
                '[Router] User already authenticated, showing main app',
              );
              // Verify authenticated services are loaded before showing HomeScreen
              final hasAuthenticatedServices =
                  _checkAuthenticatedServicesLoaded();
              if (!hasAuthenticatedServices) {
                debugPrint(
                  '[Router] Authenticated services not yet loaded, showing loading screen',
                );
                return const LoadingScreen(
                  message: 'Loading application modules...',
                );
              }
              debugPrint('[Router] Showing home screen for authenticated user');
              return const HomeScreen();
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
                  final hasAuthenticatedServices =
                      _checkAuthenticatedServicesLoaded();
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
              final hasAuthenticatedServices =
                  _checkAuthenticatedServicesLoaded();
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
            Map<String, String> callbackParams = state.uri.queryParameters;
            if (callbackParams.isEmpty && kIsWeb) {
              final baseParams = Uri.base.queryParameters;
              if (baseParams.isNotEmpty) {
                callbackParams = baseParams;
              }
            }
            debugPrint(
              '[Router] Building CallbackScreen with query params: $callbackParams',
            );
            return CallbackScreen(queryParams: callbackParams);
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
              const UnifiedSettingsScreen(initialCategory: 'downloads'),
        ),

        // Tunnel Settings route (legacy/advanced tunnel configuration)
        GoRoute(
          path: '/settings/tunnel',
          name: 'tunnel-settings',
          builder: (context, state) =>
              const UnifiedSettingsScreen(initialCategory: 'tunnel-connection'),
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

        // Admin Data Flush route (requires admin privileges)
        GoRoute(
          path: '/admin/data-flush',
          name: 'admin-data-flush',
          builder: (context, state) {
            debugPrint("[Router] Building AdminDataFlushScreen");
            return const AdminDataFlushScreen();
          },
        ),

        // Admin Center route (requires admin privileges)
        // This is separate from AdminPanelScreen which handles system administration
        // Admin Center focuses on user/payment management
        GoRoute(
          path: '/admin-center',
          name: 'admin-center',
          builder: (context, state) {
            debugPrint("[Router] Building AdminCenterScreen");

            // Check if user is authenticated
            final authService = authServiceRef;
            if (!authService.isAuthenticated.value) {
              debugPrint(
                  "[Router] User not authenticated, redirecting to login");
              // Redirect to login will be handled by redirect logic
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return const AdminCenterScreen();
          },
        ),
      ],

      // Redirect logic for authentication and domain-based routing
      redirect: (context, state) {
        debugPrint('[Router] ===== REDIRECT FUNCTION CALLED =====');
        debugPrint('[Router] Matched location: ${state.matchedLocation}');
        debugPrint('[Router] Full path: ${state.fullPath}');
        debugPrint('[Router] URI: ${state.uri}');
        final isAuthenticated = authService.isAuthenticated.value;
        final isAuthLoading = authService.isLoading.value;
        final areServicesLoaded =
            authService.areAuthenticatedServicesLoaded.value;
        debugPrint(
          '[Router] Auth state: isAuthenticated=$isAuthenticated, isLoading=$isAuthLoading, servicesLoaded=$areServicesLoaded',
        );
        final isLoggingIn = state.matchedLocation == '/login';
        final isCallback = state.matchedLocation == '/callback';
        final isLoading = state.matchedLocation == '/loading';
        final isHomepage = state.matchedLocation == '/' && kIsWeb;
        final isDownload = state.matchedLocation == '/download' && kIsWeb;
        final isDocs = state.matchedLocation == '/docs' && kIsWeb;

        // Check for Auth0 callback parameters in URL (code and state)
        // Use both state.uri and Uri.base to catch all cases
        // Check for Auth0 callback parameters in URL (code and state)
        final stateUri = state.uri;

        // Debug logging for callback detection
        debugPrint('[Router] ===== CALLBACK PARAMETER DETECTION START =====');
        debugPrint('[Router] stateUri: ${stateUri.toString()}');
        debugPrint(
          '[Router] stateUri.queryParameters: ${stateUri.queryParameters}',
        );

        // For web, get query parameters from the target state URI
        // CRITICAL: Do NOT use Uri.base here, as it reflects the *current* URL
        // which might be different from the *target* URL (state.uri) during navigation.
        // Using Uri.base causes infinite loops when navigating away from a URL with params.
        Map<String, String> queryParams = stateUri.queryParameters;
        bool callbackParamsFromSessionStorage = false;
        bool callbackAlreadyForwarded = false;
        if (kIsWeb) {
          // Check if callback parameters have already been forwarded
          try {
            final sessionStorage = window.sessionStorage;
            final forwardedFlag = sessionStorage.getItem(_callbackForwardedKey);
            callbackAlreadyForwarded = forwardedFlag == 'true';
            debugPrint(
              '[Router] Callback forwarded flag from sessionStorage: $forwardedFlag',
            );
          } catch (e) {
            debugPrint('[Router] Error reading callback forwarded flag: $e');
          }

          if (queryParams.isEmpty) {
            try {
              final sessionStorage = window.sessionStorage;
              final storedParams = sessionStorage.getItem(_callbackStorageKey);
              if (storedParams != null && storedParams.isNotEmpty) {
                final sanitized = storedParams.startsWith('?')
                    ? storedParams.substring(1)
                    : storedParams;
                final storedQueryParams = Uri.splitQueryString(sanitized);
                if (storedQueryParams.isNotEmpty) {
                  queryParams = storedQueryParams;
                  callbackParamsFromSessionStorage = true;
                  debugPrint(
                    '[Router] Loaded callback params from sessionStorage: $storedQueryParams',
                  );
                }
              } else {
                debugPrint(
                  '[Router] No callback params found in sessionStorage',
                );
              }
            } catch (e) {
              debugPrint(
                '[Router] Error reading sessionStorage callback params: $e',
              );
            }
          }
        }

        // Determine if we have callback parameters that haven't been forwarded yet
        final rawHasCallbackParams =
            queryParams.containsKey('code') && queryParams.containsKey('state');
        final hasCallbackParams =
            kIsWeb && rawHasCallbackParams && !callbackAlreadyForwarded;

        debugPrint(
          '[Router] rawHasCallbackParams: $rawHasCallbackParams (code: ${queryParams.containsKey('code')}, state: ${queryParams.containsKey('state')})',
        );
        debugPrint(
          '[Router] callbackAlreadyForwarded: $callbackAlreadyForwarded',
        );
        debugPrint(
          '[Router] hasCallbackParams (unforwarded): $hasCallbackParams',
        );
        debugPrint('[Router] queryParams keys: ${queryParams.keys.toList()}');
        debugPrint(
          '[Router] callbackParamsFromSessionStorage: $callbackParamsFromSessionStorage',
        );
        debugPrint('[Router] ===== CALLBACK PARAMETER DETECTION END =====');

        // Use robust hostname detection
        final isAppSubdomain = _isAppSubdomain();

        debugPrint('[Router] ===== REDIRECT DECISION LOGIC START =====');
        debugPrint('[Router] Current route: ${state.matchedLocation}');
        debugPrint('[Router] Full URI: ${stateUri.toString()}');
        debugPrint('[Router] Query params: $queryParams');
        debugPrint(
          '[Router] Auth state: isAuthenticated=$isAuthenticated, isAuthLoading=$isAuthLoading',
        );
        debugPrint(
          '[Router] Platform state: kIsWeb=$kIsWeb, isAppSubdomain=$isAppSubdomain',
        );
        debugPrint(
          '[Router] Route flags: isLoggingIn=$isLoggingIn, isCallback=$isCallback, isLoading=$isLoading, isHomepage=$isHomepage',
        );
        debugPrint(
          '[Router] Callback state: hasCallbackParams=$hasCallbackParams, rawHasCallbackParams=$rawHasCallbackParams, callbackAlreadyForwarded=$callbackAlreadyForwarded',
        );

        // CRITICAL: If we have unforwarded callback parameters but we're not on /callback route, redirect there
        // This ensures callback parameters are processed exactly once
        if (hasCallbackParams && !isCallback && kIsWeb) {
          debugPrint(
            '[Router] DECISION: Detected unforwarded Auth0 callback parameters, redirecting to /callback',
          );
          debugPrint('[Router] Callback params to forward: $queryParams');
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Reason: Callback parameters present but not on callback route',
          );

          // Mark callback parameters as forwarded to prevent re-processing
          try {
            window.sessionStorage.setItem(_callbackForwardedKey, 'true');
            debugPrint(
              '[Router] Successfully marked callback params as forwarded in sessionStorage',
            );
          } catch (e) {
            debugPrint(
              '[Router] ERROR: Failed to mark callback params as forwarded: $e',
            );
          }

          // Preserve query parameters when redirecting to callback
          final callbackUri = Uri(
            path: '/callback',
            queryParameters: queryParams.cast<String, dynamic>(),
          );
          debugPrint(
            '[Router] Redirecting from ${state.matchedLocation} to: ${callbackUri.toString()}',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: FORWARD TO /callback =====',
          );
          return callbackUri.toString();
        }

        // If we're on the callback route with callback parameters, allow processing
        // NEVER redirect from /callback to /login when callback parameters are present
        if (isCallback && rawHasCallbackParams && kIsWeb) {
          debugPrint(
            '[Router] DECISION: On /callback route with callback parameters present',
          );
          debugPrint('[Router] Query params: $queryParams');
          debugPrint('[Router] Auth state: isAuthenticated=$isAuthenticated');
          debugPrint(
            '[Router] Allowing callback processing (no redirect to login)',
          );
          debugPrint(
            '[Router] Reason: Callback route with valid callback parameters',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: ALLOW CALLBACK PROCESSING =====',
          );
          return null;
        }

        // Allow access to marketing pages on web root domain without authentication
        if (kIsWeb && !isAppSubdomain && (isHomepage || isDownload || isDocs)) {
          debugPrint(
            '[Router] DECISION: Allowing access to marketing page (root domain)',
          );
          debugPrint('[Router] Route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Reason: Marketing page on root domain, no auth required',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: ALLOW MARKETING PAGE =====',
          );
          return null;
        }

        // If authentication is still loading, defer redirect decisions
        if (isAuthLoading && !isCallback) {
          debugPrint(
            '[Router] DECISION: Auth still loading - deferring redirect',
          );
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Reason: Waiting for authentication state to be determined',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: DEFER (AUTH LOADING) =====',
          );
          return null; // Stay on current route until auth loading completes
        }

        // Allow access to login and loading pages
        if (isLoggingIn || isLoading) {
          // On web main domain, redirect /login to / (marketing homepage)
          if (isLoggingIn && kIsWeb && !isAppSubdomain) {
            debugPrint(
                '[Router] DECISION: Redirecting /login to / on main domain');
            return '/';
          }

          // If on loading screen but services are loaded, redirect to home
          if (isLoading && isAuthenticated && areServicesLoaded) {
            debugPrint(
                '[Router] DECISION: Services loaded, redirecting from loading to home');
            return '/';
          }

          debugPrint('[Router] DECISION: Allowing access to auth/loading page');
          debugPrint('[Router] Route: ${state.matchedLocation}');
          debugPrint('[Router] Auth state: isAuthenticated=$isAuthenticated');
          debugPrint('[Router] Reason: Login or loading page access allowed');
          debugPrint(
            '[Router] ===== REDIRECT DECISION: ALLOW AUTH/LOADING PAGE =====',
          );
          return null;
        }

        // For callback route, handle platform-specific logic
        if (isCallback) {
          if (kIsWeb) {
            debugPrint(
              '[Router] DECISION: Allowing access to callback page (web)',
            );
            debugPrint('[Router] Query params: $queryParams');
            debugPrint('[Router] Reason: Web platform callback processing');
            debugPrint(
              '[Router] ===== REDIRECT DECISION: ALLOW CALLBACK PAGE =====',
            );
            return null;
          } else {
            // Desktop platforms should not use callback route
            debugPrint(
              '[Router] DECISION: Desktop callback route accessed - redirecting based on auth state',
            );
            debugPrint('[Router] Auth state: isAuthenticated=$isAuthenticated');
            if (isAuthenticated) {
              debugPrint(
                '[Router] Reason: Desktop authenticated, redirecting to home',
              );
              debugPrint(
                '[Router] ===== REDIRECT DECISION: DESKTOP CALLBACK -> HOME =====',
              );
              return '/';
            } else {
              debugPrint(
                '[Router] Reason: Desktop not authenticated, redirecting to login',
              );
              debugPrint(
                '[Router] ===== REDIRECT DECISION: DESKTOP CALLBACK -> LOGIN =====',
              );
              return '/login';
            }
          }
        }

        // If authenticated but services not yet loaded, only redirect to loading
        // for protected routes that require authenticated services
        // Don't redirect from home route (/) as it handles loading state internally
        if (isAuthenticated &&
            !areServicesLoaded &&
            !isLoading &&
            !isHomepage) {
          debugPrint(
            '[Router] DECISION: Authenticated but services not loaded - showing loading screen',
          );
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Auth state: isAuthenticated=$isAuthenticated, servicesLoaded=$areServicesLoaded',
          );
          debugPrint(
            '[Router] Reason: Waiting for authenticated services to load',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: SHOW LOADING (SERVICES LOADING) =====',
          );
          return '/loading?message=${Uri.encodeComponent('Loading application modules...')}';
        }

        // NEVER redirect to login when authentication state is true
        // This prevents the login loop after successful authentication
        if (isAuthenticated && isLoggingIn) {
          debugPrint(
            '[Router] DECISION: Authenticated user on login page - redirecting to home',
          );
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Auth state: isAuthenticated=$isAuthenticated, servicesLoaded=$areServicesLoaded',
          );
          debugPrint(
            '[Router] Reason: Authenticated users should not be on login page',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: AUTHENTICATED -> HOME =====',
          );
          return '/';
        }

        // For desktop, require authentication (web auth handled in route builder)
        if (!kIsWeb && !isAuthenticated && !isAuthLoading) {
          debugPrint(
            '[Router] DECISION: Redirecting desktop to login - user not authenticated',
          );
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Reason: Desktop platform requires authentication',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: DESKTOP -> LOGIN =====',
          );
          return '/login';
        }

        // Check admin-center route access
        final isAdminCenter = state.matchedLocation == '/admin-center';
        if (isAdminCenter) {
          // Require authentication for admin center
          if (!isAuthenticated) {
            debugPrint(
              '[Router] DECISION: Redirecting to login - admin center requires authentication',
            );
            debugPrint('[Router] Current route: ${state.matchedLocation}');
            debugPrint(
              '[Router] Reason: Admin center requires authenticated user',
            );
            debugPrint(
              '[Router] ===== REDIRECT DECISION: ADMIN CENTER -> LOGIN =====',
            );
            return '/login';
          }

          // Admin authorization check is handled by AdminCenterScreen itself
          // This allows for proper error messaging and user experience
          debugPrint(
            '[Router] DECISION: Allowing access to admin center (authorization checked by screen)',
          );
          debugPrint('[Router] Current route: ${state.matchedLocation}');
          debugPrint(
            '[Router] Reason: User authenticated, admin authorization will be checked by screen',
          );
          debugPrint(
            '[Router] ===== REDIRECT DECISION: ALLOW ADMIN CENTER =====',
          );
          return null;
        }

        // Allow access to protected routes
        debugPrint('[Router] DECISION: Allowing access to protected route');
        debugPrint('[Router] Route: ${state.matchedLocation}');
        debugPrint(
          '[Router] Auth state: isAuthenticated=$isAuthenticated, servicesLoaded=$areServicesLoaded',
        );
        debugPrint('[Router] Reason: Protected route access granted');
        debugPrint(
          '[Router] ===== REDIRECT DECISION: ALLOW PROTECTED ROUTE =====',
        );
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

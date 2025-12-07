import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/callback_screen.dart';
// Ollama test screen is lazy-loaded

// No web-specific imports needed - using platform-safe approach

// Settings screens are lazy-loaded
import '../screens/settings/settings_lazy.dart' as settings_lazy;

// Admin screens are lazy-loaded
import '../screens/admin/admin_lazy.dart' as admin_lazy;
import '../screens/ollama_test_lazy.dart' as ollama_test_lazy;

// Marketing screens (web-only) are lazy-loaded
import '../screens/marketing/marketing_lazy.dart' as marketing_lazy;

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
  final isApp = hostname.startsWith('app.') ||
      hostname == 'app.cloudtolocalllm.online' ||
      hostname == 'localhost' ||
      hostname == '127.0.0.1';

  debugPrint('[Router] Hostname: $hostname, isApp: $isApp');
  return isApp;
}

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    required AuthService authService,
  }) {
    print('[Router] createRouter called');
    // Store authService for use in route builders
    final authServiceRef = authService;
    // For web, get the full URL including query parameters to preserve callback data
    // This ensures callback parameters are available to the router
    String initialLocation;
    if (kIsWeb) {
      try {
        print('[Router] Web detected, getting Uri.base');
        // Use Uri.base to get the full current URL with query parameters
        final currentUri = Uri.base;
        print('[Router] Uri.base: $currentUri');

        // Check for auth callback parameters
        // If present, force initial location to /callback to ensure processing
        // This bypasses the redirect logic which might fail on initial load
        if (currentUri.queryParameters.containsKey('code') ||
            currentUri.queryParameters.containsKey('error_description')) {
          print('[Router] Detected auth callback parameters in initial URL');
          initialLocation = '/callback';
          if (currentUri.hasQuery) {
            initialLocation += '?${currentUri.query}';
          }
        } else {
          initialLocation = currentUri.path;
          if (currentUri.hasQuery) {
            initialLocation += '?${currentUri.query}';
          }
        }
        print(
          '[Router] Initial location with query params: $initialLocation',
        );
      } catch (e) {
        print('[Router] Error getting current URI: $e');
        initialLocation = '/';
      }
    } else {
      initialLocation = '/';
    }

    print('[Router] Initializing GoRouter...');
    try {
      final router = GoRouter(
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
              print('[Router] ===== NEW HOME ROUTE BUILDER START =====');

              // FAILSAFE: Check for callback parameters directly in the builder
              // This handles cases where redirect logic fails to move us to /callback
              if (kIsWeb) {
                final uri = state.uri;
                final hasStateParams =
                    uri.queryParameters.containsKey('code') ||
                        uri.queryParameters.containsKey('error_description');
                final baseUri = Uri.base;
                final hasBaseParams = baseUri.queryParameters
                        .containsKey('code') ||
                    baseUri.queryParameters.containsKey('error_description');

                if (hasStateParams || hasBaseParams) {
                  print(
                      '[Router] FAILSAFE: Detected callback params in home builder - rendering CallbackScreen');
                  final params = hasStateParams
                      ? uri.queryParameters
                      : baseUri.queryParameters;
                  return CallbackScreen(queryParams: params);
                }
              }

              // Check if user is already authenticated
              bool isAlreadyAuthenticated = false;

              if (kIsWeb) {
                try {
                  // Check if user is authenticated via Supabase
                  print('[Router] Checking authentication status...');
                  isAlreadyAuthenticated = authServiceRef.isAuthenticated.value;
                  print(
                    '[Router] isAuthenticated: $isAlreadyAuthenticated',
                  );
                } catch (e) {
                  print('[Router] Error checking auth status: $e');
                  print('[Router] Error stack: ${e.toString()}');
                }
              }

              print(
                '[Router] isAlreadyAuthenticated: $isAlreadyAuthenticated',
              );

              // Decision tree for routing:
              // 1. If already authenticated -> show main app
              // 2. Otherwise -> show login screen

              if (isAlreadyAuthenticated) {
                print(
                  '[Router] User already authenticated, showing main app',
                );
                // HomeScreen handles loading state internally
                print('[Router] Showing home screen for authenticated user');
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
                  print(
                    '[Router] Route builder called - isLoading: $isAuthLoading, isAuthenticated: $isAuthenticated',
                  );

                  // If authentication is still loading, show loading screen
                  if (isAuthenticated) {
                    print('[Router] Showing home screen');
                    return const HomeScreen();
                  } else {
                    print('[Router] Showing login screen');
                    return const LoginScreen();
                  }
                } else {
                  // Root domain - show marketing homepage (lazy loaded)
                  // No longer deferred
                  return const marketing_lazy.HomepageScreen();
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
              return const HomeScreen();
            },
          ),

          // Marketing routes (formerly lazy-loaded)
          ...marketing_lazy.marketingRoutes,

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
                print(
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
              print(
                '[Router] Building CallbackScreen with query params: $callbackParams',
              );
              return CallbackScreen(queryParams: callbackParams);
            },
          ),

          // Ollama test routes (formerly lazy-loaded)
          ...ollama_test_lazy.ollamaTestRoutes,

          // Settings routes (formerly lazy-loaded)
          ...settings_lazy.settingsRoutes,

          // Admin routes (formerly lazy-loaded)
          ...admin_lazy.adminRoutes,
        ],

        // Redirect logic for authentication and domain-based routing
        redirect: (context, state) {
          print('[Router] ===== REDIRECT FUNCTION CALLED =====');
          print('[Router] Matched location: ${state.matchedLocation}');
          print('[Router] Full path: ${state.fullPath}');
          print('[Router] URI: ${state.uri}');
          final isAuthenticated = authService.isAuthenticated.value;
          final isAuthLoading = authService.isLoading.value;
          final areServicesLoaded =
              authService.areAuthenticatedServicesLoaded.value;
          print(
            '[Router] Auth state: isAuthenticated=$isAuthenticated, isLoading=$isAuthLoading, servicesLoaded=$areServicesLoaded',
          );
          print('[Router] State URI: ${state.uri}');
          print('[Router] Base URI: ${Uri.base}');
          final isLoggingIn = state.matchedLocation == '/login';
          final isCallback = state.matchedLocation == '/callback';
          final isHomepage = state.matchedLocation == '/';
          final isDownload = state.matchedLocation == '/download' && kIsWeb;
          final isDocs = state.matchedLocation == '/docs' && kIsWeb;

          // Check for callback parameters in URL (code and state)
          // Supabase might use hash fragment or query params depending on config
          final stateUri = state.uri;

          // Debug logging for callback detection
          print('[Router] ===== CALLBACK PARAMETER DETECTION START =====');
          print('[Router] stateUri: ${stateUri.toString()}');
          print(
            '[Router] stateUri.queryParameters: ${stateUri.queryParameters}',
          );

          // Determine if we have callback parameters
          // Check both state.uri and Uri.base (fallback) to ensure we catch them on initial load
          final hasStateParams = stateUri.queryParameters.containsKey('code') ||
              stateUri.queryParameters.containsKey('error_description');

          // On web, also check the browser's current URL directly
          // This is necessary because sometimes GoRouter state doesn't reflect the full URL on initial load
          final baseUri = Uri.base;
          final hasBaseParams = baseUri.queryParameters.containsKey('code') ||
              baseUri.queryParameters.containsKey('error_description');

          final rawHasCallbackParams =
              hasStateParams || (kIsWeb && hasBaseParams);

          print(
            '[Router] rawHasCallbackParams: $rawHasCallbackParams (state: $hasStateParams, base: $hasBaseParams)',
          );
          print('[Router] ===== CALLBACK PARAMETER DETECTION END =====');

          // Use robust hostname detection
          final isAppSubdomain = _isAppSubdomain();

          print('[Router] ===== REDIRECT DECISION LOGIC START =====');
          print('[Router] Current route: ${state.matchedLocation}');
          print('[Router] Full URI: ${stateUri.toString()}');
          print(
            '[Router] Auth state: isAuthenticated=$isAuthenticated, isAuthLoading=$isAuthLoading',
          );
          print(
            '[Router] Platform state: kIsWeb=$kIsWeb, isAppSubdomain=$isAppSubdomain',
          );
          print(
            '[Router] Route flags: isLoggingIn=$isLoggingIn, isCallback=$isCallback, isHomepage=$isHomepage',
          );

          // If we have callback parameters but we're not on /callback route, redirect there
          if (rawHasCallbackParams && !isCallback && kIsWeb) {
            print(
              '[Router] DECISION: Detected callback parameters, redirecting to /callback',
            );

            // Preserve query parameters when redirecting to callback
            // Use state params if available, otherwise fall back to base params
            final paramsToUse = hasStateParams
                ? stateUri.queryParameters
                : baseUri.queryParameters;

            final callbackUri = Uri(
              path: '/callback',
              queryParameters: paramsToUse,
            );
            print(
              '[Router] Redirecting from ${state.matchedLocation} to: ${callbackUri.toString()}',
            );
            print(
              '[Router] ===== REDIRECT DECISION: FORWARD TO /callback =====',
            );
            return callbackUri.toString();
          }

          // If we're on the callback route with callback parameters, allow processing
          if (isCallback && rawHasCallbackParams && kIsWeb) {
            print(
              '[Router] DECISION: On /callback route with callback parameters present',
            );
            return null;
          }

          // Allow access to marketing pages on web root domain without authentication
          if (kIsWeb &&
              !isAppSubdomain &&
              (isHomepage || isDownload || isDocs)) {
            print(
              '[Router] DECISION: Allowing access to marketing page (root domain)',
            );
            print('[Router] Route: ${state.matchedLocation}');
            print(
              '[Router] Reason: Marketing page on root domain, no auth required',
            );
            print(
              '[Router] ===== REDIRECT DECISION: ALLOW MARKETING PAGE =====',
            );
            return null;
          }

          // If authentication is still loading, defer redirect decisions
          if (isAuthLoading && !isCallback) {
            print(
              '[Router] DECISION: Auth still loading - deferring redirect',
            );
            print('[Router] Current route: ${state.matchedLocation}');
            print(
              '[Router] Reason: Waiting for authentication state to be determined',
            );
            print(
              '[Router] ===== REDIRECT DECISION: DEFER (AUTH LOADING) =====',
            );
            return null; // Stay on current route until auth loading completes
          }

          // Allow access to login and loading pages
          if (isLoggingIn) {
            // On web main domain, redirect /login to / (marketing homepage)
            if (isLoggingIn && kIsWeb && !isAppSubdomain) {
              print(
                  '[Router] DECISION: Redirecting /login to / on main domain');
              return '/';
            }

            print('[Router] DECISION: Allowing access to auth/loading page');
            print('[Router] Route: ${state.matchedLocation}');
            print('[Router] Auth state: isAuthenticated=$isAuthenticated');
            print('[Router] Reason: Login or loading page access allowed');
            print(
              '[Router] ===== REDIRECT DECISION: ALLOW AUTH/LOADING PAGE =====',
            );
            return null;
          }

          // For callback route, handle platform-specific logic
          if (isCallback) {
            if (kIsWeb) {
              print(
                '[Router] DECISION: Allowing access to callback page (web)',
              );
              print('[Router] Query params: ${state.uri.queryParameters}');
              print('[Router] Reason: Web platform callback processing');
              print(
                '[Router] ===== REDIRECT DECISION: ALLOW CALLBACK PAGE =====',
              );
              return null;
            } else {
              // Desktop platforms should not use callback route
              print(
                '[Router] DECISION: Desktop callback route accessed - redirecting based on auth state',
              );
              print('[Router] Auth state: isAuthenticated=$isAuthenticated');
              if (isAuthenticated) {
                print(
                  '[Router] Reason: Desktop authenticated, redirecting to home',
                );
                print(
                  '[Router] ===== REDIRECT DECISION: DESKTOP CALLBACK -> HOME =====',
                );
                return '/';
              } else {
                print(
                  '[Router] Reason: Desktop not authenticated, redirecting to login',
                );
                print(
                  '[Router] ===== REDIRECT DECISION: DESKTOP CALLBACK -> LOGIN =====',
                );
                return '/login';
              }
            }
          }

          // If authenticated but services not yet loaded, we allow HomeScreen to handle it
          // Logic removed to prevent redirect loop to /loading

          // NEVER redirect to login when authentication state is true
          // This prevents the login loop after successful authentication
          if (isAuthenticated && isLoggingIn) {
            print(
              '[Router] DECISION: Authenticated user on login page - redirecting to home',
            );
            print('[Router] Current route: ${state.matchedLocation}');
            print(
              '[Router] Auth state: isAuthenticated=$isAuthenticated, servicesLoaded=$areServicesLoaded',
            );
            print(
              '[Router] Reason: Authenticated users should not be on login page',
            );
            print(
              '[Router] ===== REDIRECT DECISION: AUTHENTICATED -> HOME =====',
            );
            return '/';
          }

          // For desktop, require authentication (web auth handled in route builder)
          if (!kIsWeb && !isAuthenticated && !isAuthLoading) {
            print(
              '[Router] DECISION: Redirecting desktop to login - user not authenticated',
            );
            print('[Router] Current route: ${state.matchedLocation}');
            print(
              '[Router] Reason: Desktop platform requires authentication',
            );
            print(
              '[Router] ===== REDIRECT DECISION: DESKTOP -> LOGIN =====',
            );
            return '/login';
          }

          // Check admin-center route access
          final isAdminCenter = state.matchedLocation == '/admin-center';
          if (isAdminCenter) {
            // Require authentication for admin center
            if (!isAuthenticated) {
              print(
                '[Router] DECISION: Redirecting to login - admin center requires authentication',
              );
              print('[Router] Current route: ${state.matchedLocation}');
              print(
                '[Router] Reason: Admin center requires authenticated user',
              );
              print(
                '[Router] ===== REDIRECT DECISION: ADMIN CENTER -> LOGIN =====',
              );
              return '/login';
            }

            // Admin authorization check is handled by AdminCenterScreen itself
            // This allows for proper error messaging and user experience
            print(
              '[Router] DECISION: Allowing access to admin center (authorization checked by screen)',
            );
            print('[Router] Current route: ${state.matchedLocation}');
            print(
              '[Router] Reason: User authenticated, admin authorization will be checked by screen',
            );
            print(
              '[Router] ===== REDIRECT DECISION: ALLOW ADMIN CENTER =====',
            );
            return null;
          }

          // Allow access to protected routes (access control handled in route builders)
          print(
              '[Router] DECISION: Pass-through to route builder (access control handled in builder)');
          print('[Router] Route: ${state.matchedLocation}');
          print(
            '[Router] Auth state: isAuthenticated=$isAuthenticated, servicesLoaded=$areServicesLoaded',
          );
          print('[Router] Reason: Route builder defines access logic');
          print(
            '[Router] ===== REDIRECT DECISION: PASS-THROUGH =====',
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
      print('[Router] GoRouter initialized successfully');
      return router;
    } catch (e, stack) {
      print('[Router] Error initializing GoRouter: $e');
      print('[Router] Stack: $stack');
      rethrow;
    }
  }
}

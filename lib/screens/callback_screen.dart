import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';
import '../services/auth_service.dart';
import '../screens/loading_screen.dart';

// Callback forwarding flag key - must match router.dart
const _callbackForwardedKey = 'auth0_callback_forwarded';

/// Auth0 callback screen that processes authentication results
class CallbackScreen extends StatefulWidget {
  const CallbackScreen({super.key, this.queryParams = const {}});

  final Map<String, String> queryParams;

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint(' [CallbackScreen] initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(' [CallbackScreen] postFrameCallback triggered');
      _processCallback();
    });
  }

  /// Wait for authentication state to become true with timeout and retry logic
  /// Returns true if authentication state becomes true, false otherwise
  Future<bool> _waitForAuthenticationState(
    AuthService authService, {
    int maxAttempts = 3,
    Duration attemptTimeout = const Duration(seconds: 5),
  }) async {
    debugPrint(
      '[CallbackScreen] Waiting for authentication state (max $maxAttempts attempts)...',
    );
    debugPrint(
      '[CallbackScreen] Current auth state before wait: ${authService.isAuthenticated.value}',
    );

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint(
        '[CallbackScreen] Auth state check attempt $attempt/$maxAttempts',
      );

      // Wait for auth state to become true or timeout
      final startTime = DateTime.now();
      while (DateTime.now().difference(startTime) < attemptTimeout) {
        final currentAuthState = authService.isAuthenticated.value;
        if (currentAuthState) {
          final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
          debugPrint(
            '[CallbackScreen] SUCCESS: Authentication state changed to true after ${elapsedMs}ms',
          );
          debugPrint('[CallbackScreen] Auth state before: false, after: true');
          return true;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final currentAuthState = authService.isAuthenticated.value;
      debugPrint(
        '[CallbackScreen] Attempt $attempt timed out after ${attemptTimeout.inSeconds}s',
      );
      debugPrint('[CallbackScreen] Auth state: $currentAuthState');

      // If not the last attempt, wait a bit before retrying
      if (attempt < maxAttempts) {
        debugPrint('[CallbackScreen] Waiting 500ms before retry...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    debugPrint(
      '[CallbackScreen] FAILED: Authentication state not verified after $maxAttempts attempts',
    );
    debugPrint(
      '[CallbackScreen] Final auth state: ${authService.isAuthenticated.value}',
    );
    return false;
  }

  /// Clear the callback forwarded flag from sessionStorage
  void _clearCallbackForwardedFlag() {
    if (kIsWeb) {
      try {
        window.sessionStorage.removeItem(_callbackForwardedKey);
        debugPrint(
          '[CallbackScreen] Cleared callback forwarded flag from sessionStorage',
        );
      } catch (e) {
        debugPrint(
          '[CallbackScreen] Error clearing callback forwarded flag: $e',
        );
      }
    }
  }

  /// Clear callback parameters from URL
  void _clearCallbackParametersFromUrl() {
    if (kIsWeb) {
      try {
        final currentUrl = window.location.href;
        final uri = Uri.parse(currentUrl);

        // Remove callback parameters (code, state, error, error_description)
        final cleanParams = Map<String, String>.from(uri.queryParameters)
          ..remove('code')
          ..remove('state')
          ..remove('error')
          ..remove('error_description');

        // Build clean URL
        final cleanUri = uri.replace(
          queryParameters: cleanParams.isEmpty ? null : cleanParams,
        );

        debugPrint('[CallbackScreen] Clearing callback parameters from URL');
        window.history.replaceState(null, document.title, cleanUri.toString());
      } catch (e) {
        debugPrint('[CallbackScreen] Error clearing callback parameters: $e');
      }
    }
  }

  /// Categorize error and return user-friendly message
  Map<String, String> _categorizeError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('session persistence') ||
        errorString.contains('database') ||
        errorString.contains('postgresql')) {
      return {
        'type': 'session_persistence_failed',
        'message':
            'Authentication failed: Unable to create session. Please check your connection and try again.',
      };
    } else if (errorString.contains('auth0 client not initialized') ||
        errorString.contains('client initialization failed') ||
        errorString.contains('bridge not available')) {
      return {
        'type': 'auth0_client_not_ready',
        'message':
            'Authentication failed: Service not ready. Please refresh the page and try again.',
      };
    } else if (errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return {
        'type': 'timeout',
        'message':
            'Authentication failed: Request timed out. Please check your connection and try again.',
      };
    } else if (errorString.contains('invalid_grant') ||
        errorString.contains('expired')) {
      return {
        'type': 'invalid_grant',
        'message':
            'Authentication failed: Authorization code expired. Please try logging in again.',
      };
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return {
        'type': 'network_error',
        'message':
            'Authentication failed: Network error. Please check your connection and try again.',
      };
    } else {
      return {
        'type': 'unexpected_error',
        'message':
            'Authentication failed: An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Verify that authenticated services are loaded
  /// Returns true if services are loaded or if we should proceed anyway
  bool _verifyAuthenticatedServicesLoaded(AuthService authService) {
    // For now, we'll assume services are loaded if auth state is true
    // In the future, we could add a specific flag in AuthService to track this
    final servicesLoaded = authService.isAuthenticated.value;
    debugPrint(
      '[CallbackScreen] Authenticated services loaded: $servicesLoaded',
    );
    return servicesLoaded;
  }

  Future<void> _processCallback() async {
    try {
      debugPrint('[CallbackScreen] ===== CALLBACK PROCESSING START =====');
      debugPrint('[CallbackScreen] _processCallback started');
      final authService = context.read<AuthService>();
      debugPrint('[CallbackScreen] AuthService obtained from context');
      debugPrint(
        '[CallbackScreen] Initial auth state: ${authService.isAuthenticated.value}',
      );

      // For desktop platforms, the callback route should not be used
      // Desktop authentication is handled internally by the auth service
      if (!kIsWeb) {
        debugPrint(
          '[CallbackScreen] Desktop platform detected - callback route not needed',
        );
        debugPrint(
          '[CallbackScreen] Checking current authentication state and redirecting',
        );
        debugPrint(
          '[CallbackScreen] Auth state: ${authService.isAuthenticated.value}',
        );

        if (mounted) {
          if (authService.isAuthenticated.value) {
            debugPrint(
              '[CallbackScreen] User already authenticated, redirecting to home',
            );
            context.go('/');
          } else {
            debugPrint(
              '[CallbackScreen] User not authenticated, redirecting to login',
            );
            context.go('/login');
          }
        }
        return;
      }

      // Check if user is already authenticated - if so, just redirect to home
      if (authService.isAuthenticated.value) {
        debugPrint(
          '[CallbackScreen] User already authenticated, skipping callback processing',
        );
        debugPrint('[CallbackScreen] Redirecting to home');
        if (mounted) {
          context.go('/');
        }
        return;
      }

      final routeParams = widget.queryParams;
      final hasRouteCallbackParams = routeParams.containsKey('code') ||
          routeParams.containsKey('state') ||
          routeParams.containsKey('error');

      debugPrint('[CallbackScreen] Route params: $routeParams');
      debugPrint(
        '[CallbackScreen] Has callback params: $hasRouteCallbackParams',
      );

      // Check if this is a callback URL using either the route params or Auth0 service
      final isCallbackUrl =
          hasRouteCallbackParams || authService.auth0Service.isCallbackUrl();
      debugPrint(
        '[CallbackScreen] Is callback URL: $isCallbackUrl (route params present: $hasRouteCallbackParams)',
      );

      if (!isCallbackUrl) {
        debugPrint('[CallbackScreen] Not a callback URL, redirecting to login');
        debugPrint('[CallbackScreen] Reason: No callback parameters found');
        _clearCallbackForwardedFlag();
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Web platform - process the callback normally
      debugPrint('[CallbackScreen] Web platform - processing callback');
      debugPrint(
        '[CallbackScreen] Auth state before callback: ${authService.isAuthenticated.value}',
      );

      String? originalUrl;
      if (kIsWeb && routeParams.isNotEmpty) {
        final queryString = Uri(queryParameters: routeParams).query;
        final newHref =
            '${window.location.origin}${window.location.pathname}?$queryString';
        originalUrl = window.location.href;
        debugPrint(
          '[CallbackScreen] Temporarily updating URL for callback processing',
        );
        window.history.replaceState(null, document.title, newHref);
      }

      debugPrint('[CallbackScreen] Calling authService.handleCallback()...');
      final success = await authService.handleCallback();

      if (originalUrl != null) {
        debugPrint('[CallbackScreen] Restoring original URL');
        window.history.replaceState(null, document.title, originalUrl);
      }

      debugPrint('[CallbackScreen] handleCallback returned: $success');
      debugPrint(
        '[CallbackScreen] Auth state immediately after callback: ${authService.isAuthenticated.value}',
      );

      if (mounted) {
        if (success) {
          // Wait for authentication state to be properly set and session persisted
          // This replaces the arbitrary 300ms delay with proper state verification
          debugPrint(
            '[CallbackScreen] Callback successful, waiting for session persistence...',
          );

          final authStateVerified = await _waitForAuthenticationState(
            authService,
            maxAttempts: 10, // Increased to 10 to allow for slower session creation/timeouts (50s total)
            attemptTimeout: const Duration(seconds: 5),
          );

          if (!mounted) return;

          if (authStateVerified) {
            debugPrint(
              '[CallbackScreen] Authentication state verified successfully',
            );

            // Verify authenticated services are loaded
            final servicesLoaded = _verifyAuthenticatedServicesLoaded(
              authService,
            );

            if (servicesLoaded) {
              debugPrint(
                '[CallbackScreen] SUCCESS: Authentication and services verified',
              );
              debugPrint('[CallbackScreen] Redirecting to home');

              // Clear the callback forwarded flag now that processing is complete
              _clearCallbackForwardedFlag();

              // Use pushReplacement to clear the callback URL from history
              debugPrint(
                '[CallbackScreen] ===== CALLBACK PROCESSING COMPLETE =====',
              );
              context.pushReplacement('/');
            } else {
              debugPrint(
                '[CallbackScreen] ERROR: Authenticated services not loaded after successful auth',
              );
              _clearCallbackForwardedFlag();
              _clearCallbackParametersFromUrl();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Authentication succeeded but services failed to load. Please try again.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                debugPrint(
                  '[CallbackScreen] Redirecting to login due to service load failure',
                );
                context.go('/login?login_error=services_load_failed');
              }
            }
          } else {
            debugPrint(
              '[CallbackScreen] ERROR: Authentication state not verified after callback success',
            );
            debugPrint(
              '[CallbackScreen] Reason: Auth state did not become true within timeout',
            );
            _clearCallbackForwardedFlag();
            _clearCallbackParametersFromUrl();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Authentication timed out. Session may not have been created. Please try again.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              debugPrint(
                '[CallbackScreen] Redirecting to login due to auth state timeout',
              );
              context.go('/login?login_error=auth_state_timeout');
            }
          }
        } else {
          debugPrint('[CallbackScreen] ERROR: Authentication callback failed');
          debugPrint(
            '[CallbackScreen] Reason: authService.handleCallback() returned false',
          );
          _clearCallbackForwardedFlag();
          _clearCallbackParametersFromUrl();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Authentication failed. Please try logging in again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            debugPrint(
              '[CallbackScreen] Redirecting to login due to callback failure',
            );
            context.go('/login?login_error=callback_failed');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[CallbackScreen] ERROR: Processing exception: $e');
      debugPrint('[CallbackScreen] Stack trace: $stackTrace');

      // Clear callback parameters and flags on error
      _clearCallbackForwardedFlag();
      _clearCallbackParametersFromUrl();

      if (mounted) {
        // Show comprehensive error message based on error type
        final errorInfo = _categorizeError(e);
        debugPrint('[CallbackScreen] Error type: ${errorInfo['type']}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorInfo['message']!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        debugPrint('[CallbackScreen] Redirecting to login due to exception');
        debugPrint('[CallbackScreen] ===== CALLBACK PROCESSING FAILED =====');

        // Redirect to login with error parameter (using login_error to avoid triggering callback detection loop)
        context.go(
            '/login?login_error=${Uri.encodeComponent(errorInfo['type']!)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen(message: 'Processing authentication...');
  }
}

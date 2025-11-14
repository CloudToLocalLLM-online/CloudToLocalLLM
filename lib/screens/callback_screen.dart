import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/loading_screen.dart';

/// Auth0 callback screen that processes authentication results
class CallbackScreen extends StatefulWidget {
  const CallbackScreen({
    super.key,
    this.queryParams = const {},
  });

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

  Future<void> _processCallback() async {
    try {
      debugPrint(' [CallbackScreen] _processCallback started');
      final authService = context.read<AuthService>();
      debugPrint(' [CallbackScreen] AuthService obtained from context');

      // For desktop platforms, the callback route should not be used
      // Desktop authentication is handled internally by the auth service
      if (!kIsWeb) {
        debugPrint(
          ' [Callback] Desktop platform detected - callback route not needed',
        );
        debugPrint(
          ' [Callback] Checking current authentication state and redirecting',
        );

        if (mounted) {
          if (authService.isAuthenticated.value) {
            debugPrint(
              ' [Callback] User already authenticated, redirecting to home',
            );
            context.go('/');
          } else {
            debugPrint(
              ' [Callback] User not authenticated, redirecting to login',
            );
            context.go('/login');
          }
        }
        return;
      }

      // Check if user is already authenticated - if so, just redirect to home
      if (authService.isAuthenticated.value) {
        debugPrint(
          ' [Callback] User already authenticated, redirecting to home',
        );
        if (mounted) {
          context.go('/');
        }
        return;
      }

      final routeParams = widget.queryParams;
      final hasRouteCallbackParams = routeParams.containsKey('code') ||
          routeParams.containsKey('state') ||
          routeParams.containsKey('error');

      // Check if this is a callback URL using either the route params or Auth0 service
      final isCallbackUrl =
          hasRouteCallbackParams || authService.auth0Service.isCallbackUrl();
      debugPrint(
        ' [Callback] Is callback URL: $isCallbackUrl (route params present: $hasRouteCallbackParams)',
      );

      if (!isCallbackUrl) {
        debugPrint(
          ' [Callback] Not a callback URL, redirecting to login',
        );
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Web platform - process the callback normally
      debugPrint(
        ' [CallbackScreen] Auth state before callback: ${authService.isAuthenticated.value}',
      );
      final success = await authService.handleCallback();
      debugPrint(' [CallbackScreen] handleCallback returned: $success');
      debugPrint(
        ' [CallbackScreen] Auth state after callback: ${authService.isAuthenticated.value}',
      );

      if (mounted) {
        if (success) {
          // Wait for authentication state to be properly set and propagated
          // This prevents race conditions with the router redirect logic
          await Future.delayed(const Duration(milliseconds: 300));

          // Double-check authentication state after delay and ensure context is still mounted
          if (mounted) {
            if (authService.isAuthenticated.value) {
              debugPrint(
                ' [Callback] Authentication successful, redirecting to home',
              );
              // Use pushReplacement to clear the callback URL from history
              context.pushReplacement('/');
            } else {
              debugPrint(
                ' [Callback] Authentication state not set after success, redirecting to login',
              );
              context.go('/login');
            }
          }
        } else {
          debugPrint(
            ' [Callback] Authentication failed, redirecting to login',
          );
          // Redirect to login page on failure
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint(' [Callback] Processing error: $e');
      if (mounted) {
        // Show error and redirect to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen(message: 'Processing authentication...');
  }
}

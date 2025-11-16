import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../di/locator.dart' as di;

/// Lightweight placeholder for the unified settings experience while the
/// redesigned implementation is being completed.
class UnifiedSettingsScreen extends StatelessWidget {
  final String? initialSection;

  const UnifiedSettingsScreen({super.key, this.initialSection});

  /// Check if the current user has admin privileges
  bool _isAdminUser() {
    try {
      final authService = di.serviceLocator.get<AuthService>();
      final userEmail = authService.currentUser?.email;

      // Check if user email matches the authorized admin email
      return userEmail == 'cmaltais@cloudtolocalllm.online';
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error checking admin status: $e');
      return false;
    }
  }

  /// Open the Admin Center in a new tab
  void _openAdminCenter(BuildContext context) {
    if (kIsWeb) {
      // For web, open in new tab using go_router
      context.go('/admin-center');
    } else {
      // For desktop, navigate to admin center route
      context.push('/admin-center');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdminUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.tune, size: 56, color: Color(0xFF6e8efb)),
              const SizedBox(height: 16),
              Text(
                'Settings Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We are wrapping up the revamped settings experience to match '
                'the new chat interface. In the meantime, you can manage '
                'critical configuration from the desktop application.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Admin Center button (only visible to admin users)
              if (isAdmin) ...[
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF6e8efb),
                    ),
                    title: const Text(
                      'Admin Center',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        const Text('Manage users, payments, and subscriptions'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openAdminCenter(context),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (kIsWeb)
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Return to Home'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

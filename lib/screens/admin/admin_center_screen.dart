import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';
import '../../di/locator.dart' as di;
import 'dashboard_tab.dart';
import 'user_management_tab.dart';
import 'payment_management_tab.dart';
import 'subscription_management_tab.dart';
import 'financial_reports_tab.dart';
import 'audit_log_viewer_tab.dart';
import 'admin_management_tab.dart';
import 'email_provider_config_tab.dart';
import 'email_metrics_tab.dart';
import 'dns_config_tab.dart';

/// Admin Center main screen for managing users, payments, and subscriptions.
/// This is separate from the AdminPanelScreen which handles system administration
/// (Docker containers, system stats). The Admin Center focuses on user/payment management.
class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

/// Navigation item for the sidebar
class _NavigationItem {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
  final List<AdminPermission> requiredPermissions;

  const _NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.requiredPermissions = const [],
  });
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  bool _isCheckingAuth = true;
  bool _isAuthorized = false;
  String? _errorMessage;
  String _selectedTabId = 'dashboard';
  late AdminCenterService _adminService;

  // Define all navigation items
  late final List<_NavigationItem> _allNavigationItems;

  @override
  void initState() {
    super.initState();
    _adminService = di.serviceLocator.get<AdminCenterService>();
    _initializeNavigationItems();
    _checkAdminAuthorization();
  }

  /// Initialize navigation items with their permissions
  void _initializeNavigationItems() {
    _allNavigationItems = [
      _NavigationItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard,
        builder: () => const DashboardTab(),
        requiredPermissions: [], // All admins can view dashboard
      ),
      _NavigationItem(
        id: 'users',
        label: 'User Management',
        icon: Icons.people,
        builder: () => const UserManagementTab(),
        requiredPermissions: [AdminPermission.viewUsers],
      ),
      _NavigationItem(
        id: 'payments',
        label: 'Payment Management',
        icon: Icons.payment,
        builder: () => const PaymentManagementTab(),
        requiredPermissions: [AdminPermission.viewPayments],
      ),
      _NavigationItem(
        id: 'subscriptions',
        label: 'Subscription Management',
        icon: Icons.subscriptions,
        builder: () => const SubscriptionManagementTab(),
        requiredPermissions: [AdminPermission.viewSubscriptions],
      ),
      _NavigationItem(
        id: 'reports',
        label: 'Financial Reports',
        icon: Icons.bar_chart,
        builder: () => const FinancialReportsTab(),
        requiredPermissions: [AdminPermission.viewReports],
      ),
      _NavigationItem(
        id: 'audit',
        label: 'Audit Logs',
        icon: Icons.history,
        builder: () => const AuditLogViewerTab(),
        requiredPermissions: [AdminPermission.viewAuditLogs],
      ),
      _NavigationItem(
        id: 'admins',
        label: 'Admin Management',
        icon: Icons.admin_panel_settings,
        builder: () => const AdminManagementTab(),
        requiredPermissions: [AdminPermission.viewAdmins],
      ),
      _NavigationItem(
        id: 'email',
        label: 'Email Provider',
        icon: Icons.email,
        builder: () => const EmailProviderConfigTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
      _NavigationItem(
        id: 'email-metrics',
        label: 'Email Metrics',
        icon: Icons.analytics,
        builder: () => const EmailMetricsTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
      _NavigationItem(
        id: 'dns',
        label: 'DNS Configuration',
        icon: Icons.dns,
        builder: () => const DnsConfigTab(),
        requiredPermissions: [AdminPermission.viewConfiguration],
      ),
    ];
  }

  /// Get filtered navigation items based on user permissions
  List<_NavigationItem> get _visibleNavigationItems {
    return _allNavigationItems.where((item) {
      // If no permissions required, show to all admins
      if (item.requiredPermissions.isEmpty) return true;

      // Check if user has any of the required permissions
      return item.requiredPermissions
          .any((permission) => _adminService.hasPermission(permission));
    }).toList();
  }

  /// Check if the current user has admin privileges
  Future<void> _checkAdminAuthorization() async {
    try {
      final authService = di.serviceLocator.get<AuthService>();
      final userEmail = authService.currentUser?.email;

      debugPrint(
          '[AdminCenterScreen] Checking admin authorization for: $userEmail');

      // Check if user email matches the authorized admin email
      // In the future, this will check against the admin_roles table in the database
      final isAuthorized = userEmail == 'cmaltais@cloudtolocalllm.online';

      if (isAuthorized) {
        // Initialize admin service to load roles
        await _adminService.initialize();
      }

      setState(() {
        _isAuthorized = isAuthorized;
        _isCheckingAuth = false;
        if (!isAuthorized) {
          _errorMessage =
              'You do not have permission to access the Admin Center.';
        }
      });

      debugPrint(
          '[AdminCenterScreen] Authorization check complete: $isAuthorized');
    } catch (e) {
      debugPrint('[AdminCenterScreen] Error checking admin authorization: $e');
      setState(() {
        _isCheckingAuth = false;
        _isAuthorized = false;
        _errorMessage = 'Error checking admin permissions: $e';
      });
    }
  }

  /// Handle tab selection
  void _onTabSelected(String tabId) {
    setState(() {
      _selectedTabId = tabId;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking authorization
    if (_isCheckingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Center'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying admin permissions...'),
            ],
          ),
        ),
      );
    }

    // Show error message if not authorized
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Center'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ??
                      'You do not have permission to access this page.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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

    // Get visible navigation items based on permissions
    final visibleItems = _visibleNavigationItems;
    final selectedItem = visibleItems.firstWhere(
      (item) => item.id == _selectedTabId,
      orElse: () => visibleItems.first,
    );

    // Show Admin Center interface with sidebar navigation
    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation
          _buildSidebar(context, visibleItems),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(context, selectedItem),

                // Content
                Expanded(
                  child: selectedItem.builder(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the sidebar navigation
  Widget _buildSidebar(
      BuildContext context, List<_NavigationItem> visibleItems) {
    final theme = Theme.of(context);
    final authService = di.serviceLocator.get<AuthService>();
    final userEmail = authService.currentUser?.email ?? 'Admin';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin Center header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Admin Center',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  userEmail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isSelected = item.id == _selectedTabId;

                return _buildNavigationItem(
                  context,
                  item: item,
                  isSelected: isSelected,
                  onTap: () => _onTabSelected(item.id),
                );
              },
            ),
          ),

          // Logout button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit Admin Center'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single navigation item
  Widget _buildNavigationItem(
    BuildContext context, {
    required _NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the header with title and actions
  Widget _buildHeader(BuildContext context, _NavigationItem selectedItem) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selectedItem.icon,
            size: 28,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            selectedItem.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh current tab data
              setState(() {
                // This will trigger a rebuild of the current tab
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refreshing ${selectedItem.label}...'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

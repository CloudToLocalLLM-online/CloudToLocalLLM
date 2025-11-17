import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/platform_category_filter.dart';
import '../services/admin_center_service.dart';
import '../services/enhanced_user_tier_service.dart';
import '../models/settings_category.dart';
import '../widgets/settings/settings_category_list.dart';
import '../widgets/settings/general_settings_category.dart';
import '../widgets/settings/local_llm_providers_category.dart';
import '../widgets/settings/import_export_settings_category.dart';
import '../utils/responsive_layout.dart';
import '../di/locator.dart' as di;

/// Main unified settings screen that orchestrates the settings experience
/// across all platforms (web, Windows, Linux, mobile).
///
/// This screen:
/// - Detects the current platform and filters available settings categories
/// - Manages category navigation and search functionality
/// - Provides a responsive layout (single/multi-column based on screen size)
/// - Integrates with existing services (AuthService, PlatformDetectionService)
class UnifiedSettingsScreen extends StatefulWidget {
  /// Optional initial category to display
  final String? initialCategory;

  const UnifiedSettingsScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  late PlatformCategoryFilter _platformFilter;
  late AuthService _authService;
  AdminCenterService? _adminCenterService;
  EnhancedUserTierService? _tierService;

  // State management
  late String _activeCategory;
  String _searchQuery = '';
  List<BaseSettingsCategory> _visibleCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _activeCategory = widget.initialCategory ?? SettingsCategoryIds.general;
  }

  /// Initialize required services
  void _initializeServices() {
    try {
      _authService = di.serviceLocator.get<AuthService>();

      // Try to get AdminCenterService if available
      try {
        _adminCenterService = di.serviceLocator.get<AdminCenterService>();
      } catch (e) {
        debugPrint(
          '[UnifiedSettingsScreen] AdminCenterService not available: $e',
        );
      }

      // Try to get EnhancedUserTierService if available
      try {
        _tierService = di.serviceLocator.get<EnhancedUserTierService>();
      } catch (e) {
        debugPrint(
          '[UnifiedSettingsScreen] EnhancedUserTierService not available: $e',
        );
      }

      // Create platform filter with services
      _platformFilter = PlatformCategoryFilter(
        authService: _authService,
        adminCenterService: _adminCenterService,
        tierService: _tierService,
      );

      // Load visible categories
      _loadVisibleCategories();
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error initializing services: $e');
      setState(() {
        _errorMessage = 'Failed to initialize settings: $e';
        _isLoading = false;
      });
    }
  }

  /// Load visible categories based on platform and user role
  Future<void> _loadVisibleCategories() async {
    try {
      final allCategories = _buildAllCategories();
      debugPrint(
          '[UnifiedSettingsScreen] Built ${allCategories.length} categories');

      final visibleCategories =
          await _platformFilter.getVisibleCategories(allCategories);

      debugPrint(
          '[UnifiedSettingsScreen] Filtered to ${visibleCategories.length} visible categories');
      for (final cat in visibleCategories) {
        debugPrint('[UnifiedSettingsScreen] Visible category: ${cat.id}');
      }

      if (mounted) {
        setState(() {
          _visibleCategories = visibleCategories;
          _isLoading = false;

          // Validate that active category is still visible
          if (!_visibleCategories.any((c) => c.id == _activeCategory)) {
            _activeCategory = _visibleCategories.isNotEmpty
                ? _visibleCategories.first.id
                : SettingsCategoryIds.general;
          }
          debugPrint(
              '[UnifiedSettingsScreen] Active category set to: $_activeCategory');
        });
      }
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error loading categories: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load settings categories: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Build all available settings categories
  List<BaseSettingsCategory> _buildAllCategories() {
    return [
      BaseSettingsCategory(
        id: SettingsCategoryIds.general,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.general),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.general),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.general,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.general,
        ),
        isVisible: true,
        contentBuilder: (context) => GeneralSettingsCategory(
          categoryId: SettingsCategoryIds.general,
          isActive: _activeCategory == SettingsCategoryIds.general,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.localLLMProviders,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.localLLMProviders,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.localLLMProviders,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.localLLMProviders,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.localLLMProviders,
        ),
        isVisible: true,
        contentBuilder: (context) => LocalLLMProvidersCategory(
          categoryId: SettingsCategoryIds.localLLMProviders,
          isActive: _activeCategory == SettingsCategoryIds.localLLMProviders,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.account,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.account),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.account),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.account,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.account,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildAccountCategoryPlaceholder(),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.privacy,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.privacy),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.privacy),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.privacy,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.privacy,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildPrivacyCategoryPlaceholder(),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.importExport,
        title:
            SettingsCategoryMetadata.getTitle(SettingsCategoryIds.importExport),
        icon:
            SettingsCategoryMetadata.getIcon(SettingsCategoryIds.importExport),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.importExport,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.importExport,
        ),
        isVisible: true,
        contentBuilder: (context) => ImportExportSettingsCategory(
          categoryId: SettingsCategoryIds.importExport,
          isActive: _activeCategory == SettingsCategoryIds.importExport,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.desktop,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.desktop),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.desktop),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.desktop,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.desktop,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildDesktopCategoryPlaceholder(),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.mobile,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.mobile),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.mobile),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.mobile,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.mobile,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildMobileCategoryPlaceholder(),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.premiumFeatures,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.premiumFeatures,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.premiumFeatures,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.premiumFeatures,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.premiumFeatures,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildPremiumCategoryPlaceholder(),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.adminCenter,
        title:
            SettingsCategoryMetadata.getTitle(SettingsCategoryIds.adminCenter),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.adminCenter),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.adminCenter,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.adminCenter,
        ),
        isVisible: true,
        contentBuilder: (context) => _buildAdminCenterCategoryPlaceholder(),
      ),
    ];
  }

  /// Handle category selection
  void _selectCategory(String categoryId) {
    setState(() {
      _activeCategory = categoryId;
      _searchQuery = ''; // Clear search when selecting a category
    });
  }

  /// Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// Get the active category widget
  BaseSettingsCategory? _getActiveCategory() {
    try {
      return _visibleCategories.firstWhere(
        (c) => c.id == _activeCategory,
        orElse: () => _visibleCategories.isNotEmpty
            ? _visibleCategories.first
            : BaseSettingsCategory(
                id: 'error',
                title: 'Error',
                icon: Icons.error,
                isVisible: false,
                contentBuilder: (context) => const SizedBox.shrink(),
              ),
      );
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error getting active category: $e');
      return null;
    }
  }

  /// Build responsive layout based on screen size
  Widget _buildResponsiveLayout(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return _buildMobileLayout();
      case ScreenSize.tablet:
        return _buildTabletLayout();
      case ScreenSize.desktop:
        return _buildDesktopLayout();
    }
  }

  /// Mobile layout (single column)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _buildCategoryContent(),
        ),
      ],
    );
  }

  /// Tablet layout (two columns)
  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildCategoryList(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _buildCategoryContent(),
        ),
      ],
    );
  }

  /// Desktop layout (three columns with sidebar)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildCategoryList(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _buildCategoryContent(),
        ),
      ],
    );
  }

  /// Build search bar widget with accessibility features
  Widget _buildSearchBar() {
    final responsivePadding = ResponsiveLayout.getResponsivePadding(context);

    return Padding(
      padding: responsivePadding,
      child: Semantics(
        label: 'Search settings',
        textField: true,
        enabled: true,
        child: TextField(
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search settings...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? Semantics(
                    label: 'Clear search',
                    button: true,
                    enabled: true,
                    onTap: () => _onSearchChanged(''),
                    child: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _onSearchChanged(''),
                      tooltip: 'Clear search (Escape)',
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  /// Build category list widget
  Widget _buildCategoryList() {
    return SettingsCategoryList(
      categories: _visibleCategories,
      activeCategory: _activeCategory,
      searchQuery: _searchQuery,
      onCategorySelected: _selectCategory,
      showDescriptions: true,
    );
  }

  /// Build category content widget
  Widget _buildCategoryContent() {
    final activeCategory = _getActiveCategory();

    if (activeCategory == null) {
      return Semantics(
        label: 'No category selected',
        child: Center(
          child: Text(
            'No category selected',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final responsivePadding = ResponsiveLayout.getResponsivePadding(context);

    return Semantics(
      label: 'Settings content for ${activeCategory.title}',
      child: SingleChildScrollView(
        child: Padding(
          padding: responsivePadding,
          child: Focus(
            onKeyEvent: (node, event) {
              // Handle keyboard shortcuts
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                // Could navigate back or clear search
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                debugPrint(
                    '[UnifiedSettingsScreen] Building content for category: ${activeCategory.id}');
                return activeCategory.contentBuilder(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  // Placeholder builders for each category
  Widget _buildAccountCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Account Settings',
      'Account information and subscription',
    );
  }

  Widget _buildPrivacyCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Privacy Settings',
      'Privacy and data collection settings',
    );
  }

  Widget _buildDesktopCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Desktop Settings',
      'Desktop application settings',
    );
  }

  Widget _buildMobileCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Mobile Settings',
      'Mobile application settings',
    );
  }

  Widget _buildPremiumCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Premium Features',
      'Premium features and upgrades',
    );
  }

  Widget _buildAdminCenterCategoryPlaceholder() {
    return _buildCategoryPlaceholder(
      'Admin Center',
      'Administration and user management',
    );
  }

  /// Generic placeholder for category content
  Widget _buildCategoryPlaceholder(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.construction, size: 32, color: Colors.blue.shade600),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This settings category is being implemented. Check back soon!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Settings screen',
          child: const Text('Settings'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          tooltip: 'Go back',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Semantics(
                  label: 'Error loading settings',
                  enabled: true,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'Error icon',
                          child: Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label: 'Error message',
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Semantics(
                          label: 'Retry loading settings',
                          button: true,
                          enabled: true,
                          onTap: () {
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });
                            _loadVisibleCategories();
                          },
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _loadVisibleCategories();
                            },
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildResponsiveLayout(context),
    );
  }

  @override
  void dispose() {
    _platformFilter.dispose();
    super.dispose();
  }
}

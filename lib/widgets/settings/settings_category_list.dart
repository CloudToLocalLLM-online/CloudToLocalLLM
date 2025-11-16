/// Settings Category List Widget
///
/// Displays a list of settings categories with selection and navigation support.
/// Provides visual indicators for the active category and smooth transitions.
library;

import 'package:flutter/material.dart';
import '../../models/settings_category.dart';
import 'settings_category_widgets.dart';

/// Callback type for category selection
typedef OnCategorySelected = void Function(String categoryId);

/// Settings category list widget for displaying available categories
///
/// This widget:
/// - Displays a list of settings categories
/// - Shows visual indicators for the active category
/// - Supports category selection and navigation
/// - Implements smooth transitions between categories
/// - Handles empty states gracefully
class SettingsCategoryList extends StatefulWidget {
  /// List of categories to display
  final List<BaseSettingsCategory> categories;

  /// Currently active category ID
  final String activeCategory;

  /// Callback when a category is selected
  final OnCategorySelected onCategorySelected;

  /// Optional search query to filter categories
  final String searchQuery;

  /// Whether to show category descriptions
  final bool showDescriptions;

  /// Custom empty state widget
  final Widget? emptyStateWidget;

  /// Animation duration for transitions
  final Duration transitionDuration;

  const SettingsCategoryList({
    super.key,
    required this.categories,
    required this.activeCategory,
    required this.onCategorySelected,
    this.searchQuery = '',
    this.showDescriptions = true,
    this.emptyStateWidget,
    this.transitionDuration = const Duration(milliseconds: 200),
  });

  @override
  State<SettingsCategoryList> createState() => _SettingsCategoryListState();
}

class _SettingsCategoryListState extends State<SettingsCategoryList>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(SettingsCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeCategory != widget.activeCategory) {
      _animationController.forward(from: 0.0);
      _scrollToActiveCategory();
    }
  }

  /// Scroll to the active category in the list
  void _scrollToActiveCategory() {
    final activeIndex = widget.categories.indexWhere(
      (c) => c.id == widget.activeCategory,
    );

    if (activeIndex != -1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollController.animateTo(
            activeIndex * 80.0, // Approximate item height
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  /// Get filtered categories based on search query
  List<BaseSettingsCategory> _getFilteredCategories() {
    if (widget.searchQuery.isEmpty) {
      return widget.categories;
    }

    final query = widget.searchQuery.toLowerCase();
    return widget.categories
        .where((category) =>
            category.title.toLowerCase().contains(query) ||
            category.description.toLowerCase().contains(query))
        .toList();
  }

  /// Build the empty state widget
  Widget _buildEmptyState() {
    if (widget.emptyStateWidget != null) {
      return widget.emptyStateWidget!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No settings found',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search query',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  /// Handle category selection with keyboard support
  void _handleCategorySelection(String categoryId) {
    widget.onCategorySelected(categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _animationController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          final isSelected = category.id == widget.activeCategory;

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  ),
                ),
                child: child,
              );
            },
            child: Semantics(
              label: '${category.title}${isSelected ? ', selected' : ''}',
              button: true,
              enabled: true,
              onTap: () => _handleCategorySelection(category.id),
              child: SettingsCategoryListItem(
                categoryId: category.id,
                title: category.title,
                icon: category.icon,
                description:
                    widget.showDescriptions ? category.description : null,
                isSelected: isSelected,
                onTap: () => _handleCategorySelection(category.id),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

/// Horizontal settings category list widget
///
/// Displays categories in a horizontal scrollable list, useful for
/// tablet and desktop layouts where space is limited.
class HorizontalSettingsCategoryList extends StatefulWidget {
  /// List of categories to display
  final List<BaseSettingsCategory> categories;

  /// Currently active category ID
  final String activeCategory;

  /// Callback when a category is selected
  final OnCategorySelected onCategorySelected;

  /// Optional search query to filter categories
  final String searchQuery;

  /// Height of the category chips
  final double height;

  const HorizontalSettingsCategoryList({
    super.key,
    required this.categories,
    required this.activeCategory,
    required this.onCategorySelected,
    this.searchQuery = '',
    this.height = 56,
  });

  @override
  State<HorizontalSettingsCategoryList> createState() =>
      _HorizontalSettingsCategoryListState();
}

class _HorizontalSettingsCategoryListState
    extends State<HorizontalSettingsCategoryList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  /// Get filtered categories based on search query
  List<BaseSettingsCategory> _getFilteredCategories() {
    if (widget.searchQuery.isEmpty) {
      return widget.categories;
    }

    final query = widget.searchQuery.toLowerCase();
    return widget.categories
        .where((category) =>
            category.title.toLowerCase().contains(query) ||
            category.description.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No categories found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          final isSelected = category.id == widget.activeCategory;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == filteredCategories.length - 1 ? 16 : 8,
            ),
            child: Semantics(
              label: '${category.title}${isSelected ? ', selected' : ''}',
              button: true,
              enabled: true,
              onTap: () => widget.onCategorySelected(category.id),
              child: FilterChip(
                selected: isSelected,
                onSelected: (_) => widget.onCategorySelected(category.id),
                avatar: Icon(
                  category.icon,
                  size: 18,
                  color:
                      isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                ),
                label: Text(category.title),
                backgroundColor: Colors.transparent,
                selectedColor: Colors.blue.shade50,
                side: BorderSide(
                  color:
                      isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// Compact settings category list widget
///
/// Displays categories in a compact format with minimal spacing,
/// useful for mobile layouts.
class CompactSettingsCategoryList extends StatefulWidget {
  /// List of categories to display
  final List<BaseSettingsCategory> categories;

  /// Currently active category ID
  final String activeCategory;

  /// Callback when a category is selected
  final OnCategorySelected onCategorySelected;

  /// Optional search query to filter categories
  final String searchQuery;

  const CompactSettingsCategoryList({
    super.key,
    required this.categories,
    required this.activeCategory,
    required this.onCategorySelected,
    this.searchQuery = '',
  });

  @override
  State<CompactSettingsCategoryList> createState() =>
      _CompactSettingsCategoryListState();
}

class _CompactSettingsCategoryListState
    extends State<CompactSettingsCategoryList> {
  /// Get filtered categories based on search query
  List<BaseSettingsCategory> _getFilteredCategories() {
    if (widget.searchQuery.isEmpty) {
      return widget.categories;
    }

    final query = widget.searchQuery.toLowerCase();
    return widget.categories
        .where((category) =>
            category.title.toLowerCase().contains(query) ||
            category.description.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty) {
      return Center(
        child: Text(
          'No categories found',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    return ListView.separated(
      itemCount: filteredCategories.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final isSelected = category.id == widget.activeCategory;

        return Semantics(
          label: '${category.title}${isSelected ? ', selected' : ''}',
          button: true,
          enabled: true,
          onTap: () => widget.onCategorySelected(category.id),
          child: Material(
            color: isSelected ? Colors.blue.shade50 : Colors.transparent,
            child: InkWell(
              onTap: () => widget.onCategorySelected(category.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 20,
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.blue.shade600 : null,
                            ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.blue.shade600,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

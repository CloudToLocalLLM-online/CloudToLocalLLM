/// Settings Search Bar Widget
///
/// Provides real-time search functionality across all settings categories.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents a single search result
class SettingsSearchResult {
  /// Unique identifier for the result
  final String id;

  /// Category ID this result belongs to
  final String categoryId;

  /// Category title
  final String categoryTitle;

  /// Setting name/label
  final String settingName;

  /// Setting description
  final String? settingDescription;

  /// The matched text from the search
  final String matchedText;

  /// Position of the match in the original text
  final int matchPosition;

  SettingsSearchResult({
    required this.id,
    required this.categoryId,
    required this.categoryTitle,
    required this.settingName,
    this.settingDescription,
    required this.matchedText,
    required this.matchPosition,
  });
}

/// Callback for when a search result is selected
typedef OnSearchResultSelected = void Function(SettingsSearchResult result);

/// Settings Search Bar Widget
///
/// Provides a search input field with real-time filtering and result highlighting.
/// Supports keyboard navigation and accessibility features.
class SettingsSearchBar extends StatefulWidget {
  /// Callback when search query changes
  final ValueChanged<String>? onSearchChanged;

  /// Callback when a search result is selected
  final OnSearchResultSelected? onResultSelected;

  /// Callback when search is cleared
  final VoidCallback? onSearchCleared;

  /// List of available search results
  final List<SettingsSearchResult> searchResults;

  /// Whether the search bar is enabled
  final bool enabled;

  /// Hint text for the search input
  final String hintText;

  /// Debounce duration for search (default: 300ms)
  final Duration debounceDuration;

  /// Maximum number of results to display
  final int maxResults;

  /// Whether to show result count
  final bool showResultCount;

  /// Custom search result builder
  final Widget Function(BuildContext, SettingsSearchResult, int)?
      searchResultBuilder;

  const SettingsSearchBar({
    super.key,
    this.onSearchChanged,
    this.onResultSelected,
    this.onSearchCleared,
    this.searchResults = const [],
    this.enabled = true,
    this.hintText = 'Search settings...',
    this.debounceDuration = const Duration(milliseconds: 300),
    this.maxResults = 10,
    this.showResultCount = true,
    this.searchResultBuilder,
  });

  @override
  State<SettingsSearchBar> createState() => _SettingsSearchBarState();
}

class _SettingsSearchBarState extends State<SettingsSearchBar> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late FocusNode _resultsFocusNode;
  bool _showResults = false;
  int _selectedResultIndex = -1;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _resultsFocusNode = FocusNode();

    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _resultsFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    setState(() {
      _showResults =
          _searchFocusNode.hasFocus && _searchController.text.isNotEmpty;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _showResults = value.isNotEmpty;
      _selectedResultIndex = -1;
    });
    widget.onSearchChanged?.call(value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showResults = false;
      _selectedResultIndex = -1;
    });
    widget.onSearchCleared?.call();
    _searchFocusNode.requestFocus();
  }

  void _selectResult(SettingsSearchResult result, int index) {
    widget.onResultSelected?.call(result);
    setState(() {
      _selectedResultIndex = index;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_showResults || widget.searchResults.isEmpty) {
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearSearch();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedResultIndex =
            (_selectedResultIndex + 1) % widget.searchResults.length;
      });
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedResultIndex = _selectedResultIndex <= 0
            ? widget.searchResults.length - 1
            : _selectedResultIndex - 1;
      });
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedResultIndex >= 0 &&
          _selectedResultIndex < widget.searchResults.length) {
        _selectResult(
            widget.searchResults[_selectedResultIndex], _selectedResultIndex);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return KeyboardListener(
      focusNode: _resultsFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Search settings input',
              textField: true,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                enabled: widget.enabled,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          if (_showResults && widget.searchResults.isNotEmpty)
            _buildSearchResults(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, bool isMobile) {
    final displayedResults =
        widget.searchResults.take(widget.maxResults).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showResultCount)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Found ${widget.searchResults.length} result${widget.searchResults.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedResults.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final result = displayedResults[index];
                final isSelected = _selectedResultIndex == index;

                return widget.searchResultBuilder
                        ?.call(context, result, index) ??
                    _buildDefaultSearchResult(
                        context, result, isSelected, index);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDefaultSearchResult(
    BuildContext context,
    SettingsSearchResult result,
    bool isSelected,
    int index,
  ) {
    return Material(
      color: isSelected ? Colors.blue.shade50 : Colors.transparent,
      child: InkWell(
        onTap: () => _selectResult(result, index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.categoryTitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.settingName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.blue.shade700 : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                ],
              ),
              if (result.settingDescription != null) ...[
                const SizedBox(height: 8),
                Text(
                  result.settingDescription!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Search utility for filtering settings
class SettingsSearchUtil {
  /// Perform a case-insensitive search across settings
  static List<SettingsSearchResult> search(
    String query,
    List<SettingsSearchResult> allResults,
  ) {
    if (query.isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase();
    final results = <SettingsSearchResult>[];

    for (final result in allResults) {
      final categoryMatch =
          result.categoryTitle.toLowerCase().contains(lowerQuery);
      final settingMatch =
          result.settingName.toLowerCase().contains(lowerQuery);
      final descriptionMatch =
          result.settingDescription?.toLowerCase().contains(lowerQuery) ??
              false;

      if (categoryMatch || settingMatch || descriptionMatch) {
        results.add(result);
      }
    }

    // Sort by relevance: exact matches first, then category matches, then description matches
    results.sort((a, b) {
      final aExact = a.settingName.toLowerCase() == lowerQuery ? 0 : 1;
      final bExact = b.settingName.toLowerCase() == lowerQuery ? 0 : 1;

      if (aExact != bExact) return aExact.compareTo(bExact);

      final aCategory =
          a.categoryTitle.toLowerCase().contains(lowerQuery) ? 0 : 1;
      final bCategory =
          b.categoryTitle.toLowerCase().contains(lowerQuery) ? 0 : 1;

      return aCategory.compareTo(bCategory);
    });

    return results;
  }

  /// Highlight matching text in a string
  static String highlightMatch(String text, String query) {
    if (query.isEmpty) return text;

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) return text;

    return text.replaceFirst(
      RegExp(RegExp.escape(query), caseSensitive: false),
      '**${text.substring(index, index + query.length)}**',
    );
  }
}

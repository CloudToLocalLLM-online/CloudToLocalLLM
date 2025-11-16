/// Settings UI State Model
///
/// Manages the state of the unified settings screen including navigation,
/// validation, and loading states.
library;

/// Represents the state of the settings UI
class SettingsUIState {
  /// Currently active settings category ID
  final String activeCategory;

  /// Current search query for filtering settings
  final String searchQuery;

  /// Field-level validation errors (fieldName -> errorMessage)
  final Map<String, String> fieldErrors;

  /// Whether the screen is currently loading data
  final bool isLoading;

  /// Whether settings are being saved
  final bool isSaving;

  /// Whether the current user is an admin
  final bool isAdminUser;

  /// Whether settings have been modified but not saved
  final bool isDirty;

  /// Last error message, if any
  final String? lastError;

  /// Timestamp of last successful save
  final DateTime? lastSaveTime;

  const SettingsUIState({
    this.activeCategory = 'general',
    this.searchQuery = '',
    this.fieldErrors = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.isAdminUser = false,
    this.isDirty = false,
    this.lastError,
    this.lastSaveTime,
  });

  /// Create a copy with updated values
  SettingsUIState copyWith({
    String? activeCategory,
    String? searchQuery,
    Map<String, String>? fieldErrors,
    bool? isLoading,
    bool? isSaving,
    bool? isAdminUser,
    bool? isDirty,
    String? lastError,
    DateTime? lastSaveTime,
  }) {
    return SettingsUIState(
      activeCategory: activeCategory ?? this.activeCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isAdminUser: isAdminUser ?? this.isAdminUser,
      isDirty: isDirty ?? this.isDirty,
      lastError: lastError ?? this.lastError,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
    );
  }

  /// Clear all validation errors
  SettingsUIState clearErrors() {
    return copyWith(fieldErrors: {}, lastError: null);
  }

  /// Add a field error
  SettingsUIState addFieldError(String fieldName, String errorMessage) {
    final updatedErrors = Map<String, String>.from(fieldErrors);
    updatedErrors[fieldName] = errorMessage;
    return copyWith(fieldErrors: updatedErrors);
  }

  /// Remove a field error
  SettingsUIState removeFieldError(String fieldName) {
    final updatedErrors = Map<String, String>.from(fieldErrors);
    updatedErrors.remove(fieldName);
    return copyWith(fieldErrors: updatedErrors);
  }

  /// Check if there are any validation errors
  bool get hasErrors => fieldErrors.isNotEmpty || lastError != null;

  /// Check if the screen is in a loading or saving state
  bool get isBusy => isLoading || isSaving;
}

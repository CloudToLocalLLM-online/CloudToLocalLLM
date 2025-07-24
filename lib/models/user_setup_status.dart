/// Model representing a user's setup completion status and preferences
///
/// This model tracks the complete setup state for a user including:
/// - First-time user status and setup completion
/// - Desktop client connection status
/// - Setup completion timestamps
/// - User preferences and configuration
class UserSetupStatus {
  final String userId;
  final bool isFirstTimeUser;
  final bool setupCompleted;
  final DateTime? setupCompletedAt;
  final DateTime lastUpdated;
  final bool hasActiveDesktopConnection;
  final String setupVersion;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic>? metadata;

  const UserSetupStatus({
    required this.userId,
    required this.isFirstTimeUser,
    required this.setupCompleted,
    this.setupCompletedAt,
    required this.lastUpdated,
    required this.hasActiveDesktopConnection,
    required this.setupVersion,
    required this.preferences,
    this.metadata,
  });

  /// Create a new first-time user status
  factory UserSetupStatus.newUser(String userId) {
    return UserSetupStatus(
      userId: userId,
      isFirstTimeUser: true,
      setupCompleted: false,
      lastUpdated: DateTime.now(),
      hasActiveDesktopConnection: false,
      setupVersion: '1.0.0',
      preferences: {},
    );
  }

  /// Create a completed setup status
  factory UserSetupStatus.completed(
    String userId, {
    bool hasActiveDesktopConnection = false,
    Map<String, dynamic>? preferences,
  }) {
    final now = DateTime.now();
    return UserSetupStatus(
      userId: userId,
      isFirstTimeUser: false,
      setupCompleted: true,
      setupCompletedAt: now,
      lastUpdated: now,
      hasActiveDesktopConnection: hasActiveDesktopConnection,
      setupVersion: '1.0.0',
      preferences: preferences ?? {},
    );
  }

  /// Check if setup is required
  bool get requiresSetup => isFirstTimeUser || !setupCompleted;

  /// Check if setup was completed recently (within last 24 hours)
  bool get isRecentlyCompleted {
    if (setupCompletedAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(setupCompletedAt!);
    return difference.inHours < 24;
  }

  /// Get setup completion duration (if completed)
  Duration? get setupDuration {
    if (setupCompletedAt == null) return null;
    // Assuming setup started when user was created (simplified)
    return setupCompletedAt!.difference(lastUpdated);
  }

  /// Get user preference value
  T? getPreference<T>(String key, [T? defaultValue]) {
    final value = preferences[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Check if user has specific preference
  bool hasPreference(String key) {
    return preferences.containsKey(key);
  }

  /// Get setup status summary
  Map<String, dynamic> get statusSummary {
    return {
      'userId': userId,
      'isFirstTimeUser': isFirstTimeUser,
      'setupCompleted': setupCompleted,
      'requiresSetup': requiresSetup,
      'hasActiveDesktopConnection': hasActiveDesktopConnection,
      'isRecentlyCompleted': isRecentlyCompleted,
      'setupVersion': setupVersion,
      'preferenceCount': preferences.length,
      'lastUpdated': lastUpdated.toIso8601String(),
      'setupCompletedAt': setupCompletedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  UserSetupStatus copyWith({
    String? userId,
    bool? isFirstTimeUser,
    bool? setupCompleted,
    DateTime? setupCompletedAt,
    DateTime? lastUpdated,
    bool? hasActiveDesktopConnection,
    String? setupVersion,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? metadata,
  }) {
    return UserSetupStatus(
      userId: userId ?? this.userId,
      isFirstTimeUser: isFirstTimeUser ?? this.isFirstTimeUser,
      setupCompleted: setupCompleted ?? this.setupCompleted,
      setupCompletedAt: setupCompletedAt ?? this.setupCompletedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      hasActiveDesktopConnection: hasActiveDesktopConnection ?? this.hasActiveDesktopConnection,
      setupVersion: setupVersion ?? this.setupVersion,
      preferences: preferences ?? this.preferences,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isFirstTimeUser': isFirstTimeUser,
      'setupCompleted': setupCompleted,
      'setupCompletedAt': setupCompletedAt?.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'hasActiveDesktopConnection': hasActiveDesktopConnection,
      'setupVersion': setupVersion,
      'preferences': preferences,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory UserSetupStatus.fromJson(Map<String, dynamic> json) {
    return UserSetupStatus(
      userId: json['userId'] as String,
      isFirstTimeUser: json['isFirstTimeUser'] as bool,
      setupCompleted: json['setupCompleted'] as bool,
      setupCompletedAt: json['setupCompletedAt'] != null
          ? DateTime.parse(json['setupCompletedAt'] as String)
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      hasActiveDesktopConnection: json['hasActiveDesktopConnection'] as bool,
      setupVersion: json['setupVersion'] as String,
      preferences: Map<String, dynamic>.from(json['preferences'] as Map),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Validate the setup status data
  bool get isValid {
    return userId.isNotEmpty &&
           setupVersion.isNotEmpty &&
           (!setupCompleted || setupCompletedAt != null);
  }

  /// Get validation errors
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (userId.isEmpty) {
      errors.add('User ID cannot be empty');
    }
    
    if (setupVersion.isEmpty) {
      errors.add('Setup version cannot be empty');
    }
    
    if (setupCompleted && setupCompletedAt == null) {
      errors.add('Setup completed timestamp is required when setup is marked complete');
    }
    
    if (setupCompletedAt != null && setupCompletedAt!.isAfter(DateTime.now())) {
      errors.add('Setup completed timestamp cannot be in the future');
    }
    
    return errors;
  }

  @override
  String toString() {
    return 'UserSetupStatus(userId: $userId, isFirstTimeUser: $isFirstTimeUser, '
           'setupCompleted: $setupCompleted, hasActiveDesktopConnection: $hasActiveDesktopConnection, '
           'setupVersion: $setupVersion, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserSetupStatus &&
           other.userId == userId &&
           other.isFirstTimeUser == isFirstTimeUser &&
           other.setupCompleted == setupCompleted &&
           other.setupCompletedAt == setupCompletedAt &&
           other.hasActiveDesktopConnection == hasActiveDesktopConnection &&
           other.setupVersion == setupVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      isFirstTimeUser,
      setupCompleted,
      setupCompletedAt,
      hasActiveDesktopConnection,
      setupVersion,
    );
  }
}

/// Extension methods for UserSetupStatus
extension UserSetupStatusExtensions on UserSetupStatus {
  /// Check if user prefers a specific platform
  String? get preferredPlatform => getPreference<String>('preferredPlatform');
  
  /// Check if user has skipped validation
  bool get hasSkippedValidation => getPreference<bool>('skippedValidation', false) ?? false;

  /// Check if user wants to see advanced options
  bool get showAdvancedOptions => getPreference<bool>('showAdvancedOptions', false) ?? false;

  /// Get user's preferred language
  String get preferredLanguage => getPreference<String>('language', 'en') ?? 'en';

  /// Check if user has enabled analytics
  bool get analyticsEnabled => getPreference<bool>('analyticsEnabled', true) ?? true;
}

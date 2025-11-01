import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation_storage_service.dart';
import 'enhanced_user_tier_service.dart';
import 'auth_service.dart';

/// Privacy-first storage manager that enforces tier-based data policies
///
/// PRIVACY ARCHITECTURE:
/// - Free Tier: Local storage only, no cloud sync
/// - Premium Tier: Optional encrypted cloud sync with user control
/// - All tiers: Conversation data never leaves device without explicit consent
/// - Transparent storage location indicators for users
class PrivacyStorageManager extends ChangeNotifier {
  final ConversationStorageService _conversationStorage;
  final EnhancedUserTierService _userTierService;
  final AuthService _authService;

  // Privacy settings
  bool _cloudSyncEnabled = false;
  bool _encryptionEnabled = false;
  String _storageLocation = 'local_only';
  DateTime? _lastSyncTime;

  // Storage statistics
  int _totalConversations = 0;
  int _totalMessages = 0;
  String _databaseSize = '0 KB';

  PrivacyStorageManager({
    required ConversationStorageService conversationStorage,
    required EnhancedUserTierService userTierService,
    required AuthService authService,
  }) : _conversationStorage = conversationStorage,
       _userTierService = userTierService,
       _authService = authService;

  // Getters
  bool get cloudSyncEnabled => _cloudSyncEnabled;
  bool get encryptionEnabled => _encryptionEnabled;
  String get storageLocation => _storageLocation;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get totalConversations => _totalConversations;
  int get totalMessages => _totalMessages;
  String get databaseSize => _databaseSize;

  /// Initialize privacy storage manager
  Future<void> initialize() async {
    try {
      debugPrint('� [PrivacyStorage] Initializing privacy storage manager...');

      // Initialize conversation storage first
      await _conversationStorage.initialize();

      // Load privacy settings
      await _loadPrivacySettings();

      // Update storage statistics
      await _updateStorageStatistics();

      debugPrint('� [PrivacyStorage] Privacy storage manager initialized');
      debugPrint('� [PrivacyStorage] Storage location: $_storageLocation');
      debugPrint(
        '� [PrivacyStorage] Cloud sync: ${_cloudSyncEnabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Load privacy settings from local storage
  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _cloudSyncEnabled = prefs.getBool('cloud_sync_enabled') ?? false;
      _encryptionEnabled = prefs.getBool('encryption_enabled') ?? false;
      _storageLocation = prefs.getString('storage_location') ?? 'local_only';

      final lastSyncTimestamp = prefs.getInt('last_sync_time');
      if (lastSyncTimestamp != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
      }

      debugPrint('� [PrivacyStorage] Privacy settings loaded');
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to load privacy settings: $e');
      // Use safe defaults
      _cloudSyncEnabled = false;
      _encryptionEnabled = false;
      _storageLocation = 'local_only';
    }
  }

  /// Save privacy settings to local storage
  Future<void> _savePrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('cloud_sync_enabled', _cloudSyncEnabled);
      await prefs.setBool('encryption_enabled', _encryptionEnabled);
      await prefs.setString('storage_location', _storageLocation);

      if (_lastSyncTime != null) {
        await prefs.setInt(
          'last_sync_time',
          _lastSyncTime!.millisecondsSinceEpoch,
        );
      }

      debugPrint('� [PrivacyStorage] Privacy settings saved');
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to save privacy settings: $e');
    }
  }

  /// Update storage statistics for transparency
  Future<void> _updateStorageStatistics() async {
    try {
      final stats = await _conversationStorage.getDatabaseStats();
      _totalConversations = stats['total_conversations'] ?? 0;
      _totalMessages = stats['total_messages'] ?? 0;

      // Calculate approximate database size (simplified)
      final avgMessageSize = 100; // bytes
      final estimatedSize = _totalMessages * avgMessageSize;
      _databaseSize = _formatBytes(estimatedSize);

      notifyListeners();
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to update storage statistics: $e');
    }
  }

  /// Format bytes to human-readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Enable cloud sync (Premium tier only)
  Future<bool> enableCloudSync() async {
    try {
      // Check if user has premium tier
      if (!_userTierService.isPremiumTier) {
        debugPrint('� [PrivacyStorage] Cloud sync requires premium tier');
        return false;
      }

      // Verify user authentication
      if (!_authService.isAuthenticated.value) {
        debugPrint('� [PrivacyStorage] Cloud sync requires authentication');
        return false;
      }

      _cloudSyncEnabled = true;
      _storageLocation = 'local_with_cloud_sync';

      await _savePrivacySettings();
      await _conversationStorage.setStorageLocation(_storageLocation);

      debugPrint('� [PrivacyStorage] Cloud sync enabled');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to enable cloud sync: $e');
      return false;
    }
  }

  /// Disable cloud sync
  Future<void> disableCloudSync() async {
    try {
      _cloudSyncEnabled = false;
      _storageLocation = 'local_only';
      _lastSyncTime = null;

      await _savePrivacySettings();
      await _conversationStorage.setStorageLocation(_storageLocation);

      debugPrint('� [PrivacyStorage] Cloud sync disabled');
      notifyListeners();
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to disable cloud sync: $e');
    }
  }

  /// Enable encryption for stored conversations
  Future<bool> enableEncryption() async {
    try {
      // Check if user has premium tier (encryption is premium feature)
      if (!_userTierService.isPremiumTier) {
        debugPrint('� [PrivacyStorage] Encryption requires premium tier');
        return false;
      }

      _encryptionEnabled = true;
      await _savePrivacySettings();
      // Enable encryption in ConversationStorageService
      await _conversationStorage.setEncryptionEnabled(true);

      debugPrint('� [PrivacyStorage] Encryption enabled');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to enable encryption: $e');
      return false;
    }
  }

  /// Disable encryption for stored conversations
  Future<void> disableEncryption() async {
    try {
      _encryptionEnabled = false;
      await _savePrivacySettings();
      // Disable encryption in ConversationStorageService
      await _conversationStorage.setEncryptionEnabled(false);

      debugPrint('� [PrivacyStorage] Encryption disabled');
      notifyListeners();
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to disable encryption: $e');
    }
  }

  /// Get storage location display text for UI
  String get storageLocationDisplay {
    switch (_storageLocation) {
      case 'local_only':
        return '� Local Storage Only';
      case 'local_with_cloud_sync':
        return '☁ Local + Cloud Sync';
      default:
        return '� Local Storage';
    }
  }

  /// Get privacy status summary
  Map<String, dynamic> get privacyStatus {
    return {
      'storage_location': _storageLocation,
      'cloud_sync_enabled': _cloudSyncEnabled,
      'encryption_enabled': _encryptionEnabled,
      'total_conversations': _totalConversations,
      'total_messages': _totalMessages,
      'database_size': _databaseSize,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
      'user_tier': _userTierService.currentTier,
      'platform': kIsWeb ? 'web' : 'desktop',
    };
  }

  /// Export conversations for manual backup
  Future<Map<String, dynamic>> exportConversations() async {
    try {
      debugPrint('� [PrivacyStorage] Exporting conversations for backup...');

      final exportData = await _conversationStorage.exportConversations();

      // Add privacy metadata
      exportData['privacy_info'] = {
        'storage_location': _storageLocation,
        'cloud_sync_enabled': _cloudSyncEnabled,
        'export_timestamp': DateTime.now().toIso8601String(),
        'user_tier': _userTierService.currentTier,
      };

      debugPrint('� [PrivacyStorage] Conversations exported successfully');
      return exportData;
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to export conversations: $e');
      rethrow;
    }
  }

  /// Check if cloud sync is available for current user
  bool get isCloudSyncAvailable {
    return _userTierService.isPremiumTier && _authService.isAuthenticated.value;
  }

  /// Check if encryption is available for current user
  bool get isEncryptionAvailable {
    return _userTierService.isPremiumTier;
  }

  /// Get tier-specific storage limitations
  Map<String, dynamic> get tierLimitations {
    if (_userTierService.isPremiumTier) {
      return {
        'cloud_sync': true,
        'encryption': true,
        'unlimited_storage': true,
        'cross_device_sync': true,
        'automated_backup': true,
      };
    } else {
      return {
        'cloud_sync': false,
        'encryption': false,
        'unlimited_storage': true, // Local storage is unlimited
        'cross_device_sync': false,
        'automated_backup': false,
      };
    }
  }

  /// Refresh storage statistics
  Future<void> refreshStatistics() async {
    await _updateStorageStatistics();
  }

  /// Clear all local data (with confirmation)
  Future<void> clearAllLocalData() async {
    try {
      debugPrint('� [PrivacyStorage] Clearing all local data...');

      await _conversationStorage.clearAllConversations();

      // Reset privacy settings to defaults
      _cloudSyncEnabled = false;
      _encryptionEnabled = false;
      _storageLocation = 'local_only';
      _lastSyncTime = null;

      await _savePrivacySettings();
      await _updateStorageStatistics();

      debugPrint('� [PrivacyStorage] All local data cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('� [PrivacyStorage] Failed to clear local data: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _conversationStorage.dispose();
    super.dispose();
  }
}

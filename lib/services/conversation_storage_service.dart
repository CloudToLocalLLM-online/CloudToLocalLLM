import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

// Conditional imports for desktop-only dependencies - NOT loaded on web
import 'conversation_storage_service_desktop.dart'
    if (dart.library.html) 'conversation_storage_service_web.dart';

/// Conversation storage service with platform-specific storage
///
/// STORAGE STRATEGY:
/// - Web platform: Uses PostgreSQL database via API (cloud storage)
/// - Desktop platform: Uses SQLite files in user documents directory (local storage)
class ConversationStorageService {
  static const String _databaseName = 'cloudtolocalllm_conversations.db';
  static const int _databaseVersion = 2; // Incremented for privacy enhancements

  // Table names
  static const String _conversationsTable = 'conversations';
  static const String _messagesTable = 'messages';
  static const String _settingsTable = 'user_settings';

  final AuthService? _authService;
  Database? _database;
  bool _isInitialized = false;
  bool _encryptionEnabled = false;
  final Dio _dio = Dio();

  ConversationStorageService({AuthService? authService})
      : _authService = authService {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  /// Initialize the storage service with platform-specific database factory
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('� [ConversationStorage] Already initialized, skipping');
      return;
    }

    try {
      // Initialize sqflite for different platforms
      if (kIsWeb) {
        // For web platform, use the default factory (IndexedDB)
        // No additional initialization needed - sqflite automatically uses IndexedDB
        debugPrint('� [ConversationStorage] Using IndexedDB for web platform');
        debugPrint(
          '� [ConversationStorage] Privacy: Data stored in browser IndexedDB only',
        );
      } else {
        // For desktop/mobile platforms, sqflite automatically uses SQLite
        debugPrint(
          '� [ConversationStorage] Using SQLite FFI for desktop platform',
        );
        debugPrint(
          '� [ConversationStorage] Privacy: Data stored in local SQLite file only',
        );
      }

      if (kIsWeb) {
        // Web platform: Use PostgreSQL via API - skip local database
        _isInitialized = true;
        debugPrint(
            '[ConversationStorage] Web platform initialized (using cloud storage)');
      } else {
        // Desktop platform: Use local SQLite
        await _initializeDatabase();
        _isInitialized = true;
        debugPrint(
            '[ConversationStorage] Desktop platform initialized (using local storage)');
      }
    } catch (e, stackTrace) {
      debugPrint('[ConversationStorage] Failed to initialize: $e');
      debugPrint('[ConversationStorage] Stack trace: $stackTrace');
      // On desktop/mobile, database is critical - rethrow
      if (!kIsWeb) {
        rethrow;
      }
      // Web can continue without local database (uses API)
      _isInitialized = true;
    }
  }

  /// Initialize the database with enhanced privacy features
  Future<void> _initializeDatabase() async {
    try {
      final databasePath = await _getDatabasePath();
      debugPrint('� [ConversationStorage] Database path: $databasePath');

      _database = await openDatabase(
        databasePath,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        singleInstance: true,
      );

      debugPrint('� [ConversationStorage] Database opened successfully');
    } catch (e) {
      debugPrint('� [ConversationStorage] Database initialization failed: $e');
      rethrow;
    }
  }

  /// Get the database file path with platform-specific handling
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // For web, use a simple path (IndexedDB will be used internally)
      // sqflite automatically uses IndexedDB on web, no file path needed
      return _databaseName;
    }

    try {
      // For desktop/mobile, use app documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final appDirectory = Directory(
        join(documentsDirectory.path, 'CloudToLocalLLM'),
      );

      // Create directory if it doesn't exist
      if (!await appDirectory.exists()) {
        await appDirectory.create(recursive: true);
        debugPrint(
          '� [ConversationStorage] Created app directory: ${appDirectory.path}',
        );
      }

      return join(appDirectory.path, _databaseName);
    } catch (e) {
      debugPrint(
        '� [ConversationStorage] Failed to get documents directory: $e',
      );
      // Fallback to current directory
      return _databaseName;
    }
  }

  /// Create database tables with privacy-focused schema
  Future<void> _createDatabase(Database db, int version) async {
    try {
      // Create conversations table
      await db.execute('''
        CREATE TABLE $_conversationsTable (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          model TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_encrypted INTEGER DEFAULT 0,
          storage_location TEXT DEFAULT 'local'
        )
      ''');

      // Create messages table
      await db.execute('''
        CREATE TABLE $_messagesTable (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          model TEXT,
          status TEXT NOT NULL,
          error TEXT,
          timestamp INTEGER NOT NULL,
          is_encrypted INTEGER DEFAULT 0,
          FOREIGN KEY (conversation_id) REFERENCES $_conversationsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create user settings table for privacy preferences
      await db.execute('''
        CREATE TABLE $_settingsTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for better performance
      await db.execute('''
        CREATE INDEX idx_messages_conversation_id ON $_messagesTable (conversation_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_conversations_updated_at ON $_conversationsTable (updated_at DESC)
      ''');

      await db.execute('''
        CREATE INDEX idx_settings_key ON $_settingsTable (key)
      ''');

      // Insert default privacy settings
      await _insertDefaultPrivacySettings(db);

      debugPrint(
        '� [ConversationStorage] Database tables created with privacy features',
      );
    } catch (e) {
      debugPrint(
        '� [ConversationStorage] Failed to create database tables: $e',
      );
      rethrow;
    }
  }

  /// Insert default privacy settings
  Future<void> _insertDefaultPrivacySettings(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(_settingsTable, {
      'key': 'storage_location',
      'value': 'local_only',
      'updated_at': now,
    });

    await db.insert(_settingsTable, {
      'key': 'cloud_sync_enabled',
      'value': 'false',
      'updated_at': now,
    });

    await db.insert(_settingsTable, {
      'key': 'data_retention_days',
      'value': '365',
      'updated_at': now,
    });

    debugPrint('� [ConversationStorage] Default privacy settings inserted');
  }

  /// Upgrade database schema
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      '� [ConversationStorage] Upgrading database from v$oldVersion to v$newVersion',
    );

    if (oldVersion < 2) {
      // Add privacy columns to existing tables
      try {
        await db.execute(
          'ALTER TABLE $_conversationsTable ADD COLUMN is_encrypted INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $_conversationsTable ADD COLUMN storage_location TEXT DEFAULT "local"',
        );
        await db.execute(
          'ALTER TABLE $_messagesTable ADD COLUMN is_encrypted INTEGER DEFAULT 0',
        );

        // Create settings table if it doesn't exist
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await _insertDefaultPrivacySettings(db);
        debugPrint(
          '� [ConversationStorage] Privacy enhancements added to database',
        );
      } catch (e) {
        debugPrint('� [ConversationStorage] Database upgrade failed: $e');
        // Continue with existing schema if upgrade fails
      }
    }
  }

  /// Save a list of conversations
  Future<void> saveConversations(List<Conversation> conversations) async {
    if (kIsWeb) {
      // Web: Save each conversation via API
      await _saveConversationsViaAPI(conversations);
      return;
    }

    // Desktop: Use local SQLite
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        // Clear existing data
        await txn.delete(_messagesTable);
        await txn.delete(_conversationsTable);

        // Insert conversations and messages
        for (final conversation in conversations) {
          await _insertConversation(txn, conversation);
          await _insertMessages(txn, conversation);
        }
      });

      debugPrint(
        '� [ConversationStorage] Saved ${conversations.length} conversations',
      );
    } catch (e) {
      debugPrint('� [ConversationStorage] Error saving conversations: $e');
      rethrow;
    }
  }

  /// Load all conversations
  Future<List<Conversation>> loadConversations() async {
    if (_database == null) {
      if (kIsWeb) {
        debugPrint(
            '[ConversationStorage] Database not available on web, returning empty list');
        return []; // Return empty list on web if database failed to initialize
      }
      throw StateError('Database not initialized');
    }

    try {
      // Load conversations ordered by most recently updated
      final conversationRows = await _database!.query(
        _conversationsTable,
        orderBy: 'updated_at DESC',
      );

      final conversations = <Conversation>[];

      for (final row in conversationRows) {
        final conversation = await _loadConversationWithMessages(row);
        conversations.add(conversation);
      }

      debugPrint(
        '� [ConversationStorage] Loaded ${conversations.length} conversations',
      );
      return conversations;
    } catch (e) {
      debugPrint('� [ConversationStorage] Error loading conversations: $e');
      return [];
    }
  }

  /// Save a single conversation (update or insert)
  Future<void> saveConversation(Conversation conversation) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await _insertConversation(txn, conversation);

        // Delete existing messages for this conversation
        await txn.delete(
          _messagesTable,
          where: 'conversation_id = ?',
          whereArgs: [conversation.id],
        );

        // Insert updated messages
        await _insertMessages(txn, conversation);
      });

      debugPrint(
        '� [ConversationStorage] Saved conversation: ${conversation.title}',
      );
    } catch (e) {
      debugPrint('� [ConversationStorage] Error saving conversation: $e');
      rethrow;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    if (kIsWeb) {
      // Web: Delete via API
      await _deleteConversationViaAPI(conversationId);
      return;
    }

    // Desktop: Use local SQLite
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        // Delete messages first (foreign key constraint)
        await txn.delete(
          _messagesTable,
          where: 'conversation_id = ?',
          whereArgs: [conversationId],
        );

        // Delete conversation
        await txn.delete(
          _conversationsTable,
          where: 'id = ?',
          whereArgs: [conversationId],
        );
      });

      debugPrint(
        '� [ConversationStorage] Deleted conversation: $conversationId',
      );
    } catch (e) {
      debugPrint('� [ConversationStorage] Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    if (kIsWeb) {
      // Web: Delete all conversations via API
      final conversations = await _loadConversationsViaAPI();
      for (final conv in conversations) {
        await _deleteConversationViaAPI(conv.id);
      }
      return;
    }

    // Desktop: Use local SQLite
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await txn.delete(_messagesTable);
        await txn.delete(_conversationsTable);
      });

      debugPrint('� [ConversationStorage] Cleared all conversations');
    } catch (e) {
      debugPrint('� [ConversationStorage] Error clearing conversations: $e');
      rethrow;
    }
  }

  // ========== API Helper Methods for Web Platform ==========

  /// Get authentication headers for API requests
  Future<Map<String, String>> _getAuthHeaders() async {
    if (_authService == null) {
      throw StateError('AuthService not available');
    }

    final token = await _authService.getValidatedAccessToken();
    debugPrint(
        '[ConversationStorage] Got token: ${token != null ? "YES (${token.length} chars)" : "NO"}');

    if (token == null) {
      debugPrint(
          '[ConversationStorage] Auth service authenticated: ${_authService.isAuthenticated}');
      throw StateError('No access token available');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    debugPrint('[ConversationStorage] Headers: ${headers.keys.join(", ")}');
    return headers;
  }

  /// Load conversations from API (web platform)
  Future<List<Conversation>> _loadConversationsViaAPI() async {
    try {
      final headers = await _getAuthHeaders();

      final response =
          await _dio.get('/conversations', options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final conversationsData = data['conversations'] as List<dynamic>? ?? [];

        final conversations = <Conversation>[];
        for (final convData in conversationsData) {
          // Load full conversation with messages
          final convId = convData['id'] as String;
          final fullConv = await _loadConversationViaAPI(convId);
          if (fullConv != null) {
            conversations.add(fullConv);
          }
        }

        debugPrint(
          '[ConversationStorage] Loaded ${conversations.length} conversations from API',
        );
        return conversations;
      } else {
        debugPrint(
          '[ConversationStorage] Failed to load conversations: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error loading conversations from API: $e');
      return [];
    }
  }

  /// Load a single conversation with messages from API
  Future<Conversation?> _loadConversationViaAPI(String conversationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get('/conversations/$conversationId',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final convData = data['conversation'] as Map<String, dynamic>;

        return Conversation.fromJson({
          'id': convData['id'],
          'title': convData['title'],
          'model': convData['model'],
          'createdAt': convData['created_at'],
          'updatedAt': convData['updated_at'],
          'metadata': convData['metadata'] ?? {},
          'messages': (convData['messages'] as List<dynamic>?)
                  ?.map((m) => {
                        'id': m['id'],
                        'role': m['role'],
                        'content': m['content'],
                        'model': m['model'],
                        'timestamp': m['timestamp'],
                        'metadata': m['metadata'] ?? {},
                      })
                  .toList() ??
              [],
        });
      }
      return null;
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error loading conversation from API: $e');
      return null;
    }
  }

  /// Save conversations via API (web platform)
  Future<void> _saveConversationsViaAPI(
      List<Conversation> conversations) async {
    for (final conversation in conversations) {
      await _saveConversationViaAPI(conversation);
    }
  }

  /// Save a single conversation via API (web platform)
  Future<void> _saveConversationViaAPI(Conversation conversation) async {
    try {
      final headers = await _getAuthHeaders();

      final body = {
        'title': conversation.title,
        'messages': conversation.messages
            .map((m) => {
                  'role': m.role.name,
                  'content': m.content,
                  'model': m.model,
                  'timestamp': m.timestamp.toIso8601String(),
                })
            .toList(),
      };

      final response = await _dio.put('/conversations/${conversation.id}',
          data: body, options: Options(headers: headers));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          '[ConversationStorage] Saved conversation via API: ${conversation.title}',
        );
      } else {
        // Try POST if PUT fails (conversation doesn't exist yet)
        final postBody = {
          'title': conversation.title,
          'model': conversation.model ?? 'default',
          'messages': conversation.messages
              .map((m) => {
                    'role': m.role.name,
                    'content': m.content,
                    'model': m.model,
                    'timestamp': m.timestamp.toIso8601String(),
                  })
              .toList(),
        };

        final postResponse = await _dio.post('/conversations',
            data: postBody, options: Options(headers: headers));

        if (postResponse.statusCode != 201) {
          throw Exception(
              'Failed to save conversation: ${postResponse.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('[ConversationStorage] Error saving conversation via API: $e');
      // Do not rethrow, to prevent app crash on startup when not logged in
    }
  }

  /// Delete conversation via API (web platform)
  Future<void> _deleteConversationViaAPI(String conversationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.delete('/conversations/$conversationId',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        debugPrint(
            '[ConversationStorage] Deleted conversation via API: $conversationId');
      } else {
        throw Exception(
            'Failed to delete conversation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error deleting conversation via API: $e');
      // Do not rethrow
    }
  }

  /// Insert a conversation into the database
  Future<void> _insertConversation(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    await txn.insert(
        _conversationsTable,
        {
          'id': conversation.id,
          'title': conversation.title,
          'model': conversation.model,
          'created_at': conversation.createdAt.millisecondsSinceEpoch,
          'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert messages for a conversation
  Future<void> _insertMessages(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    for (final message in conversation.messages) {
      await txn.insert(
          _messagesTable,
          {
            'id': message.id,
            'conversation_id': conversation.id,
            'role': message.role.name,
            'content': message.content,
            'model': message.model,
            'status': message.status.name,
            'error': message.error,
            'timestamp': message.timestamp.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Load a conversation with its messages
  Future<Conversation> _loadConversationWithMessages(
    Map<String, dynamic> conversationRow,
  ) async {
    final conversationId = conversationRow['id'] as String;

    // Load messages for this conversation
    final messageRows = await _database!.query(
      _messagesTable,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );

    final messages = messageRows.map((row) => _messageFromRow(row)).toList();

    return Conversation(
      id: conversationId,
      title: conversationRow['title'] as String,
      model: conversationRow['model'] as String,
      messages: messages,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        conversationRow['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        conversationRow['updated_at'] as int,
      ),
    );
  }

  /// Create a Message from database row
  Message _messageFromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      role: MessageRole.values.firstWhere(
        (role) => role.name == row['role'],
        orElse: () => MessageRole.user,
      ),
      content: row['content'] as String,
      model: row['model'] as String?,
      status: MessageStatus.values.firstWhere(
        (status) => status.name == row['status'],
        orElse: () => MessageStatus.sent,
      ),
      error: row['error'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }

  /// Check if the service is properly initialized
  bool get isInitialized =>
      kIsWeb ? _isInitialized : (_isInitialized && _database != null);

  /// Get current storage location setting
  Future<String> getStorageLocation() async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      final result = await _database!.query(
        _settingsTable,
        where: 'key = ?',
        whereArgs: ['storage_location'],
      );

      if (result.isNotEmpty) {
        return result.first['value'] as String;
      }
      return 'local_only'; // Default
    } catch (e) {
      debugPrint('� [ConversationStorage] Failed to get storage location: $e');
      return 'local_only'; // Safe default
    }
  }

  /// Update storage location setting
  Future<void> setStorageLocation(String location) async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.insert(
          _settingsTable,
          {
            'key': 'storage_location',
            'value': location,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint(
        '� [ConversationStorage] Storage location updated to: $location',
      );
    } catch (e) {
      debugPrint(
        '� [ConversationStorage] Failed to update storage location: $e',
      );
      rethrow;
    }
  }

  /// Get database statistics for privacy transparency
  Future<Map<String, dynamic>> getDatabaseStats() async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      // Count conversations
      final conversationCount = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $_conversationsTable',
      );
      final totalConversations = conversationCount.first['count'] as int;

      // Count messages
      final messageCount = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $_messagesTable',
      );
      final totalMessages = messageCount.first['count'] as int;

      // Get database file size (approximate)
      String databaseSize = 'Unknown';
      try {
        final dbPath = await _getDatabasePath();
        if (!kIsWeb) {
          final file = File(dbPath);
          if (await file.exists()) {
            final bytes = await file.length();
            databaseSize = _formatBytes(bytes);
          }
        } else {
          databaseSize = 'Cloud Storage (PostgreSQL)';
        }
      } catch (e) {
        debugPrint('� [ConversationStorage] Failed to get database size: $e');
      }

      return {
        'total_conversations': totalConversations,
        'total_messages': totalMessages,
        'database_size': databaseSize,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('� [ConversationStorage] Failed to get database stats: $e');
      rethrow;
    }
  }

  /// Export all conversations for backup
  Future<Map<String, dynamic>> exportConversations() async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      final conversations = await loadConversations();

      return {
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'export_metadata': {
          'export_timestamp': DateTime.now().toIso8601String(),
          'total_conversations': conversations.length,
          'total_messages': conversations.fold<int>(
            0,
            (sum, conv) => sum + conv.messages.length,
          ),
          'database_version': _databaseVersion,
        },
      };
    } catch (e) {
      debugPrint('� [ConversationStorage] Failed to export conversations: $e');
      rethrow;
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Enable encryption for stored conversations
  Future<void> setEncryptionEnabled(bool enabled) async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      _encryptionEnabled = enabled;

      // Update encryption setting in database
      await _database!.insert(
          _settingsTable,
          {
            'key': 'encryption_enabled',
            'value': enabled ? 'true' : 'false',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      debugPrint(
        '� [ConversationStorage] Encryption ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('� [ConversationStorage] Failed to set encryption: $e');
      rethrow;
    }
  }

  /// Get current encryption status
  Future<bool> isEncryptionEnabled() async {
    if (!isInitialized) {
      return false;
    }

    try {
      final result = await _database!.query(
        _settingsTable,
        where: 'key = ?',
        whereArgs: ['encryption_enabled'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final value = result.first['value'] as String;
        _encryptionEnabled = value == 'true';
        return _encryptionEnabled;
      }

      return false;
    } catch (e) {
      debugPrint(
        '� [ConversationStorage] Failed to get encryption status: $e',
      );
      return false;
    }
  }

  /// Close the database connection
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
    debugPrint('� [ConversationStorage] Service disposed');
  }
}

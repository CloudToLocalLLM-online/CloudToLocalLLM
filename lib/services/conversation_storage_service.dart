import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/conversation.dart';
import '../models/message.dart';

/// Privacy-first conversation storage service with platform-specific database initialization
///
/// PRIVACY POLICY:
/// - All conversations are stored ONLY on the user's device
/// - Web platform: Uses IndexedDB for persistent browser storage
/// - Desktop platform: Uses SQLite files in user documents directory
/// - NO conversation data is transmitted to cloud servers
/// - Data remains device-bound unless explicitly exported by user
class ConversationStorageService {
  static const String _databaseName = 'cloudtolocalllm_conversations.db';
  static const int _databaseVersion = 2; // Incremented for privacy enhancements

  // Table names
  static const String _conversationsTable = 'conversations';
  static const String _messagesTable = 'messages';
  static const String _settingsTable = 'user_settings';

  Database? _database;
  bool _isInitialized = false;

  /// Initialize the storage service with platform-specific database factory
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('💾 [ConversationStorage] Already initialized, skipping');
      return;
    }

    try {
      // Initialize sqflite for different platforms
      if (kIsWeb) {
        // For web platform, use the default factory (IndexedDB)
        // No additional initialization needed - sqflite automatically uses IndexedDB
        debugPrint('💾 [ConversationStorage] Using IndexedDB for web platform');
        debugPrint(
          '💾 [ConversationStorage] Privacy: Data stored in browser IndexedDB only',
        );
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use FFI implementation
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        debugPrint(
          '💾 [ConversationStorage] Using SQLite FFI for desktop platform',
        );
        debugPrint(
          '💾 [ConversationStorage] Privacy: Data stored in local SQLite file only',
        );
      } else {
        // For mobile platforms, use default factory
        debugPrint(
          '💾 [ConversationStorage] Using default SQLite for mobile platform',
        );
        debugPrint(
          '💾 [ConversationStorage] Privacy: Data stored in device SQLite only',
        );
      }

      await _initializeDatabase();
      _isInitialized = true;
      debugPrint('💾 [ConversationStorage] Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('💾 [ConversationStorage] Failed to initialize: $e');
      debugPrint('💾 [ConversationStorage] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize the database with enhanced privacy features
  Future<void> _initializeDatabase() async {
    try {
      final databasePath = await _getDatabasePath();
      debugPrint('💾 [ConversationStorage] Database path: $databasePath');

      _database = await openDatabase(
        databasePath,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      debugPrint('💾 [ConversationStorage] Database opened successfully');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Database initialization failed: $e');
      rethrow;
    }
  }

  /// Get the database file path with platform-specific handling
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // For web, use a simple path (IndexedDB will be used internally)
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
          '💾 [ConversationStorage] Created app directory: ${appDirectory.path}',
        );
      }

      return join(appDirectory.path, _databaseName);
    } catch (e) {
      debugPrint(
        '💾 [ConversationStorage] Failed to get documents directory: $e',
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
        '💾 [ConversationStorage] Database tables created with privacy features',
      );
    } catch (e) {
      debugPrint(
        '💾 [ConversationStorage] Failed to create database tables: $e',
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

    debugPrint('💾 [ConversationStorage] Default privacy settings inserted');
  }

  /// Upgrade database schema
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      '💾 [ConversationStorage] Upgrading database from v$oldVersion to v$newVersion',
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
          '💾 [ConversationStorage] Privacy enhancements added to database',
        );
      } catch (e) {
        debugPrint('💾 [ConversationStorage] Database upgrade failed: $e');
        // Continue with existing schema if upgrade fails
      }
    }
  }

  /// Save a list of conversations
  Future<void> saveConversations(List<Conversation> conversations) async {
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
        '💾 [ConversationStorage] Saved ${conversations.length} conversations',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error saving conversations: $e');
      rethrow;
    }
  }

  /// Load all conversations
  Future<List<Conversation>> loadConversations() async {
    if (_database == null) {
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
        '💾 [ConversationStorage] Loaded ${conversations.length} conversations',
      );
      return conversations;
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error loading conversations: $e');
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
        '💾 [ConversationStorage] Saved conversation: ${conversation.title}',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error saving conversation: $e');
      rethrow;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
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
        '💾 [ConversationStorage] Deleted conversation: $conversationId',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await txn.delete(_messagesTable);
        await txn.delete(_conversationsTable);
      });

      debugPrint('💾 [ConversationStorage] Cleared all conversations');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error clearing conversations: $e');
      rethrow;
    }
  }

  /// Insert a conversation into the database
  Future<void> _insertConversation(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    await txn.insert(_conversationsTable, {
      'id': conversation.id,
      'title': conversation.title,
      'model': conversation.model,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert messages for a conversation
  Future<void> _insertMessages(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    for (final message in conversation.messages) {
      await txn.insert(_messagesTable, {
        'id': message.id,
        'conversation_id': conversation.id,
        'role': message.role.name,
        'content': message.content,
        'model': message.model,
        'status': message.status.name,
        'error': message.error,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  bool get isInitialized => _isInitialized && _database != null;

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
      debugPrint('💾 [ConversationStorage] Failed to get storage location: $e');
      return 'local_only'; // Safe default
    }
  }

  /// Update storage location setting
  Future<void> setStorageLocation(String location) async {
    if (!isInitialized) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.insert(_settingsTable, {
        'key': 'storage_location',
        'value': location,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint(
        '💾 [ConversationStorage] Storage location updated to: $location',
      );
    } catch (e) {
      debugPrint(
        '💾 [ConversationStorage] Failed to update storage location: $e',
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
          databaseSize = 'IndexedDB';
        }
      } catch (e) {
        debugPrint('💾 [ConversationStorage] Failed to get database size: $e');
      }

      return {
        'total_conversations': totalConversations,
        'total_messages': totalMessages,
        'database_size': databaseSize,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Failed to get database stats: $e');
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
      debugPrint('💾 [ConversationStorage] Failed to export conversations: $e');
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

  /// Close the database connection
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
    debugPrint('💾 [ConversationStorage] Service disposed');
  }
}

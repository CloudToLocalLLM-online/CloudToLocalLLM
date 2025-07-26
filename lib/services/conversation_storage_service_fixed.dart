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
        debugPrint('💾 [ConversationStorage] Privacy: Data stored in browser IndexedDB only');
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use FFI implementation
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        debugPrint('💾 [ConversationStorage] Using SQLite FFI for desktop platform');
        debugPrint('💾 [ConversationStorage] Privacy: Data stored in local SQLite file only');
      } else {
        // For mobile platforms, use default factory
        debugPrint('💾 [ConversationStorage] Using default SQLite for mobile platform');
        debugPrint('💾 [ConversationStorage] Privacy: Data stored in device SQLite only');
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
        debugPrint('💾 [ConversationStorage] Created app directory: ${appDirectory.path}');
      }

      return join(appDirectory.path, _databaseName);
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Failed to get documents directory: $e');
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

      debugPrint('💾 [ConversationStorage] Database tables created with privacy schema');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Failed to create database: $e');
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
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('💾 [ConversationStorage] Upgrading database from v$oldVersion to v$newVersion');
    
    if (oldVersion < 2) {
      // Add privacy columns to existing tables
      try {
        await db.execute('ALTER TABLE $_conversationsTable ADD COLUMN is_encrypted INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE $_conversationsTable ADD COLUMN storage_location TEXT DEFAULT "local"');
        await db.execute('ALTER TABLE $_messagesTable ADD COLUMN is_encrypted INTEGER DEFAULT 0');
        
        // Create settings table if it doesn't exist
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        
        await _insertDefaultPrivacySettings(db);
        debugPrint('💾 [ConversationStorage] Privacy enhancements added to database');
      } catch (e) {
        debugPrint('💾 [ConversationStorage] Database upgrade failed: $e');
        // Continue with existing schema if upgrade fails
      }
    }
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
      await _database!.insert(
        _settingsTable,
        {
          'key': 'storage_location',
          'value': location,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('💾 [ConversationStorage] Storage location updated to: $location');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Failed to update storage location: $e');
      rethrow;
    }
  }

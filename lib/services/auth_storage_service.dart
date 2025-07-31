import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

/// SQLite-based authentication storage service with web support
/// Uses SQLite with FFI for all platforms including web
class AuthStorageService {
  static Database? _database;
  static const String _dbName = 'cloudtolocalllm_auth.db';
  static const String _tableName = 'auth_tokens';
  static bool _initialized = false;

  /// Initialize SQLite for web platform with timeout
  static Future<void> _initializeSQLite() async {
    if (_initialized) return;

    try {
      print('🗄️ [DEBUG] Starting SQLite initialization...');

      // Add timeout to prevent hanging
      await Future(() async {
        if (kIsWeb) {
          print(
            '🗄️ [DEBUG] Detected web platform, using databaseFactoryFfiWeb',
          );
          databaseFactory = databaseFactoryFfiWeb;
        } else {
          print(
            '🗄️ [DEBUG] Detected native platform, using databaseFactoryFfi',
          );
          databaseFactory = databaseFactoryFfi;
        }
      }).timeout(Duration(seconds: 3));

      _initialized = true;
      print('🗄️ [DEBUG] SQLite initialization complete successfully');
    } catch (e) {
      print('🗄️ [DEBUG] SQLite initialization failed: $e');
      _initialized = false;
      rethrow;
    }
  }

  /// Get the database instance
  static Future<Database> get database async {
    await _initializeSQLite();
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the SQLite database with timeout
  static Future<Database> _initDatabase() async {
    try {
      print('🗄️ [DEBUG] Getting database path...');
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      print('🗄️ [DEBUG] Opening database at: $path');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      ).timeout(Duration(seconds: 10));
    } catch (e) {
      print('🗄️ [DEBUG] Error initializing database: $e');
      rethrow;
    }
  }

  /// Create database tables
  static Future<void> _createTables(Database db, int version) async {
    try {
      debugPrint('🗄️ [AuthStorage] Creating auth_tokens table');

      await db.execute('''
        CREATE TABLE $_tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          access_token TEXT NOT NULL,
          id_token TEXT,
          refresh_token TEXT,
          token_type TEXT DEFAULT 'Bearer',
          expires_at INTEGER NOT NULL,
          scope TEXT,
          audience TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      debugPrint('🗄️ [AuthStorage] Database tables created successfully');
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error creating tables: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      '🗄️ [AuthStorage] Upgrading database from $oldVersion to $newVersion',
    );
    // Add migration logic here if needed in the future
  }

  /// Store authentication tokens with timeout
  static Future<void> storeTokens({
    required String accessToken,
    String? idToken,
    String? refreshToken,
    required DateTime expiresAt,
    String? scope,
    String? audience,
  }) async {
    try {
      print('🗄️ [DEBUG] Starting storeTokens operation...');

      // Add timeout to entire operation
      await (() async {
        final db = await database;
        final now = DateTime.now().millisecondsSinceEpoch;

        print('🗄️ [DEBUG] Database obtained, clearing existing tokens...');

        // Clear existing tokens first
        await db.delete(_tableName);

        print('🗄️ [DEBUG] Inserting new tokens...');

        // Insert new tokens
        await db.insert(_tableName, {
          'access_token': accessToken,
          'id_token': idToken,
          'refresh_token': refreshToken,
          'token_type': 'Bearer',
          'expires_at': expiresAt.millisecondsSinceEpoch,
          'scope': scope,
          'audience': audience,
          'created_at': now,
          'updated_at': now,
        });
      })().timeout(Duration(seconds: 5));

      print('🗄️ [DEBUG] Tokens stored successfully in SQLite');
    } catch (e) {
      print('🗄️ [DEBUG] Error storing tokens in SQLite: $e');
      rethrow;
    }
  }

  /// Load stored authentication tokens
  static Future<Map<String, dynamic>?> loadTokens() async {
    try {
      final db = await database;

      debugPrint('🗄️ [AuthStorage] Loading stored tokens');

      final results = await db.query(
        _tableName,
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (results.isEmpty) {
        debugPrint('🗄️ [AuthStorage] No stored tokens found');
        return null;
      }

      final tokenData = results.first;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        tokenData['expires_at'] as int,
      );

      // Check if token is expired
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('🗄️ [AuthStorage] Stored tokens are expired, clearing');
        await clearTokens();
        return null;
      }

      debugPrint('🗄️ [AuthStorage] Valid tokens loaded successfully');
      return {
        'access_token': tokenData['access_token'],
        'id_token': tokenData['id_token'],
        'refresh_token': tokenData['refresh_token'],
        'token_type': tokenData['token_type'],
        'expires_at': expiresAt,
        'scope': tokenData['scope'],
        'audience': tokenData['audience'],
      };
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error loading tokens: $e');
      return null;
    }
  }

  /// Clear all stored tokens
  static Future<void> clearTokens() async {
    try {
      final db = await database;

      debugPrint('🗄️ [AuthStorage] Clearing stored tokens');

      await db.delete(_tableName);

      debugPrint('🗄️ [AuthStorage] Tokens cleared successfully');
    } catch (e) {
      debugPrint('🗄️ [AuthStorage] Error clearing tokens: $e');
    }
  }

  /// Check if valid tokens exist
  static Future<bool> hasValidTokens() async {
    try {
      print('🗄️ [DEBUG] Checking if valid tokens exist...');
      final tokens = await loadTokens();
      final hasTokens = tokens != null;
      print('🗄️ [DEBUG] Valid tokens exist: $hasTokens');
      return hasTokens;
    } catch (e) {
      print('🗄️ [DEBUG] Error checking valid tokens: $e');
      return false;
    }
  }

  /// Get access token if valid
  static Future<String?> getAccessToken() async {
    final tokens = await loadTokens();
    return tokens?['access_token'];
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('🗄️ [AuthStorage] Database connection closed');
    }
  }
}

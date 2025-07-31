import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Simple key-value storage using SQLite that works on web
class SimpleStorageService {
  static Database? _database;
  static const String _dbName = 'simple_storage.db';
  static const String _tableName = 'key_value_store';
  static bool _initialized = false;

  /// Initialize SQLite
  static Future<void> _initializeSQLite() async {
    if (_initialized) return;
    
    try {
      print('🗄️ [DEBUG] Initializing simple SQLite storage...');
      
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfiWeb;
      } else {
        databaseFactory = databaseFactoryFfi;
      }
      
      _initialized = true;
      print('🗄️ [DEBUG] Simple SQLite storage initialized');
    } catch (e) {
      print('🗄️ [DEBUG] Simple SQLite initialization failed: $e');
      rethrow;
    }
  }

  /// Get database instance
  static Future<Database> get database async {
    await _initializeSQLite();
    if (_database != null) return _database!;
    
    try {
      print('🗄️ [DEBUG] Creating simple database...');
      
      _database = await openDatabase(
        ':memory:', // Use in-memory database for web compatibility
        version: 1,
        onCreate: (db, version) async {
          print('🗄️ [DEBUG] Creating simple key-value table...');
          await db.execute('''
            CREATE TABLE $_tableName (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ).timeout(Duration(seconds: 5));
      
      print('🗄️ [DEBUG] Simple database created successfully');
      return _database!;
    } catch (e) {
      print('🗄️ [DEBUG] Error creating simple database: $e');
      rethrow;
    }
  }

  /// Store a value
  static Future<void> store(String key, Map<String, dynamic> value) async {
    try {
      print('🗄️ [DEBUG] Storing key: $key');
      
      final db = await database;
      final jsonValue = json.encode(value);
      
      await db.insert(
        _tableName,
        {
          'key': key,
          'value': jsonValue,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ).timeout(Duration(seconds: 3));
      
      print('🗄️ [DEBUG] Successfully stored key: $key');
    } catch (e) {
      print('🗄️ [DEBUG] Error storing key $key: $e');
      rethrow;
    }
  }

  /// Retrieve a value
  static Future<Map<String, dynamic>?> retrieve(String key) async {
    try {
      print('🗄️ [DEBUG] Retrieving key: $key');
      
      final db = await database;
      final results = await db.query(
        _tableName,
        where: 'key = ?',
        whereArgs: [key],
      ).timeout(Duration(seconds: 3));
      
      if (results.isEmpty) {
        print('🗄️ [DEBUG] Key not found: $key');
        return null;
      }
      
      final jsonValue = results.first['value'] as String;
      final value = json.decode(jsonValue) as Map<String, dynamic>;
      
      print('🗄️ [DEBUG] Successfully retrieved key: $key');
      return value;
    } catch (e) {
      print('🗄️ [DEBUG] Error retrieving key $key: $e');
      return null;
    }
  }

  /// Delete a value
  static Future<void> delete(String key) async {
    try {
      print('🗄️ [DEBUG] Deleting key: $key');
      
      final db = await database;
      await db.delete(
        _tableName,
        where: 'key = ?',
        whereArgs: [key],
      ).timeout(Duration(seconds: 3));
      
      print('🗄️ [DEBUG] Successfully deleted key: $key');
    } catch (e) {
      print('🗄️ [DEBUG] Error deleting key $key: $e');
    }
  }

  /// Check if a key exists and is valid
  static Future<bool> hasValidToken() async {
    try {
      final tokenData = await retrieve('auth_tokens');
      if (tokenData == null) return false;
      
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(tokenData['expires_at']);
      final isValid = DateTime.now().isBefore(expiresAt);
      
      print('🗄️ [DEBUG] Token validity check: $isValid');
      return isValid;
    } catch (e) {
      print('🗄️ [DEBUG] Error checking token validity: $e');
      return false;
    }
  }
}

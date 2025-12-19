import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_storage_service.dart';
import '../di/locator.dart' as di;

class TokenStorageService {
  static Database? _database;
  static const String _tableName = 'auth_tokens';
  static final _secureStorage = const FlutterSecureStorage();
  static encrypt.Encrypter? _encrypter;
  static encrypt.IV? _iv;
  SessionStorageService? _sessionStorage;

  Future<void> init() async {
    if (_database != null) return;

    // Try to get SessionStorageService from locator
    try {
      _sessionStorage = di.serviceLocator.get<SessionStorageService>();
    } catch (e) {
      debugPrint(
          '[TokenStorageService] SessionStorageService not found in locator');
    }

    if (kIsWeb) {
      // On web, we use flutter_secure_storage directly for tokens
      // No SQLite initialization needed
      await _initEncryption();
      return;
    }

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = join(await getDatabasesPath(), 'auth_tokens.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    await _initEncryption();
  }

  Future<void> _initEncryption() async {
    String? keyStr = await _secureStorage.read(key: 'auth_encryption_key');
    if (keyStr == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      keyStr = key.base64;
      await _secureStorage.write(key: 'auth_encryption_key', value: keyStr);
    }

    final key = encrypt.Key.fromBase64(keyStr);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
    _iv = encrypt.IV.fromLength(
        16); // Static IV for simplicity in this context, or store per record
  }

  Future<void> saveToken(String key, String value) async {
    // If we have an active session, sync to PostgreSQL
    if (_sessionStorage?.currentSession != null) {
      final session = _sessionStorage!.currentSession!;
      try {
        await _sessionStorage!.syncTokens(
          sessionToken: session.token,
          accessToken: key == 'access_token' ? value : session.accessToken,
          idToken: key == 'id_token' ? value : session.idToken,
          refreshToken: key == 'refresh_token' ? value : session.refreshToken,
        );
      } catch (e) {
        debugPrint(
            '[TokenStorageService] Failed to sync token $key to PostgreSQL: $e');
      }
    }

    if (kIsWeb) {
      if (_encrypter == null) await init();
      final encrypted = _encrypter!.encrypt(value, iv: _iv);
      await _secureStorage.write(key: 'token_$key', value: encrypted.base64);
      return;
    }

    if (_database == null) await init();

    final encrypted = _encrypter!.encrypt(value, iv: _iv);
    final now = DateTime.now().toIso8601String();

    await _database!.insert(
      _tableName,
      {
        'key': key,
        'value': encrypted.base64,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getToken(String key) async {
    // Try to get from PostgreSQL session first
    if (_sessionStorage?.currentSession != null) {
      final session = _sessionStorage!.currentSession!;
      if (key == 'access_token') return session.accessToken;
      if (key == 'id_token') return session.idToken;
      if (key == 'refresh_token') return session.refreshToken;
    }

    if (kIsWeb) {
      if (_encrypter == null) await init();
      final encryptedStr = await _secureStorage.read(key: 'token_$key');
      if (encryptedStr == null) return null;
      try {
        return _encrypter!.decrypt64(encryptedStr, iv: _iv);
      } catch (e) {
        debugPrint(
            '[TokenStorageService] Decryption failed for key: $key - $e');
        return null;
      }
    }

    if (_database == null) await init();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;

    final encryptedStr = maps.first['value'] as String;
    try {
      return _encrypter!.decrypt64(encryptedStr, iv: _iv);
    } catch (e) {
      debugPrint('[TokenStorageService] Decryption failed for key: $key - $e');
      return null;
    }
  }

  Future<void> deleteToken(String key) async {
    if (kIsWeb) {
      await _secureStorage.delete(key: 'token_$key');
      return;
    }

    if (_database == null) await init();
    await _database!.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      // Clear known tokens
      await _secureStorage.delete(key: 'token_access_token');
      await _secureStorage.delete(key: 'token_id_token');
      await _secureStorage.delete(key: 'token_refresh_token');
      return;
    }

    if (_database == null) await init();
    await _database!.delete(_tableName);
  }
}

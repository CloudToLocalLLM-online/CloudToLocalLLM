import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  static Database? _database;
  static const String _tableName = 'auth_tokens';
  static final _secureStorage = const FlutterSecureStorage();
  static encrypt.Encrypter? _encrypter;
  static encrypt.IV? _iv;

  Future<void> init() async {
    if (_database != null) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = kIsWeb
        ? 'auth_tokens.db'
        : join(await getDatabasesPath(), 'auth_tokens.db');

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
    if (_database == null) await init();
    await _database!.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> clearAll() async {
    if (_database == null) await init();
    await _database!.delete(_tableName);
  }
}

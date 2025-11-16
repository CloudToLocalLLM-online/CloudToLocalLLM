// Web-only stub - no database types needed
// These are never used on web since we use API instead
// This file prevents desktop modules from loading on web

/// Stub Database class for web
class Database {
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      throw UnimplementedError('Database not available on web');
  Future<int> insert(String table, Map<String, Object?> values,
          {ConflictAlgorithm? conflictAlgorithm}) async =>
      throw UnimplementedError('Database not available on web');
  Future<List<Map<String, Object?>>> query(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset}) async =>
      throw UnimplementedError('Database not available on web');
  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<Object?>? arguments]) async =>
      throw UnimplementedError('Database not available on web');
  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) action,
          {bool? exclusive}) async =>
      throw UnimplementedError('Database not available on web');
  Future<void> close() async =>
      throw UnimplementedError('Database not available on web');
}

/// Stub DatabaseExecutor class for web
class DatabaseExecutor {
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      throw UnimplementedError('Database not available on web');
  Future<int> insert(String table, Map<String, Object?> values,
          {ConflictAlgorithm? conflictAlgorithm}) async =>
      throw UnimplementedError('Database not available on web');
  Future<int> delete(String table,
          {String? where, List<Object?>? whereArgs}) async =>
      throw UnimplementedError('Database not available on web');
  Future<List<Map<String, Object?>>> query(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset}) async =>
      throw UnimplementedError('Database not available on web');
  Future<Map<String, Object?>> first() async =>
      throw UnimplementedError('Database not available on web');
}

/// Stub Directory class for web
class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async =>
      throw UnimplementedError('Directory not available on web');
  Future<Directory> create({bool recursive = false}) async =>
      throw UnimplementedError('Directory not available on web');
}

/// Stub File class for web
class File {
  final String path;
  File(this.path);

  Future<bool> exists() async =>
      throw UnimplementedError('File not available on web');
  Future<int> length() async =>
      throw UnimplementedError('File not available on web');
}

enum ConflictAlgorithm { replace }

// Stub functions that should never be called on web
Future<Directory> getApplicationDocumentsDirectory() async =>
    throw UnimplementedError('Not available on web');
String join(String part1, String part2, [String? part3]) =>
    throw UnimplementedError('Not available on web');
Future<Database> openDatabase(String path,
        {int? version,
        void Function(Database, int)? onCreate,
        void Function(Database, int, int)? onUpgrade,
        bool? singleInstance}) async =>
    throw UnimplementedError('Not available on web');

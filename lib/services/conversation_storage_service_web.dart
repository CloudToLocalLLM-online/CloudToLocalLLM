// Web-only stub - no database types needed
// These are never used on web since we use API instead
// This file prevents desktop modules from loading on web

class Database {}
class DatabaseExecutor {}
class Directory {}
class File {}
enum ConflictAlgorithm { replace }

// Stub functions that should never be called on web
Future<Directory> getApplicationDocumentsDirectory() async => throw UnimplementedError('Not available on web');
String join(String part1, String part2, [String? part3]) => throw UnimplementedError('Not available on web');
Future<Database> openDatabase(String path, {int? version, void Function(Database, int)? onCreate, void Function(Database, int, int)? onUpgrade, bool? singleInstance}) => throw UnimplementedError('Not available on web');


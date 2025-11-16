// Desktop-only imports - only loaded on desktop platforms
// These imports are re-exported below, so they're actually used
// ignore_for_file: unused_import

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io' as io;

// Re-export all needed types and functions for desktop
export 'package:path/path.dart' show join;
export 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
export 'package:sqflite/sqflite.dart'
    show Database, DatabaseExecutor, ConflictAlgorithm, openDatabase;
export 'dart:io' show Directory, File;

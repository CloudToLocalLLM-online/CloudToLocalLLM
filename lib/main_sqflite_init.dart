import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initSqflite() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

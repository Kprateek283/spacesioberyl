import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  // Try default path
  String dbPath = await databaseFactory.getDatabasesPath();
  String path = join(dbPath, 'studio_crm.db');
  
  if (!File(path).existsSync()) {
      path = join(Directory.current.path, '.dart_tool', 'sqflite_common_ffi', 'databases', 'studio_crm.db');
  }

  print('Looking for DB at: $path');
  if (!File(path).existsSync()) {
      print('DB not found!');
      return;
  }

  var db = await databaseFactory.openDatabase(path);
  
  try {
    var outbox = await db.query('outbox_queue');
    print('Outbox queue count: ${outbox.length}');
    for (var r in outbox) {
      print(r);
    }
  } catch (e) {
    print('Error querying outbox_queue: $e');
  }
  
  try {
    var leads = await db.query('leads');
    print('Leads count: ${leads.length}');
  } catch (e) {
    print('Error querying leads: $e');
  }

  await db.close();
}

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Web in-memory caches
  static final Map<String, List<Map<String, dynamic>>> _webCaches = {};
  static final List<Map<String, dynamic>> _webOutboxQueue = [];
  static int _webOutboxIdCounter = 1;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError("sqflite database is not supported on Web.");
    }
    if (_database != null) return _database!;
    _database = await _initDB('studio_crm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.macOS || 
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Vendors Cache
    await db.execute('''
      CREATE TABLE vendors(
        id INTEGER PRIMARY KEY,
        company_name TEXT NOT NULL,
        phone TEXT,
        contact_person TEXT,
        email TEXT,
        default_payment_mode TEXT
      )
    ''');

    // Installers Cache
    await db.execute('''
      CREATE TABLE installers(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        expertise_area TEXT,
        standard_rate REAL,
        preferred_payment_mode TEXT
      )
    ''');

    // Leads Cache
    await db.execute('''
      CREATE TABLE leads(
        id INTEGER PRIMARY KEY,
        client_name TEXT NOT NULL,
        client_phone TEXT,
        client_email TEXT,
        source TEXT,
        status TEXT,
        assigned_to INTEGER
      )
    ''');

    // Outbox Queue for offline mutations
    await db.execute('''
      CREATE TABLE outbox_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        payload TEXT NOT NULL,
        has_file INTEGER NOT NULL DEFAULT 0,
        local_file_path TEXT,
        file_field_key TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createAttendanceCacheTable(db);
    await _createLeavesCacheTable(db);
    await _createExpensesCacheTable(db);
    await _createSiteUpdatesCacheTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await _createAttendanceCacheTable(db);
      await _createLeavesCacheTable(db);
      await _createExpensesCacheTable(db);
      await _createSiteUpdatesCacheTable(db);
    }
    if (oldVersion < 5) {
      // Add missing CRM/Logistics tables for older databases
      await db.execute('''
        CREATE TABLE IF NOT EXISTS leads(
          id INTEGER PRIMARY KEY,
          client_name TEXT NOT NULL,
          client_phone TEXT,
          client_email TEXT,
          source TEXT,
          status TEXT,
          assigned_to INTEGER
        )
      ''');
    }
  }

  Future<void> _createAttendanceCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_cache(
        id INTEGER PRIMARY KEY,
        date TEXT,
        check_in_time TEXT,
        check_out_time TEXT,
        status TEXT,
        reason TEXT
      )
    ''');
  }

  Future<void> _createLeavesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaves_cache(
        id INTEGER PRIMARY KEY,
        leave_type TEXT,
        start_date TEXT,
        end_date TEXT,
        reason TEXT,
        status TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _createSiteUpdatesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS site_updates_cache(
        local_id TEXT PRIMARY KEY,
        job_id INTEGER NOT NULL,
        notes TEXT,
        update_time TEXT,
        photo_url TEXT
      )
    ''');
  }

  Future<void> _createExpensesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses_cache(
        id INTEGER PRIMARY KEY,
        amount REAL,
        person_paid TEXT,
        context TEXT,
        expense_date TEXT,
        receipt_url TEXT
      )
    ''');
  }

  // --- Caching Methods ---

  Future<void> cacheVendors(List<dynamic> vendors) async {
    if (kIsWeb) {
      _webCaches['vendors'] = vendors.map((vendor) => {
        'id': vendor['id'],
        'company_name': vendor['company_name'],
        'phone': vendor['phone'],
        'contact_person': vendor['contact_person'],
        'email': vendor['email'],
        'default_payment_mode': vendor['default_payment_mode'],
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('vendors'); // Clear old cache
      for (var vendor in vendors) {
        await txn.insert('vendors', {
          'id': vendor['id'],
          'company_name': vendor['company_name'],
          'phone': vendor['phone'],
          'contact_person': vendor['contact_person'],
          'email': vendor['email'],
          'default_payment_mode': vendor['default_payment_mode'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedVendors() async {
    if (kIsWeb) {
      return _webCaches['vendors'] ?? [];
    }
    final db = await instance.database;
    return await db.query('vendors');
  }

  Future<void> cacheInstallers(List<dynamic> installers) async {
    if (kIsWeb) {
      _webCaches['installers'] = installers.map((installer) => {
        'id': installer['id'],
        'name': installer['name'],
        'phone': installer['phone'],
        'expertise_area': installer['expertise_area'],
        'standard_rate': installer['standard_rate'],
        'preferred_payment_mode': installer['preferred_payment_mode'],
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('installers');
      for (var installer in installers) {
        await txn.insert('installers', {
          'id': installer['id'],
          'name': installer['name'],
          'phone': installer['phone'],
          'expertise_area': installer['expertise_area'],
          'standard_rate': installer['standard_rate'],
          'preferred_payment_mode': installer['preferred_payment_mode'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedInstallers() async {
    if (kIsWeb) {
      return _webCaches['installers'] ?? [];
    }
    final db = await instance.database;
    return await db.query('installers');
  }

  Future<void> cacheLeads(List<dynamic> leads) async {
    if (kIsWeb) {
      _webCaches['leads'] = leads.map((lead) => {
        'id': lead['id'],
        'client_name': lead['client_name'],
        'client_phone': lead['client_phone'],
        'client_email': lead['client_email'],
        'source': lead['source'],
        'status': lead['status'],
        'assigned_to': lead['assigned_to'],
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('leads');
      for (var lead in leads) {
        await txn.insert('leads', {
          'id': lead['id'],
          'client_name': lead['client_name'],
          'client_phone': lead['client_phone'],
          'client_email': lead['client_email'],
          'source': lead['source'],
          'status': lead['status'],
          'assigned_to': lead['assigned_to'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedLeads() async {
    if (kIsWeb) {
      return _webCaches['leads'] ?? [];
    }
    final db = await instance.database;
    return await db.query('leads', orderBy: 'id DESC');
  }

  Future<void> cacheAttendance(List<dynamic> rows) async {
    if (kIsWeb) {
      _webCaches['attendance_cache'] = rows.map((row) => {
        'id': row['id'],
        'date': row['date'],
        'check_in_time': row['check_in_time'],
        'check_out_time': row['check_out_time'],
        'status': row['status'],
        'reason': row['reason'] ?? row['override_reason'],
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('attendance_cache');
      for (var row in rows) {
        await txn.insert('attendance_cache', {
          'id': row['id'],
          'date': row['date'],
          'check_in_time': row['check_in_time'],
          'check_out_time': row['check_out_time'],
          'status': row['status'],
          'reason': row['reason'] ?? row['override_reason'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedAttendance() async {
    if (kIsWeb) {
      return _webCaches['attendance_cache'] ?? [];
    }
    final db = await instance.database;
    return await db.query('attendance_cache', orderBy: 'date DESC');
  }

  Future<void> cacheLeaves(List<dynamic> rows) async {
    if (kIsWeb) {
      _webCaches['leaves_cache'] = rows.map((row) => {
        'id': row['id'],
        'leave_type': row['leave_type'],
        'start_date': row['start_date'],
        'end_date': row['end_date'],
        'reason': row['reason'],
        'status': row['status'],
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('leaves_cache');
      for (var row in rows) {
        await txn.insert('leaves_cache', {
          'id': row['id'],
          'leave_type': row['leave_type'],
          'start_date': row['start_date'],
          'end_date': row['end_date'],
          'reason': row['reason'],
          'status': row['status'],
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedLeaves() async {
    if (kIsWeb) {
      return _webCaches['leaves_cache'] ?? [];
    }
    final db = await instance.database;
    return await db.query('leaves_cache', orderBy: 'start_date DESC');
  }

  Future<void> cacheExpenses(List<dynamic> rows) async {
    if (kIsWeb) {
      _webCaches['expenses_cache'] = rows.map((row) => {
        'id': row['id'],
        'amount': row['amount'],
        'person_paid': row['person_paid'],
        'context': row['context'],
        'expense_date': row['expense_date'],
        'receipt_url': row['receipt_url'],
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('expenses_cache');
      for (var row in rows) {
        await txn.insert('expenses_cache', {
          'id': row['id'],
          'amount': row['amount'],
          'person_paid': row['person_paid'],
          'context': row['context'],
          'expense_date': row['expense_date'],
          'receipt_url': row['receipt_url'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedExpenses() async {
    if (kIsWeb) {
      return _webCaches['expenses_cache'] ?? [];
    }
    final db = await instance.database;
    return await db.query('expenses_cache', orderBy: 'expense_date DESC');
  }

  Future<void> cacheSiteUpdates(int jobId, List<dynamic> rows) async {
    if (kIsWeb) {
      final key = 'site_updates_$jobId';
      _webCaches[key] = rows.map((row) {
        final localId = (row['local_id'] ?? row['id'] ?? '${jobId}_${row['update_time']}').toString();
        return {
          'local_id': localId,
          'job_id': row['installation_id'] ?? jobId,
          'notes': row['notes'],
          'update_time': row['update_time'],
          'photo_url': row['photo_url'],
        };
      }).toList();
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('site_updates_cache', where: 'job_id = ?', whereArgs: [jobId]);
      for (var row in rows) {
        final localId = (row['local_id'] ?? row['id'] ?? '${jobId}_${row['update_time']}').toString();
        await txn.insert('site_updates_cache', {
          'local_id': localId,
          'job_id': row['installation_id'] ?? jobId,
          'notes': row['notes'],
          'update_time': row['update_time'],
          'photo_url': row['photo_url'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> insertLocalSiteUpdate({
    required int jobId,
    required String localId,
    required String notes,
    required String updateTime,
    String? photoUrl,
  }) async {
    if (kIsWeb) {
      final key = 'site_updates_$jobId';
      final list = _webCaches[key] ?? [];
      list.add({
        'local_id': localId,
        'job_id': jobId,
        'notes': notes,
        'update_time': updateTime,
        'photo_url': photoUrl,
      });
      _webCaches[key] = list;
      return;
    }
    final db = await instance.database;
    await db.insert('site_updates_cache', {
      'local_id': localId,
      'job_id': jobId,
      'notes': notes,
      'update_time': updateTime,
      'photo_url': photoUrl,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedSiteUpdates(int jobId) async {
    if (kIsWeb) {
      final list = _webCaches['site_updates_$jobId'] ?? [];
      list.sort((a, b) => b['update_time'].toString().compareTo(a['update_time'].toString()));
      return list;
    }
    final db = await instance.database;
    return await db.query(
      'site_updates_cache',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'update_time DESC',
    );
  }

  // --- Outbox Queue Methods ---

  Future<int> queueMutation({
    required String endpoint,
    required String method,
    required String payload,
    bool hasFile = false,
    String? localFilePath,
    String? fileFieldKey,
  }) async {
    if (kIsWeb) {
      final id = _webOutboxIdCounter++;
      _webOutboxQueue.add({
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'has_file': hasFile ? 1 : 0,
        'local_file_path': localFilePath,
        'file_field_key': fileFieldKey,
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
      return id;
    }
    final db = await instance.database;
    return await db.insert('outbox_queue', {
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'has_file': hasFile ? 1 : 0,
      'local_file_path': localFilePath,
      'file_field_key': fileFieldKey,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    if (kIsWeb) {
      return List.from(_webOutboxQueue);
    }
    final db = await instance.database;
    return await db.query('outbox_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeMutation(int id) async {
    if (kIsWeb) {
      _webOutboxQueue.removeWhere((item) => item['id'] == id);
      return;
    }
    final db = await instance.database;
    await db.delete('outbox_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetryCount(int id) async {
    if (kIsWeb) {
      for (var item in _webOutboxQueue) {
        if (item['id'] == id) {
          item['retry_count'] = (item['retry_count'] as int) + 1;
          break;
        }
      }
      return;
    }
    final db = await instance.database;
    await db.rawUpdate('UPDATE outbox_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }
}

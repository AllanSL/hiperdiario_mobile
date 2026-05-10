import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/appointment.dart';
import '../models/medication.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hiperdiario.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE patients (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              cpf TEXT NOT NULL,
              birth_date TEXT,
              gender TEXT,
              diseases TEXT,
              phone TEXT,
              email TEXT,
              state_code TEXT,
              city_ibge TEXT,
              ubs_cnes TEXT,
              ubs_name TEXT,
              zip_code TEXT,
              street TEXT,
              number TEXT,
              neighborhood TEXT,
              complement TEXT,
              emergency_contact TEXT
            )
          ''');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const textType = 'TEXT';
    const boolType = 'BOOLEAN';
    const integerType = 'INTEGER';

    // Appointments Table
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        dateTime TEXT NOT NULL,
        location TEXT NOT NULL,
        specialty TEXT NOT NULL,
        professionalName TEXT,
        professionalId TEXT,
        shift TEXT NOT NULL,
        notes TEXT,
        attended INTEGER,
        status TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    // Medications Table
    await db.execute('''
      CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        times TEXT NOT NULL,
        stockUnits INTEGER NOT NULL,
        dispensationId TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    // Sync Queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        local_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Metadata Table
    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Patients Table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cpf TEXT NOT NULL,
        birth_date TEXT,
        gender TEXT,
        diseases TEXT,
        phone TEXT,
        email TEXT,
        state_code TEXT,
        city_ibge TEXT,
        ubs_cnes TEXT,
        ubs_name TEXT,
        zip_code TEXT,
        street TEXT,
        number TEXT,
        neighborhood TEXT,
        complement TEXT,
        emergency_contact TEXT
      )
    ''');
  }

  // --- CRUD Operations ---

  Future<void> saveAppointment(Appointment appt, {String syncStatus = 'synced'}) async {
    final db = await instance.database;
    final map = {
      'id': appt.id,
      'dateTime': appt.dateTime.toIso8601String(),
      'location': appt.location,
      'specialty': appt.specialty,
      'professionalName': appt.professionalName,
      'professionalId': appt.professionalId,
      'shift': appt.shift.dbValue,
      'notes': appt.notes,
      'attended': appt.attended == null ? null : (appt.attended! ? 1 : 0),
      'status': appt.status,
      'sync_status': syncStatus,
    };
    await db.insert('appointments', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Appointment>> getAllAppointments() async {
    final db = await instance.database;
    final result = await db.query('appointments', orderBy: 'dateTime ASC');
    return result.map((json) {
      final attended = json['attended'] as int?;
      return Appointment(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        location: json['location'] as String,
        specialty: json['specialty'] as String,
        professionalName: json['professionalName'] as String?,
        professionalId: json['professionalId'] as String?,
        shift: AppointmentShiftX.fromDb(json['shift'] as String?),
        notes: json['notes'] as String?,
        attended: attended == null ? null : (attended == 1),
        status: json['status'] as String?,
        syncStatus: json['sync_status'] as String? ?? 'synced',
      );
    }).toList();
  }

  Future<void> deleteAppointment(String id) async {
    final db = await instance.database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveMedication(Medication med, {String syncStatus = 'synced'}) async {
    final db = await instance.database;
    final map = {
      'id': med.id,
      'name': med.name,
      'dosage': med.dosage,
      'times': jsonEncode(med.times.map((t) => {'hour': t.hour, 'minute': t.minute}).toList()),
      'stockUnits': med.stockUnits,
      'dispensationId': med.dispensationId,
      'sync_status': syncStatus,
    };
    await db.insert('medications', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Medication>> getAllMedications() async {
    final db = await instance.database;
    final result = await db.query('medications', where: 'active = 1');
    return result.map((json) {
      final timesRaw = jsonDecode(json['times'] as String) as List;
      final times = timesRaw.map((t) => TimeOfDayLite(t['hour'], t['minute'])).toList();
      return Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        dosage: json['dosage'] as String,
        times: times,
        stockUnits: json['stockUnits'] as int,
        dispensationId: json['dispensationId'] as String?,
        syncStatus: json['sync_status'] as String? ?? 'synced',
      );
    }).toList();
  }

  Future<void> deleteMedication(String id) async {
    final db = await instance.database;
    await db.update('medications', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Sync Queue Operations ---

  Future<void> addToSyncQueue({
    required String tableName,
    required String operation,
    required Map<String, dynamic> data,
    required String localId,
  }) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'operation': operation,
      'data': jsonEncode(data),
      'local_id': localId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeFromSyncQueue(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- Patient Operations ---

  Future<void> savePatient(Map<String, dynamic> patient) async {
    final db = await instance.database;
    await db.insert('patients', patient, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPatient() async {
    final db = await instance.database;
    final result = await db.query('patients', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('appointments');
    await db.delete('medications');
    await db.delete('patients');
    await db.delete('sync_queue');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoltraak_app/model/SavedMode.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'zoltraak.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE modes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            peak_height_factor REAL NOT NULL,
            slope_up_width_factor REAL NOT NULL,
            slope_down_width_factor REAL NOT NULL,
            top_flat_factor REAL NOT NULL,
            bottom_flat_factor REAL NOT NULL,
            baseline_y_factor REAL NOT NULL,
            road_width REAL NOT NULL,
            speed REAL NOT NULL,
            repetitions INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Inserts or replaces a mode (UNIQUE on name). Returns the row id.
  Future<int> insertMode(SavedMode mode) async {
    final db = await database;
    return db.insert(
      'modes',
      mode.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMode(int id) async {
    final db = await database;
    await db.delete('modes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SavedMode>> getAllModes() async {
    final db = await database;
    final rows = await db.query('modes', orderBy: 'name ASC');
    return rows.map(SavedMode.fromMap).toList();
  }
}

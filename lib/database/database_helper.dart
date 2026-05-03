import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_log.dart';
import '../models/weight_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('health_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE food_logs (
  id $idType,
  name $textType,
  calories $integerType,
  protein $realType,
  carbs $realType,
  fat $realType,
  date $textType,
  amount $realType
)
''');

    await db.execute('''
CREATE TABLE weight_logs (
  id $idType,
  weight $realType,
  date $textType
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE food_logs ADD COLUMN amount REAL NOT NULL DEFAULT 100.0');
    }
  }

  Future<FoodLog> createFoodLog(FoodLog log) async {
    final db = await instance.database;
    final id = await db.insert('food_logs', log.toJson());
    return log.copyWith(id: id);
  }

  Future<FoodLog> updateFoodLog(FoodLog log) async {
    final db = await instance.database;
    await db.update(
      'food_logs',
      log.toJson(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
    return log;
  }

  Future<List<FoodLog>> readAllFoodLogs() async {
    final db = await instance.database;
    final result = await db.query('food_logs', orderBy: 'date DESC');
    return result.map((json) => FoodLog.fromJson(json)).toList();
  }

  Future<WeightLog> createWeightLog(WeightLog log) async {
    final db = await instance.database;
    final id = await db.insert('weight_logs', log.toJson());
    return log.copyWith(id: id);
  }

  Future<List<WeightLog>> readAllWeightLogs() async {
    final db = await instance.database;
    final result = await db.query('weight_logs', orderBy: 'date DESC');
    return result.map((json) => WeightLog.fromJson(json)).toList();
  }

  Future<int> deleteFoodLog(int id) async {
    final db = await instance.database;
    return db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

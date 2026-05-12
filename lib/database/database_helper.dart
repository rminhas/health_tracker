import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_log.dart';
import '../models/weight_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _useInMemory = false;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('health_tracker.db');
    return _database!;
  }

  /// Switches to an isolated in-memory database. Call before each test.
  @visibleForTesting
  static void useInMemoryForTesting() {
    _useInMemory = true;
    _database = null;
  }

  /// Closes and discards the current database. Call after each test.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _useInMemory = false;
  }

  Future<Database> _initDB(String filePath) async {
    final path = _useInMemory
        ? inMemoryDatabasePath
        : join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 4,
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
  amount $realType,
  meal_type TEXT
)
''');

    await db.execute('''
CREATE TABLE weight_logs (
  id $idType,
  weight $realType,
  date $textType
)
''');

    await db.execute('''
CREATE TABLE food_search_cache (
  query TEXT PRIMARY KEY,
  results TEXT NOT NULL,
  cached_at TEXT NOT NULL
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE food_logs ADD COLUMN amount REAL NOT NULL DEFAULT 100.0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE food_logs ADD COLUMN meal_type TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS food_search_cache (
  query TEXT PRIMARY KEY,
  results TEXT NOT NULL,
  cached_at TEXT NOT NULL
)
''');
    }
  }

  Future<FoodLog> createFoodLog(FoodLog log) async {
    final db = await instance.database;
    // Omit the id so SQLite always auto-assigns a new one.
    final map = Map<String, dynamic>.from(log.toJson())..remove('id');
    final newId = await db.insert('food_logs', map);
    return log.copyWith(id: newId);
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

  Future<List<FoodLog>?> readCachedSearch(
    String query, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final db = await instance.database;
    final rows = await db.query(
      'food_search_cache',
      where: 'query = ?',
      whereArgs: [query],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final cachedAt = DateTime.parse(rows.first['cached_at'] as String);
    if (DateTime.now().difference(cachedAt) > ttl) return null;

    final List decoded = json.decode(rows.first['results'] as String) as List;
    return decoded.map((e) => FoodLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> writeCachedSearch(String query, List<FoodLog> results) async {
    final db = await instance.database;
    await db.insert(
      'food_search_cache',
      {
        'query': query,
        'results': json.encode(results.map((f) => f.toJson()).toList()),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Prune entries older than 48 hours to keep the cache table small.
    final cutoff = DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    await db.delete('food_search_cache', where: 'cached_at < ?', whereArgs: [cutoff]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

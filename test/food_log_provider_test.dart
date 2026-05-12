import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:health_tracker/database/database_helper.dart';
import 'package:health_tracker/models/food_log.dart';
import 'package:health_tracker/providers/food_log_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FoodLog _food({
  int? id,
  String name = 'Food',
  int calories = 200,
  double protein = 20.0,
  double carbs = 20.0,
  double fat = 5.0,
  double amount = 100.0,
  DateTime? date,
}) =>
    FoodLog(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      amount: amount,
      date: date ?? DateTime.now(),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.useInMemoryForTesting();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  // -------------------------------------------------------------------------
  // addLog
  // -------------------------------------------------------------------------

  group('FoodLogProvider.addLog', () {
    test('adds the food to the in-memory list and notifies listeners', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'Apple'));

      expect(provider.foodLogs.length, 1);
      expect(provider.foodLogs.first.name, 'Apple');
    });

    test('newly added log receives a DB-assigned id', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food());

      expect(provider.foodLogs.first.id, isNotNull);
    });

    // Regression: before the fix, passing a food whose id already existed in
    // the DB caused a PRIMARY KEY conflict and the log was silently dropped.
    test('succeeds when the source food carries an existing DB id', () async {
      final provider = FoodLogProvider();

      // First log — assigned id=1 by the DB.
      await provider.addLog(_food(name: 'Chicken'));

      // Simulate picking from history: food still has id=1.
      final fromHistory = provider.foodLogs.first;
      expect(fromHistory.id, isNotNull);

      // Re-log with the same object (id intact) — must not throw or silently fail.
      await provider.addLog(fromHistory);

      expect(provider.foodLogs.length, 2);
    });

    test('can re-log the same food multiple times without conflict', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'Rice'));
      final logged = provider.foodLogs.first;

      await provider.addLog(logged);
      await provider.addLog(logged);

      expect(provider.foodLogs.length, 3);
    });

    test('inserts at the front of the list', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'First'));
      await provider.addLog(_food(name: 'Second'));

      expect(provider.foodLogs.first.name, 'Second');
    });
  });

  // -------------------------------------------------------------------------
  // distinctRecentFoods
  // -------------------------------------------------------------------------

  group('FoodLogProvider.distinctRecentFoods', () {
    test('normalizes macros to per-100g regardless of logged amount', () async {
      final provider = FoodLogProvider();
      // Logged at 200g, so DB stores double the per-100g values.
      await provider.addLog(_food(
        name: 'Oats',
        calories: 300, // 150 per 100g
        protein: 10.0, // 5 per 100g
        carbs: 54.0,   // 27 per 100g
        fat: 6.0,      // 3 per 100g
        amount: 200.0,
      ));

      final recents = provider.distinctRecentFoods;
      expect(recents.length, 1);
      expect(recents.first.amount, 100.0);
      expect(recents.first.calories, 150);
      expect(recents.first.protein, closeTo(5.0, 0.01));
      expect(recents.first.carbs, closeTo(27.0, 0.01));
      expect(recents.first.fat, closeTo(3.0, 0.01));
    });

    // Regression: copyWith(id: null) used to silently keep the original id,
    // causing a PRIMARY KEY conflict when the food was re-logged.
    test('returns entries with null id so re-logging never conflicts', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'Banana'));

      final recents = provider.distinctRecentFoods;
      expect(recents.first.id, isNull);
    });

    test('deduplicates by name case-insensitively', () async {
      final provider = FoodLogProvider();
      final now = DateTime.now();
      await provider.addLog(_food(name: 'Apple', date: now));
      await provider.addLog(_food(name: 'apple', date: now.subtract(const Duration(hours: 1))));
      await provider.addLog(_food(name: 'APPLE', date: now.subtract(const Duration(hours: 2))));

      expect(provider.distinctRecentFoods.length, 1);
    });

    test('returns most-recently-logged item when names collide', () async {
      final provider = FoodLogProvider();
      final now = DateTime.now();
      // Most recent first in _foodLogs (insert(0, ...)), so the newest name
      // variant wins deduplication.
      await provider.addLog(_food(name: 'yogurt', calories: 100, date: now.subtract(const Duration(hours: 2))));
      await provider.addLog(_food(name: 'Yogurt', calories: 59, date: now));

      final recents = provider.distinctRecentFoods;
      expect(recents.length, 1);
      expect(recents.first.calories, 59);
    });

    test('is capped at 30 distinct foods', () async {
      final provider = FoodLogProvider();
      for (var i = 0; i < 35; i++) {
        await provider.addLog(_food(name: 'Food $i'));
      }
      expect(provider.distinctRecentFoods.length, 30);
    });
  });

  // -------------------------------------------------------------------------
  // todayLogs and macro totals
  // -------------------------------------------------------------------------

  group('FoodLogProvider.todayLogs', () {
    test('includes only logs dated today', () async {
      final provider = FoodLogProvider();
      // Today.
      await provider.addLog(_food(name: 'Lunch', date: DateTime.now()));
      // Yesterday — insert directly so we control the date.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await DatabaseHelper.instance.createFoodLog(_food(name: 'Breakfast', date: yesterday));
      await provider.loadLogs();

      expect(provider.todayLogs.length, 1);
      expect(provider.todayLogs.first.name, 'Lunch');
    });

    test('totalCalories sums only today\'s logs', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'Snack', calories: 150, date: DateTime.now()));
      await provider.addLog(_food(name: 'Dinner', calories: 600, date: DateTime.now()));

      await DatabaseHelper.instance.createFoodLog(
        _food(name: 'Yesterday', calories: 999, date: DateTime.now().subtract(const Duration(days: 1))),
      );
      await provider.loadLogs();

      expect(provider.totalCalories, 750);
    });

    test('macro totals are zero when no logs exist today', () async {
      final provider = FoodLogProvider();
      expect(provider.totalCalories, 0);
      expect(provider.totalProtein, 0.0);
      expect(provider.totalCarbs, 0.0);
      expect(provider.totalFat, 0.0);
    });
  });

  // -------------------------------------------------------------------------
  // loadLogs / persistence
  // -------------------------------------------------------------------------

  group('FoodLogProvider.loadLogs', () {
    test('loads all persisted logs from the database', () async {
      final provider = FoodLogProvider();
      await provider.addLog(_food(name: 'Persisted'));

      final freshProvider = FoodLogProvider();
      await freshProvider.loadLogs();

      expect(freshProvider.foodLogs.length, 1);
      expect(freshProvider.foodLogs.first.name, 'Persisted');
    });
  });
}

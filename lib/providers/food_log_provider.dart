import 'package:flutter/material.dart';
import '../models/food_log.dart';
import '../database/database_helper.dart';

class FoodLogProvider extends ChangeNotifier {
  List<FoodLog> _foodLogs = [];
  bool _isLoading = false;

  List<FoodLog> get foodLogs => _foodLogs;
  bool get isLoading => _isLoading;

  // ----- Today-only views (used by the Dashboard's "Daily Summary") -----

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Logs eaten today, ordered most-recent first (matches DB read order).
  List<FoodLog> get todayLogs => _foodLogs.where((log) => _isToday(log.date)).toList();

  /// Logs eaten on a given calendar day (local time).
  List<FoodLog> logsForDay(DateTime day) =>
      _foodLogs.where((log) => _isSameDay(log.date, day)).toList();

  /// Distinct foods previously logged (most-recent first), keyed by lowercased name.
  /// Used by the Food Logging screen so users can re-log familiar foods in one tap.
  /// Each entry's amount/calories/macros are normalized back to the per-100g baseline
  /// so the caller can scale by amount the same way as USDA results.
  List<FoodLog> get distinctRecentFoods {
    final seen = <String>{};
    final result = <FoodLog>[];
    for (final log in _foodLogs) {
      final key = log.name.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      // Normalize back to per-100g so callers can scale by amount.
      // Preserve the original amount as lastUsedAmount so the log dialog
      // can pre-populate with the user's actual serving size.
      final scale = log.amount > 0 ? 100.0 / log.amount : 1.0;
      result.add(log.copyWith(
        id: null,
        amount: 100.0,
        lastUsedAmount: log.amount,
        calories: (log.calories * scale).round(),
        protein: log.protein * scale,
        carbs: log.carbs * scale,
        fat: log.fat * scale,
        date: DateTime.now(),
      ));
      if (result.length >= 30) break;
    }
    return result;
  }

  // Today-only totals — what the dashboard's Daily Summary should display.
  int get totalCalories => todayLogs.fold(0, (sum, log) => sum + log.calories);
  double get totalProtein => todayLogs.fold(0.0, (sum, log) => sum + log.protein);
  double get totalCarbs => todayLogs.fold(0.0, (sum, log) => sum + log.carbs);
  double get totalFat => todayLogs.fold(0.0, (sum, log) => sum + log.fat);

  // All-time totals — used by the Analytics screen for charts/averages.
  int get allTimeCalories => _foodLogs.fold(0, (sum, log) => sum + log.calories);
  double get allTimeProtein => _foodLogs.fold(0.0, (sum, log) => sum + log.protein);
  double get allTimeCarbs => _foodLogs.fold(0.0, (sum, log) => sum + log.carbs);
  double get allTimeFat => _foodLogs.fold(0.0, (sum, log) => sum + log.fat);

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();

    _foodLogs = await DatabaseHelper.instance.readAllFoodLogs();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLog(FoodLog log) async {
    final newLog = await DatabaseHelper.instance.createFoodLog(log);
    _foodLogs.insert(0, newLog);
    notifyListeners();
  }

  Future<void> updateLog(FoodLog log) async {
    final updatedLog = await DatabaseHelper.instance.updateFoodLog(log);
    final index = _foodLogs.indexWhere((l) => l.id == log.id);
    if (index != -1) {
      _foodLogs[index] = updatedLog;
      notifyListeners();
    }
  }

  Future<void> deleteLog(FoodLog log) async {
    if (log.id == null) return;
    await DatabaseHelper.instance.deleteFoodLog(log.id!);
    _foodLogs.removeWhere((l) => l.id == log.id);
    notifyListeners();
  }

  /// Re-creates a previously deleted [log] in the database. Used to power the
  /// "Undo" affordance shown after a swipe-delete: SQLite will assign a fresh
  /// auto-increment id, but the user-visible fields (name, amount, date,
  /// nutrition, meal type) are preserved exactly.
  Future<FoodLog> restoreLog(FoodLog log) async {
    final restored = await DatabaseHelper.instance.createFoodLog(
      log.copyWith(id: null),
    );
    _foodLogs.insert(0, restored);
    _foodLogs.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return restored;
  }
}

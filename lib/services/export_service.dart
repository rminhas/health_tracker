import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../models/weight_unit.dart';
import '../models/workout_log.dart';
import 'calorie_calculator.dart';
import 'health_service.dart';

class ExportResult {
  ExportResult({required this.summaryFile, required this.detailFile, required this.daysCovered});

  final File summaryFile;
  final File detailFile;
  final int daysCovered;
}

/// Builds CSV exports of the user's daily health data for a date range.
///
/// Produces two files:
///   * `daily_summary.csv` — one row per day, with weight + calorie aggregates.
///   * `detail.csv` — one row per individual food or workout entry.
class ExportService {
  ExportService({HealthService? healthService})
      : _healthService = healthService ?? HealthService();

  final HealthService _healthService;

  Future<ExportResult> exportRange({
    required DateTime start,
    required DateTime end,
    required UserProfile? profile,
    required Goal? goal,
    required WeightUnit weightUnit,
  }) async {
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    if (endDay.isBefore(startDay)) {
      throw ArgumentError('end ($endDay) must be on or after start ($startDay)');
    }

    final foodLogs = await DatabaseHelper.instance.readAllFoodLogs();
    final weightLogs = await DatabaseHelper.instance.readAllWeightLogs();

    final days = <DateTime>[];
    for (var d = startDay;
        !d.isAfter(endDay);
        d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    // Fan-out health queries with a small concurrency cap so a long "all time"
    // export doesn't slam the platform API. Per-day calls are how the rest of
    // the app reads from health, so we reuse the same path here.
    final workoutsByDay = <DateTime, List<WorkoutLog>>{};
    final activeKcalByDay = <DateTime, int?>{};
    const batchSize = 8;
    for (var i = 0; i < days.length; i += batchSize) {
      final batch = days.sublist(i, (i + batchSize).clamp(0, days.length));
      final results = await Future.wait(batch.expand((d) => [
            _healthService.getWorkoutsForDay(d),
            _healthService.getActiveEnergyBurnedForDay(d),
          ]));
      for (var j = 0; j < batch.length; j++) {
        workoutsByDay[batch[j]] = results[j * 2] as List<WorkoutLog>;
        activeKcalByDay[batch[j]] = results[j * 2 + 1] as int?;
      }
    }

    final summaryBuf = StringBuffer();
    summaryBuf.writeln(_csvRow([
      'date',
      'weight_${weightUnit.name}',
      'calories_consumed',
      'calories_burned_active',
      'calories_burned_total_bmr_plus_active',
      'calorie_target',
      'net_deficit',
      'food_entry_count',
      'workout_count',
      'protein_g',
      'carbs_g',
      'fat_g',
    ]));

    final detailBuf = StringBuffer();
    detailBuf.writeln(_csvRow([
      'date',
      'time',
      'type',
      'name',
      'meal_category',
      'amount_g',
      'calories',
      'protein_g',
      'carbs_g',
      'fat_g',
      'workout_duration_min',
    ]));

    for (final day in days) {
      final dayFood = foodLogs.where((f) => _isSameDay(f.date, day)).toList();
      final dayWorkouts = workoutsByDay[day] ?? const <WorkoutLog>[];

      final weightKg = _weightAsOfDay(weightLogs, day);
      final consumed = dayFood.fold<int>(0, (s, f) => s + f.calories);
      final activeKcal = activeKcalByDay[day];
      final workoutSum =
          dayWorkouts.fold<int>(0, (s, w) => s + w.caloriesBurned);
      final activeForDay = workoutSum > 0 ? workoutSum : (activeKcal ?? 0);

      final bmr = (profile != null && weightKg != null)
          ? CalorieCalculatorService.calculateBMR(profile, weightKg)
          : null;
      final totalBurned =
          bmr == null ? activeForDay : (bmr.round() + activeForDay);
      final target = (profile != null && goal != null && weightKg != null)
          ? CalorieCalculatorService.calculateDailyTargetCalories(
              CalorieCalculatorService.calculateTDEE(bmr!, profile.activityLevel),
              goal,
            )
          : null;
      final netDeficit = totalBurned - consumed;

      final protein = dayFood.fold<double>(0, (s, f) => s + f.protein);
      final carbs = dayFood.fold<double>(0, (s, f) => s + f.carbs);
      final fat = dayFood.fold<double>(0, (s, f) => s + f.fat);

      summaryBuf.writeln(_csvRow([
        _isoDate(day),
        weightKg == null ? '' : _formatWeight(weightKg, weightUnit),
        consumed,
        activeForDay,
        bmr == null ? '' : totalBurned,
        target ?? '',
        bmr == null ? '' : netDeficit,
        dayFood.length,
        dayWorkouts.length,
        protein.toStringAsFixed(1),
        carbs.toStringAsFixed(1),
        fat.toStringAsFixed(1),
      ]));

      for (final f in dayFood) {
        detailBuf.writeln(_csvRow([
          _isoDate(f.date),
          _isoTime(f.date),
          'food',
          f.name,
          f.mealType?.name ?? '',
          f.amount.toStringAsFixed(1),
          f.calories,
          f.protein.toStringAsFixed(1),
          f.carbs.toStringAsFixed(1),
          f.fat.toStringAsFixed(1),
          '',
        ]));
      }
      for (final w in dayWorkouts) {
        detailBuf.writeln(_csvRow([
          _isoDate(w.startTime),
          _isoTime(w.startTime),
          'workout',
          w.displayName,
          '',
          '',
          w.caloriesBurned,
          '',
          '',
          '',
          w.durationMinutes,
        ]));
      }
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final summaryFile = File('${dir.path}/health_tracker_daily_summary_$stamp.csv');
    final detailFile = File('${dir.path}/health_tracker_detail_$stamp.csv');
    await summaryFile.writeAsString(summaryBuf.toString());
    await detailFile.writeAsString(detailBuf.toString());

    return ExportResult(
      summaryFile: summaryFile,
      detailFile: detailFile,
      daysCovered: days.length,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  /// Latest weight log on or before [day]. Carries forward the most recent
  /// reading so historical days still report a weight even if the user didn't
  /// step on the scale that day.
  double? _weightAsOfDay(List<WeightLog> logs, DateTime day) {
    final endOfDay =
        DateTime(day.year, day.month, day.day).add(const Duration(days: 1));
    WeightLog? best;
    for (final log in logs) {
      if (log.date.isBefore(endOfDay)) {
        if (best == null || log.date.isAfter(best.date)) best = log;
      }
    }
    return best?.weight;
  }

  String _formatWeight(double kg, WeightUnit unit) {
    final value = unit == WeightUnit.lbs ? kg * 2.20462 : kg;
    return value.toStringAsFixed(2);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _isoTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _csvRow(List<Object?> fields) => fields.map(_csvField).join(',');

  String _csvField(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

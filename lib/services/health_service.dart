import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/workout_log.dart';

/// Status of the Apple Health / Health Connect integration.
///
/// Apple's privacy model means `requestAuthorization` returns `true` even when
/// the user denied READ access — so we cannot rely on the boolean alone. We
/// expose a richer status so the UI can distinguish:
///   - "never asked"      → show a Connect button
///   - "asked & failed"   → show error + retry
///   - "connected"        → show data
///   - "no data today"    → distinguishable from a permission failure
enum HealthStatus {
  unknown,        // configure + auth not attempted
  notRequested,   // configure ran, but auth not yet requested
  connected,      // auth dialog completed (note: on iOS this does NOT mean granted)
  failed,         // platform threw / configure failed / explicitly denied on Android
}

/// Singleton wrapper around the `health` package.
///
/// Multiple call sites (dashboard, profile provider, etc.) share a single
/// `Health` instance and a single auth/configure cache so we don't repeatedly
/// reconfigure or re-prompt.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();
  factory HealthService() => instance;

  final Health _health = Health();
  bool _isConfigured = false;
  HealthStatus _status = HealthStatus.unknown;
  String lastError = '';
  Future<bool>? _inFlightConnect;

  HealthStatus get status => _status;

  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
  ];

  // ACTIVE_ENERGY_BURNED and WORKOUT are read-only;
  // WEIGHT is read+write so we can sync weight logs back to Apple Health.
  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ,
  ];

  Future<void> _configure() async {
    if (_isConfigured) return;
    try {
      await _health.configure();
      _isConfigured = true;
    } catch (e) {
      lastError = 'configure: $e';
      _status = HealthStatus.failed;
      rethrow;
    }
  }

  /// Explicit connect flow — prompts for permission if needed.
  ///
  /// Returns `true` if the OS authorization step completed without throwing.
  /// On iOS this does NOT mean read permission was granted (Apple's privacy
  /// model hides that). The caller should follow up by attempting to read
  /// data and treating an empty result as "either no data, or denied" — and
  /// surface that to the user.
  Future<bool> connect() {
    // Coalesce concurrent callers onto one in-flight Future. Without this, the
    // dashboard's parallel _loadHealthData calls each invoke connect(), and
    // Android throws "Can request only one set of permissions at a time",
    // which prevents the Health Connect dialog from ever appearing.
    return _inFlightConnect ??= _connect()
      ..whenComplete(() => _inFlightConnect = null);
  }

  Future<bool> _connect() async {
    try {
      await _configure();

      if (Platform.isAndroid) {
        // Health Connect on Android also needs activity recognition for
        // step / energy data on many devices.
        await Permission.activityRecognition.request();
      }

      final ok = await _health.requestAuthorization(_types, permissions: _permissions);
      if (ok) {
        _status = HealthStatus.connected;
        lastError = '';
      } else {
        _status = HealthStatus.failed;
        lastError = 'Authorization was not granted.';
      }
      return ok;
    } catch (e) {
      lastError = 'connect: $e';
      _status = HealthStatus.failed;
      return false;
    }
  }

  /// Ensures permissions have been requested at least once this session.
  Future<bool> _ensureAuthorized() async {
    if (_status == HealthStatus.connected) return true;
    if (_status == HealthStatus.failed) {
      // Try once more in case it was a transient error.
      return connect();
    }
    return connect();
  }

  /// Returns today's active energy burned in kcal, or `null` if we couldn't
  /// determine it (caller should treat null as "unknown" and show a Connect
  /// affordance rather than displaying 0 silently).
  Future<int?> getDailyActiveEnergyBurned() =>
      getActiveEnergyBurnedForDay(DateTime.now());

  /// Returns active energy burned in kcal for [day]'s calendar day (local time).
  /// Endpoint clamps to `now` for today so we don't query the future.
  Future<int?> getActiveEnergyBurnedForDay(DateTime day) async {
    final now = DateTime.now();
    final start = DateTime(day.year, day.month, day.day);
    final end = _isSameLocalDay(day, now)
        ? now
        : start.add(const Duration(days: 1));

    try {
      final ok = await _ensureAuthorized();
      if (!ok) return null;

      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      // De-duplicate overlapping samples from multiple sources (Apple Watch,
      // iPhone, third-party apps): two samples with identical start/end/value
      // are treated as one. This is best-effort but avoids inflating burn.
      final seen = <String>{};
      double totalEnergy = 0;
      for (final data in healthData) {
        final value = data.value;
        if (value is! NumericHealthValue) continue;
        final n = value.numericValue.toDouble();
        final key =
            '${data.dateFrom.toIso8601String()}|${data.dateTo.toIso8601String()}|$n';
        if (seen.contains(key)) continue;
        seen.add(key);
        totalEnergy += n;
      }
      return totalEnergy.round();
    } catch (e) {
      lastError = 'getHealthData: $e';
      _status = HealthStatus.failed;
      return null;
    }
  }

  /// Returns today's workouts, sorted most-recent first.
  /// Returns an empty list if unavailable (not an error — caller can display nothing).
  Future<List<WorkoutLog>> getTodayWorkouts() =>
      getWorkoutsForDay(DateTime.now());

  /// Returns workouts for [day]'s calendar day (local time), sorted most-recent first.
  Future<List<WorkoutLog>> getWorkoutsForDay(DateTime day) async {
    final now = DateTime.now();
    final start = DateTime(day.year, day.month, day.day);
    final end = _isSameLocalDay(day, now)
        ? now
        : start.add(const Duration(days: 1));

    try {
      final ok = await _ensureAuthorized();
      if (!ok) return [];

      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.WORKOUT],
      );

      final workouts = <WorkoutLog>[];
      for (final data in healthData) {
        final value = data.value;
        if (value is! WorkoutHealthValue) continue;
        final duration = data.dateTo.difference(data.dateFrom).inMinutes;
        final calories = value.totalEnergyBurned?.toInt() ?? 0;
        workouts.add(WorkoutLog(
          activityType: value.workoutActivityType.name,
          durationMinutes: duration,
          caloriesBurned: calories,
          startTime: data.dateFrom,
        ));
      }
      workouts.sort((a, b) => b.startTime.compareTo(a.startTime));
      return workouts;
    } catch (e) {
      lastError = 'getWorkouts: $e';
      return [];
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<bool> writeWeight(double weightInKg) async {
    try {
      final ok = await _ensureAuthorized();
      if (!ok) return false;

      final now = DateTime.now();
      return await _health.writeHealthData(
        value: weightInKg,
        type: HealthDataType.WEIGHT,
        startTime: now,
        endTime: now,
      );
    } catch (e) {
      lastError = 'writeWeight: $e';
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import '../models/workout_log.dart';
import '../services/health_service.dart';
import 'widgets/date_navigator.dart';

class ExerciseDayScreen extends StatefulWidget {
  const ExerciseDayScreen({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<ExerciseDayScreen> createState() => _ExerciseDayScreenState();
}

class _ExerciseDayScreenState extends State<ExerciseDayScreen> {
  final HealthService _healthService = HealthService();
  late DateTime _selectedDate = dateOnly(widget.initialDate);
  bool _isLoading = true;
  int _activeCalories = 0;
  bool _hasActiveCalories = false;
  List<WorkoutLog> _workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final day = _selectedDate;
    final results = await Future.wait([
      _healthService.getActiveEnergyBurnedForDay(day),
      _healthService.getWorkoutsForDay(day),
    ]);
    if (!mounted || _selectedDate != day) return;
    setState(() {
      final burned = results[0] as int?;
      _activeCalories = burned ?? 0;
      _hasActiveCalories = burned != null;
      _workouts = results[1] as List<WorkoutLog>;
      _isLoading = false;
    });
  }

  void _onDateChanged(DateTime d) {
    setState(() {
      _selectedDate = d;
      _isLoading = true;
    });
    _load();
  }

  int get _workoutCalories =>
      _workouts.fold<int>(0, (s, w) => s + w.caloriesBurned);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DateNavigator(
              selectedDate: _selectedDate,
              onChanged: _onDateChanged,
            ),
          ),
          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  _buildSummaryCard(context),
                  const SizedBox(height: 12),
                  _sectionLabel(
                      context, Icons.fitness_center, 'Workout sessions'),
                  if (_workouts.isEmpty)
                    _emptyState()
                  else
                    ..._workouts.map((w) => _workoutCard(context, w)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    // Prefer the sum of workout-session calories (Strava etc.) when we have
    // them; otherwise fall back to the aggregate active calories that
    // Health Connect derives from steps/heart rate.
    final showWorkoutSum = _workouts.isNotEmpty;
    final headline = showWorkoutSum ? _workoutCalories : _activeCalories;
    final source = showWorkoutSum
        ? 'from ${_workouts.length} workout${_workouts.length == 1 ? '' : 's'}'
        : (_hasActiveCalories
            ? 'aggregate active calories from Health Connect'
            : 'Health Connect not available');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calories burned • '
                      '${formatDateLabel(_selectedDate).toLowerCase()}',
                      style: theme.textTheme.bodyMedium),
                  Text(_hasActiveCalories || showWorkoutSum
                      ? '$headline kcal'
                      : '—',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(source,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final isToday = dateOnly(_selectedDate) == dateOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        isToday
            ? 'No workout sessions recorded today.'
            : 'No workout sessions recorded on this day.',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, IconData icon, String label) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _workoutCard(BuildContext context, WorkoutLog w) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.directions_run, size: 22),
        title: Text(w.activityType.replaceAll('_', ' '),
            style: const TextStyle(fontSize: 14)),
        subtitle: Text('${w.durationMinutes} min · ${w.caloriesBurned} kcal',
            style: const TextStyle(fontSize: 11)),
        trailing: Text(
            '${w.startTime.hour}:${w.startTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

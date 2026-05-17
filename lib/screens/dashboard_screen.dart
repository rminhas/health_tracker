import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weight_unit.dart';
import '../providers/food_log_provider.dart';
import '../providers/profile_provider.dart';
import '../services/health_service.dart';
import 'analytics_screen.dart';
import 'exercise_day_screen.dart';
import 'export_screen.dart';
import 'food_day_screen.dart';
import 'food_logging_screen.dart';
import 'profile_goals_screen.dart';
import 'widgets/date_navigator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final HealthService _healthService = HealthService();
  int _caloriesBurned = 0;
  bool _healthDataAvailable = false;
  bool _isLoadingHealth = true;
  DateTime _selectedDate = dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHealthData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadHealthData();
  }

  /// Loads calories burned for [_selectedDate]. Prefers the sum of workout
  /// sessions (e.g. Strava entries) when available so each logged exercise's
  /// calorie cost is what counts toward the daily balance. Falls back to the
  /// aggregate ACTIVE_ENERGY_BURNED record from Health Connect.
  Future<void> _loadHealthData() async {
    final day = _selectedDate;
    final results = await Future.wait([
      _healthService.getActiveEnergyBurnedForDay(day),
      _healthService.getWorkoutsForDay(day),
    ]);
    if (!mounted || _selectedDate != day) return;
    final activeKcal = results[0] as int?;
    final workouts = results[1] as List;
    final workoutSum = workouts.fold<int>(
        0, (s, w) => s + (w.caloriesBurned as int));
    setState(() {
      _caloriesBurned = workoutSum > 0 ? workoutSum : (activeKcal ?? 0);
      _healthDataAvailable = activeKcal != null || workoutSum > 0;
      _isLoadingHealth = false;
    });
  }

  void _onDateChanged(DateTime d) {
    setState(() {
      _selectedDate = d;
      _isLoadingHealth = true;
    });
    _loadHealthData();
  }

  Future<void> _connectHealth() async {
    final ok = await _healthService.connect();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not connect: ${_healthService.lastError}'),
        duration: const Duration(seconds: 5),
      ));
    }
    await _loadHealthData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileGoalsScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExportScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.ios_share),
                  title: Text('Export data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer2<FoodLogProvider, ProfileProvider>(
        builder: (context, foodLogProvider, profileProvider, child) {
          if (foodLogProvider.isLoading ||
              profileProvider.isLoading ||
              _isLoadingHealth) {
            return const Center(child: CircularProgressIndicator());
          }

          final dayLogs = foodLogProvider.logsForDay(_selectedDate);
          final dayCalories = dayLogs.fold<int>(0, (s, l) => s + l.calories);
          final dayProtein = dayLogs.fold<double>(0, (s, l) => s + l.protein);
          final dayCarbs = dayLogs.fold<double>(0, (s, l) => s + l.carbs);
          final dayFat = dayLogs.fold<double>(0, (s, l) => s + l.fat);
          final netCalories = dayCalories - _caloriesBurned;
          final targetCalories = profileProvider.targetCalories;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_healthDataAvailable) _buildHealthConnectBanner(context),
                DateNavigator(
                  selectedDate: _selectedDate,
                  onChanged: _onDateChanged,
                ),
                _buildSummaryCard(
                  context,
                  consumed: dayCalories,
                  protein: dayProtein,
                  carbs: dayCarbs,
                  fat: dayFat,
                  netCalories: netCalories,
                  targetCalories: targetCalories,
                ),
                const SizedBox(height: 12),
                _buildNavButtons(context),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showWeightLogDialog(context),
                  icon: const Icon(Icons.scale, size: 18),
                  label: const Text('Log Weight'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FoodLoggingScreen()),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log Food'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Food / Exercise navigation cards ─────────────────────────────────────

  Widget _buildNavButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _navCard(
            context,
            icon: Icons.restaurant_menu,
            label: 'Food',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      FoodDayScreen(initialDate: _selectedDate)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _navCard(
            context,
            icon: Icons.directions_run,
            label: 'Exercise',
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ExerciseDayScreen(initialDate: _selectedDate)),
            ).then((_) {
              // Exercise screen may have triggered new permissions / data;
              // refresh in case the burned total changed.
              _loadHealthData();
            }),
          ),
        ),
      ],
    );
  }

  Widget _navCard(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showWeightLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final profileProvider = context.read<ProfileProvider>();
        final unit = profileProvider.weightUnit;
        final currentKg = profileProvider.latestWeightLog?.weight ?? 70.0;
        double displayValue = unit.toDisplay(currentKg);
        return AlertDialog(
          title: const Text('Log Weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your weight in ${unit.label}:'),
              TextFormField(
                initialValue: displayValue.toStringAsFixed(1),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (val) {
                  displayValue = double.tryParse(val) ?? displayValue;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final kg = unit.toKg(displayValue);
                Navigator.pop(dialogContext);
                if (kg > 0) profileProvider.logWeight(kg);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ── Health connect banner ────────────────────────────────────────────────

  Widget _buildHealthConnectBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isFailure = _healthService.status == HealthStatus.failed;
    final platformLabel =
        Platform.isIOS ? 'Apple Health' : 'Health Connect';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isFailure ? Icons.error_outline : Icons.favorite_border,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFailure
                      ? 'Could not read $platformLabel data'
                      : 'Connect $platformLabel',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isFailure
                      ? 'Open $platformLabel and confirm permissions, then tap Retry.'
                      : "Allow read access to show today's exercise calories.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _connectHealth,
            child: Text(isFailure ? 'Retry' : 'Connect'),
          ),
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _buildSummaryCard(
    BuildContext context, {
    required int consumed,
    required double protein,
    required double carbs,
    required double fat,
    required int netCalories,
    required int targetCalories,
  }) {
    final burned = consumed - netCalories;
    final remaining = targetCalories - netCalories;
    final isOver = remaining < 0;
    final hasTarget = targetCalories > 0;
    final effectiveBudget = targetCalories + burned;
    final progress = hasTarget && effectiveBudget > 0
        ? (consumed / effectiveBudget).clamp(0.0, 1.0)
        : 0.0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientStart = isDark
        ? Color.alphaBlend(
            Colors.teal.withValues(alpha: 0.18), theme.colorScheme.surface)
        : Colors.teal.shade50;
    final gradientEnd = isDark ? theme.colorScheme.surface : Colors.white;
    final headingColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final ringColor = isOver
        ? theme.colorScheme.error
        : (isDark ? Colors.greenAccent : Colors.green.shade700);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('Daily Summary',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: headingColor)),
            const SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: mutedColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(ringColor),
                  ),
                ),
                const SizedBox(height: 10),
                Text('$consumed kcal consumed',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: headingColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_healthDataAvailable)
                  _buildMacroStat('Burned', '$_caloriesBurned', 'kcal',
                      Colors.green,
                      labelColor: mutedColor, valueFontSize: 18),
                _buildMacroStat(
                  'Remaining',
                  hasTarget ? '$remaining' : '—',
                  hasTarget ? 'kcal' : '',
                  ringColor,
                  labelColor: mutedColor,
                  valueFontSize: 18,
                ),
                _buildMacroStat(
                    'Target',
                    hasTarget ? '$targetCalories' : 'Not set',
                    hasTarget ? 'kcal' : '',
                    mutedColor,
                    labelColor: mutedColor,
                    valueFontSize: 18),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat('Protein',
                    protein.toStringAsFixed(1), 'g', Colors.red,
                    labelColor: mutedColor),
                _buildMacroStat('Carbs',
                    carbs.toStringAsFixed(1), 'g', Colors.blue,
                    labelColor: mutedColor),
                _buildMacroStat('Fat',
                    fat.toStringAsFixed(1), 'g', Colors.amber,
                    labelColor: mutedColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, String unit, Color color,
      {Color? labelColor, double valueFontSize = 24}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: labelColor ?? Colors.grey)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

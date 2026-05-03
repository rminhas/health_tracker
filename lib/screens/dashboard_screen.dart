import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_log.dart';
import '../models/weight_unit.dart';
import '../models/workout_log.dart';
import '../providers/food_log_provider.dart';
import '../providers/profile_provider.dart';
import '../services/health_service.dart';
import 'food_logging_screen.dart';
import 'profile_goals_screen.dart';
import 'analytics_screen.dart';

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
  List<WorkoutLog> _todayWorkouts = [];

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

  Future<void> _loadHealthData() async {
    final results = await Future.wait([
      _healthService.getDailyActiveEnergyBurned(),
      _healthService.getTodayWorkouts(),
    ]);
    if (!mounted) return;
    setState(() {
      final burned = results[0] as int?;
      _caloriesBurned = burned ?? 0;
      _healthDataAvailable = burned != null;
      _todayWorkouts = results[1] as List<WorkoutLog>;
      _isLoadingHealth = false;
    });
  }

  Future<void> _connectAppleHealth() async {
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileGoalsScreen())),
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

          final netCalories =
              foodLogProvider.totalCalories - _caloriesBurned;
          final targetCalories = profileProvider.targetCalories;
          final todayLogs = foodLogProvider.todayLogs;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_healthDataAvailable)
                  _buildHealthConnectBanner(context),
                _buildSummaryCard(
                    context, foodLogProvider, netCalories, targetCalories),
                const SizedBox(height: 16),
                _buildSectionHeader("Today's Log"),
                const SizedBox(height: 6),
                _buildSectionLabel(context, Icons.restaurant_menu, 'Meals'),
                if (todayLogs.isEmpty)
                  _buildEmptyState('No food logged today.')
                else
                  ...todayLogs.map((log) => _buildMealCard(context, log)),
                const SizedBox(height: 8),
                if (_healthDataAvailable) ...[
                  _buildSectionLabel(
                      context, Icons.directions_run, 'Exercise'),
                  if (_todayWorkouts.isEmpty)
                    _buildEmptyState('No workouts recorded today.')
                  else
                    ..._todayWorkouts
                        .map((w) => _buildWorkoutCard(context, w)),
                ],
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

  // ── Section helpers ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildSectionLabel(
      BuildContext context, IconData icon, String label) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  // ── Meal card ────────────────────────────────────────────────────────────

  Widget _buildMealCard(BuildContext context, FoodLog log) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete,
            size: 20,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete entry?'),
                content: Text('Remove ${log.name} from today\'s log?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => context.read<FoodLogProvider>().deleteLog(log),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: const Icon(Icons.restaurant_menu, size: 20),
          title: Text(log.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${log.amount.toStringAsFixed(0)}g · ${log.calories} kcal',
              style: const TextStyle(fontSize: 11)),
          trailing: Text(
              '${log.date.hour}:${log.date.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11)),
          onTap: () => _editLog(context, log),
        ),
      ),
    );
  }

  // ── Workout card ─────────────────────────────────────────────────────────

  Widget _buildWorkoutCard(BuildContext context, WorkoutLog workout) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(workout.icon, size: 20, color: Colors.teal),
        title: Text(workout.displayName,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${workout.durationMinutes} min'
            '${workout.caloriesBurned > 0 ? ' · ${workout.caloriesBurned} kcal' : ''}',
            style: const TextStyle(fontSize: 11)),
        trailing: Text(
            '${workout.startTime.hour}:${workout.startTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11)),
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
                if (kg > 0) profileProvider.logWeight(kg);
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editLog(BuildContext context, FoodLog log) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        double newAmount = log.amount;
        return AlertDialog(
          title: Text('Edit ${log.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter new amount in grams:'),
              TextFormField(
                initialValue: log.amount.toStringAsFixed(1),
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (val) {
                  newAmount = double.tryParse(val) ?? 0.0;
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
                if (newAmount <= 0) return;
                final ratio = log.amount > 0 ? newAmount / log.amount : 1.0;
                context.read<FoodLogProvider>().updateLog(log.copyWith(
                      amount: newAmount,
                      calories: (log.calories * ratio).round(),
                      protein: log.protein * ratio,
                      carbs: log.carbs * ratio,
                      fat: log.fat * ratio,
                    ));
                Navigator.pop(dialogContext);
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
            onPressed: _connectAppleHealth,
            child: Text(isFailure ? 'Retry' : 'Connect'),
          ),
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, FoodLogProvider provider,
      int netCalories, int targetCalories) {
    final difference = targetCalories - netCalories;
    final isOver = difference < 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientStart = isDark
        ? Color.alphaBlend(
            Colors.teal.withValues(alpha: 0.18), theme.colorScheme.surface)
        : Colors.teal.shade50;
    final gradientEnd =
        isDark ? theme.colorScheme.surface : Colors.white;
    final headingColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat('Consumed', '${provider.totalCalories}',
                    'kcal', Colors.orange,
                    labelColor: mutedColor),
                _buildMacroStat(
                  'Burned',
                  _healthDataAvailable ? '$_caloriesBurned' : '—',
                  'kcal',
                  Colors.green,
                  labelColor: mutedColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat(
                  'Remaining',
                  '$difference',
                  'kcal',
                  isOver
                      ? theme.colorScheme.error
                      : (isDark
                          ? Colors.greenAccent
                          : Colors.green.shade700),
                  labelColor: mutedColor,
                ),
                _buildMacroStat('Target', '$targetCalories', 'kcal',
                    mutedColor,
                    labelColor: mutedColor),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat('Protein',
                    provider.totalProtein.toStringAsFixed(1), 'g', Colors.red,
                    labelColor: mutedColor),
                _buildMacroStat('Carbs',
                    provider.totalCarbs.toStringAsFixed(1), 'g', Colors.blue,
                    labelColor: mutedColor),
                _buildMacroStat('Fat', provider.totalFat.toStringAsFixed(1),
                    'g', Colors.amber,
                    labelColor: mutedColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, String unit, Color color,
      {Color? labelColor}) {
    return Column(
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 14, color: labelColor ?? Colors.grey)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24,
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

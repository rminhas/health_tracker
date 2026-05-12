import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_log.dart';
import '../models/weight_unit.dart';
import '../models/workout_log.dart';
import '../models/food_unit.dart';
import '../models/meal_type.dart';
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
                if (todayLogs.isEmpty)
                  _buildEmptyState('No food logged today.')
                else
                  ..._buildGroupedMeals(context, todayLogs),
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

  // ── Grouped meals ────────────────────────────────────────────────────────

  List<Widget> _buildGroupedMeals(BuildContext context, List<FoodLog> logs) {
    final widgets = <Widget>[];
    for (final type in MealType.values) {
      final group = logs.where((l) => l.mealType == type).toList();
      if (group.isEmpty) continue;
      widgets.add(_buildSectionLabel(context, type.icon, type.label));
      widgets.addAll(group.map((l) => _buildMealCard(context, l)));
      widgets.add(const SizedBox(height: 4));
    }
    // Legacy entries logged before meal categories were introduced.
    final untyped = logs.where((l) => l.mealType == null).toList();
    if (untyped.isNotEmpty) {
      widgets.add(_buildSectionLabel(context, Icons.restaurant_menu, 'Other'));
      widgets.addAll(untyped.map((l) => _buildMealCard(context, l)));
    }
    return widgets;
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

  void _editLog(BuildContext context, FoodLog log) {
    final amountCtrl =
        TextEditingController(text: log.amount.toStringAsFixed(1));
    var selectedUnit = FoodUnit.g;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final amt = double.tryParse(amountCtrl.text) ?? 0.0;
          final newGrams = amt * selectedUnit.toGrams;
          final valid = newGrams > 0;

          return AlertDialog(
            title: Text('Edit ${log.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Amount (${selectedUnit.label})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<FoodUnit>(
                      value: selectedUnit,
                      underline: const SizedBox(),
                      items: FoodUnit.values
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.label),
                              ))
                          .toList(),
                      onChanged: (u) {
                        if (u != null) {
                          setDialogState(() => selectedUnit = u);
                        }
                      },
                    ),
                  ],
                ),
                if (selectedUnit.isVolume) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Volume units assume density ≈ 1 g/ml (accurate for liquids).',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: valid
                    ? () {
                        final ratio =
                            log.amount > 0 ? newGrams / log.amount : 1.0;
                        final provider = context.read<FoodLogProvider>();
                        final updatedLog = log.copyWith(
                          amount: newGrams,
                          calories: (log.calories * ratio).round(),
                          protein: log.protein * ratio,
                          carbs: log.carbs * ratio,
                          fat: log.fat * ratio,
                        );
                        Navigator.pop(dialogContext);
                        provider.updateLog(updatedLog);
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(amountCtrl.dispose);
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
    final consumed = provider.totalCalories;
    final burned = consumed - netCalories; // calories burned via exercise
    final remaining = targetCalories - netCalories;
    final isOver = remaining < 0;
    final hasTarget = targetCalories > 0;
    // Use target + burned as the budget so exercise calories extend the ring.
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
            // Calorie progress ring with label below.
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
            // Compact stats below the ring.
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
                    provider.totalProtein.toStringAsFixed(1), 'g', Colors.red,
                    labelColor: mutedColor),
                _buildMacroStat('Carbs',
                    provider.totalCarbs.toStringAsFixed(1), 'g', Colors.blue,
                    labelColor: mutedColor),
                _buildMacroStat('Fat',
                    provider.totalFat.toStringAsFixed(1), 'g', Colors.amber,
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

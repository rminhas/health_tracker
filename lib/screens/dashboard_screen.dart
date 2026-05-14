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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final HealthService _healthService = HealthService();
  int _caloriesBurned = 0;
  bool _healthDataAvailable = false;
  bool _isLoadingHealth = true;
  List<WorkoutLog> _todayWorkouts = [];
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  DateTime _selectedDate = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _isViewingToday =>
      _dateOnly(_selectedDate) == _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHealthData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    final day = _selectedDate;
    final results = await Future.wait([
      _healthService.getActiveEnergyBurnedForDay(day),
      _healthService.getWorkoutsForDay(day),
    ]);
    if (!mounted) return;
    // Only apply the result if the user hasn't switched away to another day
    // while this load was in flight.
    if (_selectedDate != day) return;
    setState(() {
      final burned = results[0] as int?;
      _caloriesBurned = burned ?? 0;
      _healthDataAvailable = burned != null;
      _todayWorkouts = results[1] as List<WorkoutLog>;
      _isLoadingHealth = false;
    });
  }

  void _shiftDate(int days) {
    final next = _dateOnly(_selectedDate.add(Duration(days: days)));
    final today = _dateOnly(DateTime.now());
    if (next.isAfter(today)) return;
    setState(() {
      _selectedDate = next;
      _isLoadingHealth = true;
    });
    _loadHealthData();
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    final normalized = _dateOnly(picked);
    if (normalized == _selectedDate) return;
    setState(() {
      _selectedDate = normalized;
      _isLoadingHealth = true;
    });
    _loadHealthData();
  }

  String _dateLabel(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final diff = today.difference(_dateOnly(d)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
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

          final dayLogs = foodLogProvider.logsForDay(_selectedDate);
          final dayCalories = dayLogs.fold<int>(0, (s, l) => s + l.calories);
          final dayProtein = dayLogs.fold<double>(0, (s, l) => s + l.protein);
          final dayCarbs = dayLogs.fold<double>(0, (s, l) => s + l.carbs);
          final dayFat = dayLogs.fold<double>(0, (s, l) => s + l.fat);
          final netCalories = dayCalories - _caloriesBurned;
          final targetCalories = profileProvider.targetCalories;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_healthDataAvailable)
                      _buildHealthConnectBanner(context),
                    _buildDateNavigator(context),
                    _buildSummaryCard(
                      context,
                      consumed: dayCalories,
                      protein: dayProtein,
                      carbs: dayCarbs,
                      fat: dayFat,
                      netCalories: netCalories,
                      targetCalories: targetCalories,
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.restaurant_menu), text: 'Food'),
                  Tab(icon: Icon(Icons.directions_run), text: 'Exercise'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFoodTab(context, dayLogs),
                    _buildExerciseTab(context),
                  ],
                ),
              ),
            ],
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

  // ── Date navigator ───────────────────────────────────────────────────────

  Widget _buildDateNavigator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => _shiftDate(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_dateLabel(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: _isViewingToday ? null : () => _shiftDate(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ── Tab bodies ───────────────────────────────────────────────────────────

  Widget _buildFoodTab(BuildContext context, List<FoodLog> dayLogs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        if (dayLogs.isEmpty)
          _buildEmptyState(_isViewingToday
              ? 'No food logged today.'
              : 'No food logged on this day.')
        else
          ..._buildGroupedMeals(context, dayLogs),
      ],
    );
  }

  Widget _buildExerciseTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                      Text(
                          'Active calories burned • '
                          '${_dateLabel(_selectedDate).toLowerCase()}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text(_healthDataAvailable
                          ? '$_caloriesBurned kcal'
                          : '— (Health Connect not available)',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildSectionLabel(context, Icons.fitness_center, 'Workout sessions'),
        if (_todayWorkouts.isEmpty)
          _buildEmptyState(_isViewingToday
              ? 'No workout sessions recorded today.'
              : 'No workout sessions recorded on this day.')
        else
          ..._todayWorkouts.map((w) => _buildWorkoutCard(context, w)),
      ],
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

  Widget _buildSummaryCard(
    BuildContext context, {
    required int consumed,
    required double protein,
    required double carbs,
    required double fat,
    required int netCalories,
    required int targetCalories,
  }) {
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

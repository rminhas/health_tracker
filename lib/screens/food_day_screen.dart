import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_log.dart';
import '../models/meal_type.dart';
import '../providers/food_log_provider.dart';
import 'food_logging_screen.dart';
import 'widgets/date_navigator.dart';
import 'widgets/food_log_dialog.dart';

class FoodDayScreen extends StatefulWidget {
  const FoodDayScreen({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<FoodDayScreen> createState() => _FoodDayScreenState();
}

class _FoodDayScreenState extends State<FoodDayScreen> {
  late DateTime _selectedDate = dateOnly(widget.initialDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      body: Consumer<FoodLogProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = provider.logsForDay(_selectedDate);
          final totalCalories = logs.fold<int>(0, (s, l) => s + l.calories);
          final totalProtein = logs.fold<double>(0, (s, l) => s + l.protein);
          final totalCarbs = logs.fold<double>(0, (s, l) => s + l.carbs);
          final totalFat = logs.fold<double>(0, (s, l) => s + l.fat);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: DateNavigator(
                  selectedDate: _selectedDate,
                  onChanged: (d) => setState(() => _selectedDate = d),
                ),
              ),
              _buildTotalsStrip(
                  context, totalCalories, totalProtein, totalCarbs, totalFat),
              Expanded(
                child: logs.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                        children: _buildGroupedMeals(context, logs),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FoodLoggingScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Log Food'),
      ),
    );
  }

  Widget _buildTotalsStrip(BuildContext context, int kcal, double p, double c,
      double f) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Calories', '$kcal', 'kcal'),
          _stat('Protein', p.toStringAsFixed(1), 'g'),
          _stat('Carbs', c.toStringAsFixed(1), 'g'),
          _stat('Fat', f.toStringAsFixed(1), 'g'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              TextSpan(text: ' $unit',
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isToday = dateOnly(_selectedDate) == dateOnly(DateTime.now());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isToday ? 'No food logged today.' : 'No food logged on this day.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedMeals(BuildContext context, List<FoodLog> logs) {
    final widgets = <Widget>[];
    for (final type in MealType.values) {
      final group = logs.where((l) => l.mealType == type).toList();
      if (group.isEmpty) continue;
      widgets.add(_sectionLabel(context, type.icon, type.label));
      widgets.addAll(group.map((l) => _mealCard(context, l)));
      widgets.add(const SizedBox(height: 4));
    }
    final untyped = logs.where((l) => l.mealType == null).toList();
    if (untyped.isNotEmpty) {
      widgets.add(_sectionLabel(context, Icons.restaurant_menu, 'Other'));
      widgets.addAll(untyped.map((l) => _mealCard(context, l)));
    }
    return widgets;
  }

  Widget _sectionLabel(BuildContext context, IconData icon, String label) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
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

  /// Opens the shared food dialog in edit mode. Reconstructs the per-100g
  /// baseline from the stored (already scaled) entry so the dialog can do its
  /// usual amount-driven scaling math.
  void _editLog(BuildContext context, FoodLog log) {
    if (log.amount <= 0) return;
    final scale = 100.0 / log.amount;
    final per100g = log.copyWith(
      id: null,
      amount: 100,
      calories: (log.calories * scale).round(),
      protein: log.protein * scale,
      carbs: log.carbs * scale,
      fat: log.fat * scale,
    );
    showFoodLogDialog(
      context: context,
      perHundredGrams: per100g,
      existing: log,
    );
  }

  Future<void> _deleteWithUndo(BuildContext context, FoodLog log) async {
    final provider = context.read<FoodLogProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.deleteLog(log);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${log.name}'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => provider.restoreLog(log),
        ),
      ),
    );
  }

  Widget _mealCard(BuildContext context, FoodLog log) {
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
                content: Text('Remove ${log.name} from this day\'s log?'),
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
      onDismissed: (_) => _deleteWithUndo(context, log),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          onTap: () => _editLog(context, log),
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
        ),
      ),
    );
  }
}

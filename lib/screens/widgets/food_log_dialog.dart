import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_log.dart';
import '../../models/food_unit.dart';
import '../../models/meal_type.dart';
import '../../providers/food_log_provider.dart';

/// Shared food-entry dialog used both when adding a new log and when editing
/// an existing one.
///
/// [perHundredGrams] is the food's baseline nutrition normalized to 100 g —
/// matches how USDA search results and `FoodLogProvider.distinctRecentFoods`
/// are produced. Pass [existing] to enter edit mode: the dialog pre-populates
/// the entry's current amount + meal type, the title/button change to reflect
/// editing, and saving calls [FoodLogProvider.updateLog].
///
/// In add mode the dialog adds via [FoodLogProvider.addLog] and pops the
/// surrounding screen (Log Food → previous screen), matching the existing
/// navigation flow.
Future<void> showFoodLogDialog({
  required BuildContext context,
  required FoodLog perHundredGrams,
  FoodLog? existing,
}) {
  final isEdit = existing != null;
  final food = perHundredGrams;
  final initialAmount =
      existing?.amount ?? perHundredGrams.lastUsedAmount ?? 100.0;
  final initialAmountText = initialAmount % 1 == 0
      ? initialAmount.toInt().toString()
      : initialAmount.toStringAsFixed(1);
  final amountCtrl = TextEditingController(text: initialAmountText);
  var selectedUnit = FoodUnit.g;
  var selectedMealType =
      existing?.mealType ?? perHundredGrams.mealType ?? MealType.suggest();

  return showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final amt = double.tryParse(amountCtrl.text) ?? 0.0;
        final valid = amt > 0;
        final gramsEquivalent = amt * selectedUnit.toGrams;
        final ratio = valid ? gramsEquivalent / 100.0 : 0.0;

        return AlertDialog(
          title: Text('${isEdit ? "Edit" : "Add"} ${food.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per 100g: ${food.calories} kcal  ·  P ${food.protein.toStringAsFixed(1)}g  ·  C ${food.carbs.toStringAsFixed(1)}g  ·  F ${food.fat.toStringAsFixed(1)}g',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text('Meal', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: MealType.values
                      .map((t) => ChoiceChip(
                            label: Text(t.label),
                            selected: selectedMealType == t,
                            onSelected: (_) =>
                                setDialogState(() => selectedMealType = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                if (valid)
                  Text(
                    'At ${amt.toStringAsFixed(0)} ${selectedUnit.label}: ${(food.calories * ratio).round()} kcal  ·  P ${(food.protein * ratio).toStringAsFixed(1)}g  ·  C ${(food.carbs * ratio).toStringAsFixed(1)}g  ·  F ${(food.fat * ratio).toStringAsFixed(1)}g',
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: valid
                  ? () {
                      final adjusted = food.copyWith(
                        id: existing?.id,
                        amount: gramsEquivalent,
                        calories: (food.calories * ratio).round(),
                        protein: food.protein * ratio,
                        carbs: food.carbs * ratio,
                        fat: food.fat * ratio,
                        mealType: selectedMealType,
                        // Preserve the original log's timestamp on edit so the
                        // entry stays in its day; new entries stamp now.
                        date: existing?.date ?? DateTime.now(),
                      );
                      final provider = context.read<FoodLogProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      if (isEdit) {
                        provider.updateLog(adjusted);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Updated ${adjusted.name}')),
                        );
                      } else {
                        // Add flow is launched from the Log Food screen — pop
                        // back to the previous screen once recorded.
                        Navigator.pop(context);
                        provider.addLog(adjusted);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Logged ${adjusted.name}')),
                        );
                      }
                    }
                  : null,
              child: Text(isEdit ? 'Save' : 'Log Food'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(amountCtrl.dispose);
}

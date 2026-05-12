import 'package:flutter/material.dart';

enum MealType {
  breakfast('Breakfast', Icons.free_breakfast),
  lunch('Lunch', Icons.lunch_dining),
  dinner('Dinner', Icons.dinner_dining),
  snack('Snack', Icons.apple);

  const MealType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Suggests a meal type based on the current time of day.
  static MealType suggest() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  /// Returns null for unrecognised or null values (used for legacy DB rows).
  static MealType? fromString(String? value) {
    if (value == null) return null;
    return MealType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MealType.snack,
    );
  }
}

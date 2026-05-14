import 'meal_type.dart';

class FoodLog {
  final int? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime date;
  final double amount;
  final MealType? mealType;
  // Not persisted to DB — carries the last-used gram amount through distinctRecentFoods
  // so the log dialog can pre-populate with the user's actual serving size.
  final double? lastUsedAmount;

  FoodLog({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
    this.amount = 100.0,
    this.mealType,
    this.lastUsedAmount,
  });

  // _Unset sentinel lets copyWith distinguish "pass null" from "omit argument".
  static const Object _unset = Object();

  FoodLog copyWith({
    Object? id = _unset,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? date,
    double? amount,
    MealType? mealType,
    Object? lastUsedAmount = _unset,
  }) =>
      FoodLog(
        id: id == _unset ? this.id : id as int?,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        mealType: mealType ?? this.mealType,
        lastUsedAmount: lastUsedAmount == _unset ? this.lastUsedAmount : lastUsedAmount as double?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'date': date.toIso8601String(),
        'amount': amount,
        'meal_type': mealType?.name,
      };

  static FoodLog fromJson(Map<String, dynamic> json) => FoodLog(
        id: json['id'] as int?,
        name: json['name'] as String,
        calories: json['calories'] as int,
        protein: json['protein'] as double,
        carbs: json['carbs'] as double,
        fat: json['fat'] as double,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num?)?.toDouble() ?? 100.0,
        mealType: MealType.fromString(json['meal_type'] as String?),
      );
}

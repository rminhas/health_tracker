class FoodLog {
  final int? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime date;
  final double amount;

  FoodLog({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
    this.amount = 100.0,
  });

  FoodLog copyWith({
    int? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? date,
    double? amount,
  }) =>
      FoodLog(
        id: id ?? this.id,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        date: date ?? this.date,
        amount: amount ?? this.amount,
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
      );
}

class WeightLog {
  final int? id;
  final double weight;
  final DateTime date;

  WeightLog({
    this.id,
    required this.weight,
    required this.date,
  });

  WeightLog copyWith({
    int? id,
    double? weight,
    DateTime? date,
  }) =>
      WeightLog(
        id: id ?? this.id,
        weight: weight ?? this.weight,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weight': weight,
        'date': date.toIso8601String(),
      };

  static WeightLog fromJson(Map<String, dynamic> json) => WeightLog(
        id: json['id'] as int?,
        weight: json['weight'] as double,
        date: DateTime.parse(json['date'] as String),
      );
}

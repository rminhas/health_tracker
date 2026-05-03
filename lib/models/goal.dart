class Goal {
  final double targetWeightKg;
  final double weeklyChangeRateKg; // e.g. -0.5 for losing 0.5kg/week, 0.5 for gaining, 0 for maintenance

  Goal({
    required this.targetWeightKg,
    required this.weeklyChangeRateKg,
  });

  Goal copyWith({
    double? targetWeightKg,
    double? weeklyChangeRateKg,
  }) {
    return Goal(
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      weeklyChangeRateKg: weeklyChangeRateKg ?? this.weeklyChangeRateKg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetWeightKg': targetWeightKg,
      'weeklyChangeRateKg': weeklyChangeRateKg,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      targetWeightKg: (json['targetWeightKg'] as num).toDouble(),
      weeklyChangeRateKg: (json['weeklyChangeRateKg'] as num).toDouble(),
    );
  }
}

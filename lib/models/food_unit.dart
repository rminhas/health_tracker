enum FoodUnit {
  g(label: 'g', toGrams: 1.0, isVolume: false),
  oz(label: 'oz', toGrams: 28.3495, isVolume: false),
  lbs(label: 'lbs', toGrams: 453.592, isVolume: false),
  ml(label: 'ml', toGrams: 1.0, isVolume: true),
  cups(label: 'cups', toGrams: 240.0, isVolume: true);

  const FoodUnit({
    required this.label,
    required this.toGrams,
    required this.isVolume,
  });

  final String label;

  /// Multiply an amount in this unit by [toGrams] to get the gram equivalent.
  final double toGrams;

  /// True for ml and cups — conversion assumes density ≈ 1 g/ml.
  final bool isVolume;
}

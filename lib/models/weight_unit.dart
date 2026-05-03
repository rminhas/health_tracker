enum WeightUnit { kg, lbs }

extension WeightUnitExt on WeightUnit {
  String get label => this == WeightUnit.kg ? 'kg' : 'lbs';
  String get rateLabel => this == WeightUnit.kg ? 'kg/week' : 'lbs/week';
  double toDisplay(double kg) => this == WeightUnit.kg ? kg : kg * 2.20462;
  double toKg(double display) => this == WeightUnit.kg ? display : display / 2.20462;
}

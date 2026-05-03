import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/food_log.dart';
import 'package:health_tracker/models/weight_log.dart';

void main() {
  group('Model Serialization Tests', () {
    test('FoodLog to/from JSON', () {
      final date = DateTime.now();
      final log = FoodLog(
        id: 1,
        name: 'Apple',
        calories: 95,
        protein: 0.5,
        carbs: 25.0,
        fat: 0.3,
        date: date,
      );

      final json = log.toJson();
      final fromJson = FoodLog.fromJson(json);

      expect(fromJson.id, log.id);
      expect(fromJson.name, log.name);
      expect(fromJson.calories, log.calories);
      expect(fromJson.date.toIso8601String(), date.toIso8601String());
    });

    test('WeightLog to/from JSON', () {
      final date = DateTime.now();
      final log = WeightLog(
        id: 1,
        weight: 75.5,
        date: date,
      );

      final json = log.toJson();
      final fromJson = WeightLog.fromJson(json);

      expect(fromJson.id, log.id);
      expect(fromJson.weight, log.weight);
      expect(fromJson.date.toIso8601String(), date.toIso8601String());
    });
  });
}

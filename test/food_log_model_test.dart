import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/food_log.dart';
import 'package:health_tracker/models/food_unit.dart';
import 'package:health_tracker/models/meal_type.dart';

void main() {
  final base = FoodLog(
    id: 5,
    name: 'Chicken Breast',
    calories: 165,
    protein: 31.0,
    carbs: 0.0,
    fat: 3.6,
    date: DateTime(2024, 6, 1, 12, 0),
    amount: 150.0,
    mealType: MealType.lunch,
  );

  group('FoodLog.copyWith', () {
    test('copyWith(id: null) clears the id', () {
      final copy = base.copyWith(id: null);
      expect(copy.id, isNull);
    });

    test('copyWith() with no arguments preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.name, base.name);
      expect(copy.calories, base.calories);
      expect(copy.protein, base.protein);
      expect(copy.carbs, base.carbs);
      expect(copy.fat, base.fat);
      expect(copy.date, base.date);
      expect(copy.amount, base.amount);
    });

    test('copyWith overrides only the specified fields', () {
      final copy = base.copyWith(calories: 200, name: 'Grilled Chicken');
      expect(copy.name, 'Grilled Chicken');
      expect(copy.calories, 200);
      // Everything else unchanged.
      expect(copy.id, base.id);
      expect(copy.protein, base.protein);
      expect(copy.amount, base.amount);
    });

    test('copyWith with a new non-null id replaces the id', () {
      final copy = base.copyWith(id: 99);
      expect(copy.id, 99);
    });
  });

  group('FoodLog serialization', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final copy = FoodLog.fromJson(base.toJson());
      expect(copy.id, base.id);
      expect(copy.name, base.name);
      expect(copy.calories, base.calories);
      expect(copy.protein, base.protein);
      expect(copy.carbs, base.carbs);
      expect(copy.fat, base.fat);
      expect(copy.amount, base.amount);
      expect(copy.date.toIso8601String(), base.date.toIso8601String());
    });

    test('toJson includes id when present', () {
      final json = base.toJson();
      expect(json['id'], 5);
    });

    test('toJson produces null id for a food with no id', () {
      final noId = base.copyWith(id: null);
      expect(noId.toJson()['id'], isNull);
    });

    test('fromJson with null id deserializes to null id', () {
      final json = base.toJson();
      json['id'] = null;
      final log = FoodLog.fromJson(json);
      expect(log.id, isNull);
    });

    test('fromJson defaults amount to 100g when key is absent', () {
      final json = base.toJson()..remove('amount');
      final log = FoodLog.fromJson(json);
      expect(log.amount, 100.0);
    });
  });

  group('FoodUnit conversions', () {
    test('g has a toGrams factor of 1.0', () {
      expect(FoodUnit.g.toGrams, 1.0);
    });

    test('oz converts to ~28.35g', () {
      expect(FoodUnit.oz.toGrams, closeTo(28.3495, 0.001));
    });

    test('lbs converts to ~453.59g', () {
      expect(FoodUnit.lbs.toGrams, closeTo(453.592, 0.001));
    });

    test('ml converts to 1.0g (liquid density assumption)', () {
      expect(FoodUnit.ml.toGrams, 1.0);
    });

    test('cups converts to 240g (liquid density assumption)', () {
      expect(FoodUnit.cups.toGrams, 240.0);
    });

    test('only ml and cups are flagged as volume units', () {
      expect(FoodUnit.g.isVolume, isFalse);
      expect(FoodUnit.oz.isVolume, isFalse);
      expect(FoodUnit.lbs.isVolume, isFalse);
      expect(FoodUnit.ml.isVolume, isTrue);
      expect(FoodUnit.cups.isVolume, isTrue);
    });

    // Macro scaling via unit conversion — the same logic used in _logFood.
    test('1 oz of a 100 kcal/100g food yields ~28.3 kcal', () {
      const calsPerHundredG = 100;
      final gramsEquivalent = 1.0 * FoodUnit.oz.toGrams; // ~28.35g
      final ratio = gramsEquivalent / 100.0;
      final kcal = calsPerHundredG * ratio;
      expect(kcal, closeTo(28.35, 0.1));
    });

    test('1 lbs of a 100 kcal/100g food yields ~453.6 kcal', () {
      const calsPerHundredG = 100;
      final gramsEquivalent = 1.0 * FoodUnit.lbs.toGrams;
      final ratio = gramsEquivalent / 100.0;
      final kcal = calsPerHundredG * ratio;
      expect(kcal, closeTo(453.6, 0.1));
    });

    test('1 cup of a 42 kcal/100g food yields ~100.8 kcal', () {
      const calsPerHundredG = 42; // e.g. whole milk
      final gramsEquivalent = 1.0 * FoodUnit.cups.toGrams; // 240g
      final ratio = gramsEquivalent / 100.0;
      final kcal = calsPerHundredG * ratio;
      expect(kcal, closeTo(100.8, 0.1));
    });

    test('amount stored is always the gram equivalent regardless of unit', () {
      // 2 cups → 480g stored
      final gramsEquivalent = 2.0 * FoodUnit.cups.toGrams;
      expect(gramsEquivalent, 480.0);
    });
  });

  group('MealType', () {
    test('fromString roundtrips each value', () {
      for (final type in MealType.values) {
        expect(MealType.fromString(type.name), type);
      }
    });

    test('fromString(null) returns null', () {
      expect(MealType.fromString(null), isNull);
    });

    test('fromString with unknown string falls back to snack', () {
      expect(MealType.fromString('unknown_value'), MealType.snack);
    });

    test('suggest() returns a valid MealType', () {
      expect(MealType.values, contains(MealType.suggest()));
    });

    test('mealType survives toJson / fromJson roundtrip', () {
      final copy = FoodLog.fromJson(base.toJson());
      expect(copy.mealType, MealType.lunch);
    });

    test('null mealType survives toJson / fromJson roundtrip', () {
      final noType = base.copyWith(id: null)
        ..toJson(); // just making sure it doesn't throw
      final log = FoodLog(
        name: 'Test',
        calories: 100,
        protein: 5.0,
        carbs: 10.0,
        fat: 2.0,
        date: DateTime(2024, 1, 1),
      );
      final copy = FoodLog.fromJson(log.toJson());
      expect(copy.mealType, isNull);
    });

    test('copyWith preserves mealType when not specified', () {
      final copy = base.copyWith(calories: 200);
      expect(copy.mealType, MealType.lunch);
    });

    test('copyWith can change mealType', () {
      final copy = base.copyWith(mealType: MealType.dinner);
      expect(copy.mealType, MealType.dinner);
    });
  });
}

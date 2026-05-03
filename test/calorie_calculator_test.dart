import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/user_profile.dart';
import 'package:health_tracker/models/goal.dart';
import 'package:health_tracker/services/calorie_calculator.dart';

void main() {
  group('CalorieCalculatorService Tests', () {
    test('calculateBMR for Male', () {
      final profile = UserProfile(
        age: 30,
        heightCm: 180,
        biologicalSex: 'Male',
        activityLevel: 'Sedentary',
      );
      // (10 * 80) + (6.25 * 180) - (5 * 30) + 5 = 800 + 1125 - 150 + 5 = 1780
      final bmr = CalorieCalculatorService.calculateBMR(profile, 80.0);
      expect(bmr, 1780.0);
    });

    test('calculateBMR for Female', () {
      final profile = UserProfile(
        age: 25,
        heightCm: 165,
        biologicalSex: 'Female',
        activityLevel: 'Sedentary',
      );
      // (10 * 65) + (6.25 * 165) - (5 * 25) - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
      final bmr = CalorieCalculatorService.calculateBMR(profile, 65.0);
      expect(bmr, 1395.25);
    });

    test('calculateTDEE for Moderately Active', () {
      final tdee = CalorieCalculatorService.calculateTDEE(2000, 'Moderately Active');
      // 2000 * 1.55 = 3100
      expect(tdee, 3100.0);
    });

    test('calculateDailyTargetCalories for weight loss', () {
      final goal = Goal(targetWeightKg: 70, weeklyChangeRateKg: -0.5);
      // Daily change = (-0.5 * 7700) / 7 = -550
      // TDEE = 2500 -> Target = 1950
      final target = CalorieCalculatorService.calculateDailyTargetCalories(2500.0, goal);
      expect(target, 1950);
    });
  });
}

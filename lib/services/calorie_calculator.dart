import '../models/user_profile.dart';
import '../models/goal.dart';

class CalorieCalculatorService {
  /// Calculates Base Metabolic Rate (BMR) using Mifflin-St Jeor equation
  static double calculateBMR(UserProfile profile, double currentWeightKg) {
    double bmr = (10 * currentWeightKg) + (6.25 * profile.heightCm) - (5 * profile.age);
    
    if (profile.biologicalSex.toLowerCase() == 'male') {
      bmr += 5;
    } else {
      bmr -= 161;
    }
    
    return bmr;
  }

  /// Calculates Total Daily Energy Expenditure (TDEE) based on activity level
  static double calculateTDEE(double bmr, String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        return bmr * 1.2;
      case 'lightly active':
        return bmr * 1.375;
      case 'moderately active':
        return bmr * 1.55;
      case 'very active':
        return bmr * 1.725;
      case 'super active':
        return bmr * 1.9;
      default:
        return bmr * 1.2;
    }
  }

  /// Calculates the target daily calories based on TDEE and Goal
  /// 1 kg of body weight is roughly equivalent to 7700 kcal
  static int calculateDailyTargetCalories(double tdee, Goal goal) {
    // kcal per day change = (weekly change in kg * 7700 kcal/kg) / 7 days
    double dailyChangeKcal = (goal.weeklyChangeRateKg * 7700) / 7;
    return (tdee + dailyChangeKcal).round();
  }
}

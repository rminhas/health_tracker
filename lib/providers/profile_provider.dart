import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/goal.dart';
import '../models/weight_log.dart';
import '../models/weight_unit.dart';
import '../database/database_helper.dart';
import '../services/calorie_calculator.dart';
import '../services/health_service.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  Goal? _goal;
  WeightLog? _latestWeightLog;
  WeightUnit _weightUnit = WeightUnit.kg;
  bool _isLoading = true;

  UserProfile? get profile => _profile;
  Goal? get goal => _goal;
  WeightLog? get latestWeightLog => _latestWeightLog;
  WeightUnit get weightUnit => _weightUnit;
  bool get isLoading => _isLoading;

  int get targetCalories {
    if (_profile == null || _goal == null || _latestWeightLog == null) {
      return 2000; // Fallback default
    }
    
    final bmr = CalorieCalculatorService.calculateBMR(_profile!, _latestWeightLog!.weight);
    final tdee = CalorieCalculatorService.calculateTDEE(bmr, _profile!.activityLevel);
    return CalorieCalculatorService.calculateDailyTargetCalories(tdee, _goal!);
  }

  Future<void> loadProfileData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      _profile = UserProfile.fromJson(json.decode(profileJson));
    }

    final goalJson = prefs.getString('user_goal');
    if (goalJson != null) {
      _goal = Goal.fromJson(json.decode(goalJson));
    }

    _weightUnit = prefs.getString('weight_unit') == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;

    final weightLogs = await DatabaseHelper.instance.readAllWeightLogs();
    if (weightLogs.isNotEmpty) {
      _latestWeightLog = weightLogs.first; // ordered by date DESC
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(profile.toJson()));
    notifyListeners();
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    _weightUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit.name);
    notifyListeners();
  }

  Future<void> saveGoal(Goal goal) async {
    _goal = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_goal', json.encode(goal.toJson()));
    notifyListeners();
  }

  Future<void> logWeight(double weight) async {
    final newLog = WeightLog(weight: weight, date: DateTime.now());
    final savedLog = await DatabaseHelper.instance.createWeightLog(newLog);
    _latestWeightLog = savedLog;
    
    final healthService = HealthService();
    await healthService.writeWeight(weight);
    
    notifyListeners();
  }
}

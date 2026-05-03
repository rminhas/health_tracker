import 'package:flutter/material.dart';

class WorkoutLog {
  final String activityType; // raw enum .name from health package (camelCase)
  final int durationMinutes;
  final int caloriesBurned;
  final DateTime startTime;

  const WorkoutLog({
    required this.activityType,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.startTime,
  });

  String get displayName {
    // "cyclingIndoor" → "Cycling Indoor"
    final spaced = activityType.replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (m) => ' ${m.group(0)}',
    );
    return spaced.isEmpty ? activityType : spaced[0].toUpperCase() + spaced.substring(1);
  }

  IconData get icon {
    switch (activityType) {
      case 'cycling':
      case 'cyclingIndoor':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'swimming':
      case 'swimmingOpenWater':
        return Icons.pool;
      case 'yoga':
        return Icons.self_improvement;
      case 'hiking':
        return Icons.landscape;
      case 'tennis':
        return Icons.sports_tennis;
      case 'basketball':
        return Icons.sports_basketball;
      case 'soccer':
      case 'football':
        return Icons.sports_soccer;
      case 'traditionalStrengthTraining':
      case 'functionalStrengthTraining':
        return Icons.fitness_center;
      case 'highIntensityIntervalTraining':
        return Icons.timer;
      case 'elliptical':
      case 'crossTraining':
        return Icons.nordic_walking;
      case 'dance':
      case 'danceInspiredTraining':
        return Icons.music_note;
      case 'rowing':
        return Icons.rowing;
      default:
        return Icons.fitness_center;
    }
  }
}

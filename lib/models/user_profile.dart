class UserProfile {
  final int age;
  final double heightCm;
  final String biologicalSex; // 'Male' or 'Female'
  final String activityLevel; // 'Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active', 'Super Active'

  UserProfile({
    required this.age,
    required this.heightCm,
    required this.biologicalSex,
    required this.activityLevel,
  });

  UserProfile copyWith({
    int? age,
    double? heightCm,
    String? biologicalSex,
    String? activityLevel,
  }) {
    return UserProfile(
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'heightCm': heightCm,
      'biologicalSex': biologicalSex,
      'activityLevel': activityLevel,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      age: json['age'] as int,
      heightCm: (json['heightCm'] as num).toDouble(),
      biologicalSex: json['biologicalSex'] as String,
      activityLevel: json['activityLevel'] as String,
    );
  }
}

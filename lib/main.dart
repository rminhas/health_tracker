import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/food_log_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FoodLogProvider()..loadLogs()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..loadProfileData()),
      ],
      child: MaterialApp(
        title: 'Health Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system, // Prioritize speed and modern look
        home: const DashboardScreen(),
      ),
    );
  }
}

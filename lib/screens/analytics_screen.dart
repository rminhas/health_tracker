import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/weight_log.dart';
import '../models/weight_unit.dart';
import '../models/food_log.dart';
import '../database/database_helper.dart';
import '../providers/food_log_provider.dart';
import '../providers/profile_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<WeightLog> _weightLogs = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await DatabaseHelper.instance.readAllWeightLogs();
    setState(() {
      _weightLogs = List.from(logs)..sort((a, b) => a.date.compareTo(b.date));
      _isLoading = false;
    });
  }

  double _getAverageDailyCalories(List<FoodLog> logs, int days) {
    if (logs.isEmpty) return 0;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final recentLogs = logs.where((log) => log.date.isAfter(cutoff)).toList();
    if (recentLogs.isEmpty) return 0;

    int totalCalories = recentLogs.fold(0, (sum, log) => sum + log.calories);
    final uniqueDays = recentLogs.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet();
    return totalCalories / (uniqueDays.isEmpty ? 1 : uniqueDays.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final foodProvider = context.watch<FoodLogProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCalendar(foodProvider),
            const Divider(height: 32),
            const Text('Weight Progression', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildWeightChart(profileProvider),
            const Divider(height: 32),
            const Text('Macronutrient Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatSummaries(foodProvider.foodLogs),
            const SizedBox(height: 24),
            const Text('Calorie Split (All Time)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMacroPieChart(foodProvider.foodLogs),
            const SizedBox(height: 24),
            const Text('Daily Macros (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMacroStackedBarChart(foodProvider.foodLogs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(FoodLogProvider foodProvider) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      eventLoader: (day) {
        final events = foodProvider.foodLogs.where((log) => isSameDay(log.date, day)).toList();
        return events;
      },
      calendarStyle: const CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildWeightChart(ProfileProvider profileProvider) {
    if (_weightLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No weight logs available to chart.'),
      );
    }

    final unit = profileProvider.weightUnit;

    List<FlSpot> spots = [];
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (int i = 0; i < _weightLogs.length; i++) {
      final v = unit.toDisplay(_weightLogs[i].weight);
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
      spots.add(FlSpot(i.toDouble(), v));
    }

    final targetDisplay = profileProvider.goal?.targetWeightKg != null
        ? unit.toDisplay(profileProvider.goal!.targetWeightKg)
        : null;
    if (targetDisplay != null) {
      if (targetDisplay < minVal) minVal = targetDisplay;
      if (targetDisplay > maxVal) maxVal = targetDisplay;
    }

    final padding = unit == WeightUnit.lbs ? 11.0 : 5.0;

    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LineChart(
        LineChartData(
          minY: minVal - padding,
          maxY: maxVal + padding,
          extraLinesData: targetDisplay != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: targetDisplay,
                    color: Colors.red,
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                      labelResolver: (line) =>
                          'Target: ${line.y.toStringAsFixed(1)} ${unit.label}',
                    ),
                  ),
                ])
              : const ExtraLinesData(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true, color: Colors.teal.withValues(alpha: 0.2)),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text(unit.label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              axisNameSize: 20,
              sideTitles: const SideTitles(showTitles: true, reservedSize: 44),
            ),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildStatSummaries(List<FoodLog> logs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Last 7 Days', _getAverageDailyCalories(logs, 7)),
          _buildStatCard('Last 30 Days', _getAverageDailyCalories(logs, 30)),
          _buildStatCard('Last Year', _getAverageDailyCalories(logs, 365)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double avgCalories) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('${avgCalories.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('avg/day', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMacroPieChart(List<FoodLog> logs) {
    if (logs.isEmpty) return const Text('No food logged yet.');

    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var log in logs) {
      totalProtein += log.protein;
      totalCarbs += log.carbs;
      totalFat += log.fat;
    }

    double proteinCals = totalProtein * 4;
    double carbsCals = totalCarbs * 4;
    double fatCals = totalFat * 9;
    double totalCals = proteinCals + carbsCals + fatCals;

    if (totalCals == 0) return const Text('No macro data.');

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(color: Colors.red, value: proteinCals, title: '${((proteinCals/totalCals)*100).toStringAsFixed(1)}%\nProtein', radius: 60, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            PieChartSectionData(color: Colors.blue, value: carbsCals, title: '${((carbsCals/totalCals)*100).toStringAsFixed(1)}%\nCarbs', radius: 60, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            PieChartSectionData(color: Colors.amber, value: fatCals, title: '${((fatCals/totalCals)*100).toStringAsFixed(1)}%\nFat', radius: 60, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildMacroStackedBarChart(List<FoodLog> logs) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 6));
    
    // Group by day (0 to 6)
    Map<int, Map<String, double>> dailyMacros = {};
    for (int i = 0; i < 7; i++) {
      dailyMacros[i] = {'protein': 0, 'carbs': 0, 'fat': 0};
    }

    for (var log in logs) {
      if (log.date.isAfter(cutoff) || isSameDay(log.date, cutoff)) {
        final dayDiff = now.difference(DateTime(log.date.year, log.date.month, log.date.day)).inDays;
        int index = 6 - dayDiff; // 6 is today, 0 is 6 days ago
        if (index >= 0 && index <= 6) {
          dailyMacros[index]!['protein'] = dailyMacros[index]!['protein']! + log.protein;
          dailyMacros[index]!['carbs'] = dailyMacros[index]!['carbs']! + log.carbs;
          dailyMacros[index]!['fat'] = dailyMacros[index]!['fat']! + log.fat;
        }
      }
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 7; i++) {
      final p = dailyMacros[i]!['protein']!;
      final c = dailyMacros[i]!['carbs']!;
      final f = dailyMacros[i]!['fat']!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p + c + f,
              rodStackItems: [
                BarChartRodStackItem(0, p, Colors.red),
                BarChartRodStackItem(p, p + c, Colors.blue),
                BarChartRodStackItem(p + c, p + c + f, Colors.amber),
              ],
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = now.subtract(Duration(days: 6 - value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${day.day}/${day.month}', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

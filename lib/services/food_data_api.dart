import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_log.dart';
import '../config/secrets.dart';

class FoodDataService {
  static const String _apiKey = usdaApiKey;
  static const String _usdaBase = 'api.nal.usda.gov';
  static const String _offBase = 'world.openfoodfacts.org';
  static const Map<String, String> _offHeaders = {'User-Agent': 'HealthTracker/1.0'};

  Future<List<FoodLog>> searchFood(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.https(_usdaBase, '/fdc/v1/foods/search', {
      'api_key': _apiKey,
      'query': query,
      'pageSize': '10',
    });

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List foods = data['foods'] ?? [];

      return foods.map((foodData) {
        final foodNutrients = foodData['foodNutrients'] as List? ?? [];

        double getNutrient(String name) {
          final nutrient = foodNutrients.firstWhere(
            (n) => n['nutrientName'] == name,
            orElse: () => {'value': 0.0},
          );
          return (nutrient['value'] as num?)?.toDouble() ?? 0.0;
        }

        return FoodLog(
          name: foodData['description'] ?? 'Unknown',
          calories: getNutrient('Energy').toInt(),
          protein: getNutrient('Protein'),
          carbs: getNutrient('Carbohydrate, by difference'),
          fat: getNutrient('Total lipid (fat)'),
          date: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  Future<FoodLog?> lookupBarcode(String barcode) async {
    final url = Uri.https(_offBase, '/api/v0/product/$barcode.json');

    try {
      final response = await http.get(url, headers: _offHeaders);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      double n(String key) => (nutriments[key] as num?)?.toDouble() ?? 0.0;

      return FoodLog(
        name: (product['product_name'] as String?)?.trim().isNotEmpty == true
            ? product['product_name'] as String
            : 'Unknown',
        calories: n('energy-kcal_100g').toInt(),
        protein: n('proteins_100g'),
        carbs: n('carbohydrates_100g'),
        fat: n('fat_100g'),
        date: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error fetching barcode data: $e');
    }
  }
}

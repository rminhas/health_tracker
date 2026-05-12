import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_log.dart';
import '../config/secrets.dart';
import '../database/database_helper.dart';

class FoodDataService {
  static const String _apiKey = usdaApiKey;
  static const String _usdaBase = 'api.nal.usda.gov';
  static const String _offBase = 'world.openfoodfacts.org';
  static const Map<String, String> _offHeaders = {'User-Agent': 'HealthTracker/1.0'};

  final http.Client _client;

  FoodDataService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<FoodLog>> searchFood(String query) async {
    if (query.isEmpty) return [];

    final cacheKey = query.trim().toLowerCase();

    final cached = await DatabaseHelper.instance.readCachedSearch(cacheKey);
    if (cached != null) return cached;

    final url = Uri.https(_usdaBase, '/fdc/v1/foods/search', {
      'api_key': _apiKey,
      'query': query,
      'pageSize': '10',
    });

    try {
      final response = await _client.get(url);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List foods = data['foods'] ?? [];

      final results = foods.map((foodData) {
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

      await DatabaseHelper.instance.writeCachedSearch(cacheKey, results);
      return results;
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  Future<FoodLog?> lookupBarcode(String barcode) async {
    // Try the scanned code, then its UPC-A ↔ EAN-13 counterpart.
    // Scanners sometimes return a 13-digit EAN-13 for a product indexed under
    // its 12-digit UPC-A (or vice-versa); trying both avoids spurious misses.
    for (final candidate in _barcodeVariants(barcode.trim())) {
      final result = await _lookupSingleBarcode(candidate);
      if (result != null) return result;
    }
    return null;
  }

  /// Returns the barcode itself plus its UPC-A / EAN-13 counterpart when one
  /// can be derived by stripping or adding a leading zero.
  List<String> _barcodeVariants(String barcode) {
    if (barcode.length == 13 && barcode.startsWith('0')) {
      return [barcode, barcode.substring(1)]; // EAN-13 → also try UPC-A
    }
    if (barcode.length == 12) {
      return [barcode, '0$barcode']; // UPC-A → also try EAN-13
    }
    return [barcode];
  }

  Future<FoodLog?> _lookupSingleBarcode(String barcode) async {
    final url = Uri.https(_offBase, '/api/v0/product/$barcode.json');

    try {
      final response = await _client.get(url, headers: _offHeaders);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      double n(String key) => (nutriments[key] as num?)?.toDouble() ?? 0.0;

      double kcal = n('energy-kcal_100g');
      if (kcal == 0) {
        final kj = n('energy_100g');
        if (kj > 0) kcal = kj / 4.184;
      }

      return FoodLog(
        name: (product['product_name'] as String?)?.trim().isNotEmpty == true
            ? product['product_name'] as String
            : 'Unknown',
        calories: kcal.round(),
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

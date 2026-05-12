import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:health_tracker/database/database_helper.dart';
import 'package:health_tracker/models/food_log.dart';
import 'package:health_tracker/services/food_data_api.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FoodLog _food({String name = 'Apple', int calories = 95}) => FoodLog(
      name: name,
      calories: calories,
      protein: 1.0,
      carbs: 25.0,
      fat: 0.3,
      date: DateTime(2024, 1, 1),
    );

/// Builds a USDA-style JSON response body for a single food item.
String _usdaBody(String description, {int kcal = 95}) => json.encode({
      'foods': [
        {
          'description': description,
          'foodNutrients': [
            {'nutrientName': 'Energy', 'value': kcal},
            {'nutrientName': 'Protein', 'value': 1.0},
            {'nutrientName': 'Carbohydrate, by difference', 'value': 25.0},
            {'nutrientName': 'Total lipid (fat)', 'value': 0.3},
          ],
        }
      ]
    });

MockClient _mockClient(String body, {int status = 200}) => MockClient((_) async =>
    http.Response(body, status, headers: {'content-type': 'application/json'}));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.useInMemoryForTesting();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  // -------------------------------------------------------------------------
  // DB-level cache tests
  // -------------------------------------------------------------------------

  group('DatabaseHelper search cache', () {
    test('cache miss returns null for unseen query', () async {
      final result = await DatabaseHelper.instance.readCachedSearch('apple');
      expect(result, isNull);
    });

    test('write then read returns same results', () async {
      final foods = [_food(name: 'Apple', calories: 95), _food(name: 'Green Apple', calories: 80)];
      await DatabaseHelper.instance.writeCachedSearch('apple', foods);

      final cached = await DatabaseHelper.instance.readCachedSearch('apple');
      expect(cached, isNotNull);
      expect(cached!.length, 2);
      expect(cached[0].name, 'Apple');
      expect(cached[1].name, 'Green Apple');
    });

    test('expired entry returns null', () async {
      await DatabaseHelper.instance.writeCachedSearch('banana', [_food(name: 'Banana')]);

      // Read with a tiny TTL so the entry is immediately stale.
      final result = await DatabaseHelper.instance.readCachedSearch(
        'banana',
        ttl: Duration.zero,
      );
      expect(result, isNull);
    });

    test('different queries are stored independently', () async {
      await DatabaseHelper.instance.writeCachedSearch('apple', [_food(name: 'Apple')]);
      await DatabaseHelper.instance.writeCachedSearch('banana', [_food(name: 'Banana')]);

      final appleCache = await DatabaseHelper.instance.readCachedSearch('apple');
      final bananaCache = await DatabaseHelper.instance.readCachedSearch('banana');

      expect(appleCache!.first.name, 'Apple');
      expect(bananaCache!.first.name, 'Banana');
    });

    test('writing the same query twice replaces the entry', () async {
      await DatabaseHelper.instance.writeCachedSearch('apple', [_food(name: 'Apple')]);
      await DatabaseHelper.instance.writeCachedSearch('apple', [_food(name: 'Apple Updated')]);

      final cached = await DatabaseHelper.instance.readCachedSearch('apple');
      expect(cached!.length, 1);
      expect(cached.first.name, 'Apple Updated');
    });

    test('nutritional values survive cache roundtrip', () async {
      final food = FoodLog(
        name: 'Oats',
        calories: 389,
        protein: 17.0,
        carbs: 66.0,
        fat: 7.0,
        date: DateTime(2024, 1, 1),
      );
      await DatabaseHelper.instance.writeCachedSearch('oats', [food]);

      final cached = await DatabaseHelper.instance.readCachedSearch('oats');
      final result = cached!.first;
      expect(result.name, 'Oats');
      expect(result.calories, 389);
      expect(result.protein, 17.0);
      expect(result.carbs, 66.0);
      expect(result.fat, 7.0);
    });
  });

  // -------------------------------------------------------------------------
  // Service-level cache tests
  // -------------------------------------------------------------------------

  group('FoodDataService caching', () {
    test('API is called once; second identical query uses cache', () async {
      var callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response(
          _usdaBody('Apple'),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FoodDataService(client: client);

      await service.searchFood('apple');
      await service.searchFood('apple');

      expect(callCount, 1);
    });

    test('different queries each hit the API', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        final q = req.url.queryParameters['query'] ?? '';
        return http.Response(
          _usdaBody(q),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FoodDataService(client: client);
      await service.searchFood('apple');
      await service.searchFood('banana');

      expect(callCount, 2);
    });

    test('cached results are returned correctly by the service', () async {
      final service = FoodDataService(client: _mockClient(_usdaBody('Apple', kcal: 95)));

      final first = await service.searchFood('apple');
      final second = await service.searchFood('apple');

      expect(first.length, 1);
      expect(second.length, 1);
      expect(second.first.name, first.first.name);
      expect(second.first.calories, first.first.calories);
    });

    test('query is normalised (trimmed, lowercased) before cache lookup', () async {
      var callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response(
          _usdaBody('Apple'),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FoodDataService(client: client);
      await service.searchFood('Apple');
      await service.searchFood('  apple  ');

      // Both normalise to "apple" — only one API call.
      expect(callCount, 1);
    });
  });
}

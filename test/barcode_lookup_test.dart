// Integration test — requires network access and hits the live Open Food Facts API.
// Run with: flutter test test/barcode_lookup_test.dart
//
// Product: Atkins Chocolate Peanut Butter protein bar
//
// Two barcodes are tested:
//
//   637480021012  — 12-digit UPC-A visible on the wrapper in the reference photo.
//                   Confirmed to return full nutritional data from Open Food Facts.
//
//   9645400021012 — 13-digit EAN-13 returned by the in-app scanner on the same
//                   wrapper.  This is NOT a zero-padded variant of the UPC-A
//                   (9XX… ≠ 0637…), so it is likely a retailer or distribution
//                   barcode on the reverse side of the wrapper.  Open Food Facts
//                   does not index this code, which is why the scanner produced
//                   "Product Not Found" even though the UPC-A lookup succeeds.
//
// The EAN-13/UPC-A normalization added to lookupBarcode (stripping/adding a
// leading zero) fixes the common class of mismatches but cannot bridge barcodes
// that are genuinely unrelated.  If 9645400021012 needs to resolve, the product
// must be added to Open Food Facts under that code.
//
// Serving size: 60 g  →  API returns nutrients per 100 g, so label values ÷ 0.6.
//
//   Label (per 60 g)  │ Per 100 g (API)
//   ──────────────────┼──────────────────────────────────────────
//   Calories 250 kcal │ ~490 kcal (standard calc; Atkins excludes
//                     │  sugar-alcohol calories on the label)
//   Protein   16 g    │ ~26.7 g
//   Carbs     23 g    │ ~38.3 g
//   Fat       15 g    │ ~25.0 g

import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/food_data_api.dart';

void main() {
  const networkTimeout = Timeout(Duration(seconds: 30));

  late FoodDataService service;
  setUp(() => service = FoodDataService());

  // Serving size on the physical label.
  const servingG = 60.0;

  // Per-100g helpers derived from per-serving label values.
  double per100g(num labelValue) => labelValue / servingG * 100;
  double tolerance(num expected) => expected * 0.25;

  // ---------------------------------------------------------------------------
  // Manufacturer UPC-A — confirmed working
  // ---------------------------------------------------------------------------

  group('UPC-A 637480021012 (manufacturer barcode — confirmed)', () {
    const barcode = '637480021012';

    test('returns a non-null result', () async {
      expect(await service.lookupBarcode(barcode), isNotNull);
    }, timeout: networkTimeout);

    test('product name references Atkins / Chocolate / Peanut', () async {
      final result = await service.lookupBarcode(barcode);
      expect(result, isNotNull);
      final name = result!.name.toLowerCase();
      expect(
        name.contains('atkins') || name.contains('chocolate') || name.contains('peanut'),
        isTrue,
        reason: 'Got: "${result.name}"',
      );
    }, timeout: networkTimeout);

    test('calories are in the right ballpark per 100 g', () async {
      final result = await service.lookupBarcode(barcode);
      expect(result, isNotNull);
      // Standard calc ≈ 490; Atkins net-carb calc ≈ 417. Accept either.
      final expected = per100g(250); // 416.7
      expect(result!.calories, closeTo(expected, expected * 0.50),
          reason: 'Got ${result.calories} kcal/100g');
    }, timeout: networkTimeout);

    test('protein ≈ ${per100g(16).toStringAsFixed(1)} g/100g', () async {
      final result = await service.lookupBarcode(barcode);
      expect(result, isNotNull);
      final expected = per100g(16);
      expect(result!.protein, closeTo(expected, tolerance(expected)),
          reason: 'Got ${result.protein}g/100g');
    }, timeout: networkTimeout);

    test('carbs ≈ ${per100g(23).toStringAsFixed(1)} g/100g', () async {
      final result = await service.lookupBarcode(barcode);
      expect(result, isNotNull);
      final expected = per100g(23);
      expect(result!.carbs, closeTo(expected, tolerance(expected)),
          reason: 'Got ${result.carbs}g/100g');
    }, timeout: networkTimeout);

    test('fat ≈ ${per100g(15).toStringAsFixed(1)} g/100g', () async {
      final result = await service.lookupBarcode(barcode);
      expect(result, isNotNull);
      final expected = per100g(15);
      expect(result!.fat, closeTo(expected, tolerance(expected)),
          reason: 'Got ${result.fat}g/100g');
    }, timeout: networkTimeout);
  });

  // ---------------------------------------------------------------------------
  // EAN-13 / UPC-A normalisation
  // ---------------------------------------------------------------------------

  group('EAN-13 / UPC-A normalisation', () {
    test('EAN-13 with leading zero resolves the same product as its UPC-A', () async {
      // 0637480021012 is the EAN-13 form of UPC-A 637480021012.
      final ean13 = await service.lookupBarcode('0637480021012');
      final upcA  = await service.lookupBarcode('637480021012');
      expect(ean13, isNotNull, reason: 'EAN-13 lookup returned null');
      expect(upcA,  isNotNull, reason: 'UPC-A lookup returned null');
      expect(ean13!.name, equals(upcA!.name));
    }, timeout: networkTimeout);
  });

  // ---------------------------------------------------------------------------
  // Retailer / distribution barcode returned by scanner — expected not found
  // ---------------------------------------------------------------------------

  group('EAN-13 9645400021012 (scanned barcode — retailer / distribution code)', () {
    const barcode = '9645400021012';

    test('returns null — not indexed in Open Food Facts under this code', () async {
      // This barcode was returned by the in-app scanner on the same wrapper.
      // It is not a zero-padded variant of the manufacturer UPC-A (9XX ≠ 0637),
      // so the EAN-13 normalisation cannot bridge the gap.  The expected
      // behaviour is null (graceful not-found), not an exception.
      final result = await service.lookupBarcode(barcode);
      expect(result, isNull,
          reason: 'If this passes with non-null the product has been added to '
              'Open Food Facts — update the test to validate the returned data.');
    }, timeout: networkTimeout);
  });
}

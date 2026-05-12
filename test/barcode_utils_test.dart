import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/utils/barcode_utils.dart';

void main() {
  group('BarcodeUtils.hasValidCheckDigit', () {
    group('UPC-A (12 digits)', () {
      test('accepts the Atkins bar manufacturer UPC', () {
        expect(BarcodeUtils.hasValidCheckDigit('637480021012'), isTrue);
      });

      test('rejects a UPC-A with a wrong check digit', () {
        // Last digit changed from 2 → 3.
        expect(BarcodeUtils.hasValidCheckDigit('637480021013'), isFalse);
      });

      test('rejects a UPC-A containing non-numeric characters', () {
        expect(BarcodeUtils.hasValidCheckDigit('63748002101X'), isFalse);
      });
    });

    group('EAN-13 (13 digits)', () {
      test('accepts the EAN-13 equivalent of the Atkins UPC', () {
        expect(BarcodeUtils.hasValidCheckDigit('0637480021012'), isTrue);
      });

      test('rejects an EAN-13 with a wrong check digit', () {
        expect(BarcodeUtils.hasValidCheckDigit('0637480021013'), isFalse);
      });

      test('rejects an EAN-13 containing non-numeric characters', () {
        expect(BarcodeUtils.hasValidCheckDigit('063748002101X'), isFalse);
      });

      // The specific corrupted scan from the Atkins wrapper incident.
      // It coincidentally passes the check-digit test (1-in-10 probability),
      // so the filter cannot catch it — documented here to make that explicit.
      test('9645400021012 (misread) coincidentally passes — cannot be rejected', () {
        expect(BarcodeUtils.hasValidCheckDigit('9645400021012'), isTrue);
      });
    });

    group('Other formats', () {
      test('passes through short codes without validating', () {
        expect(BarcodeUtils.hasValidCheckDigit('01234567'), isTrue); // EAN-8
      });

      test('passes through long / Code-128 codes without validating', () {
        expect(BarcodeUtils.hasValidCheckDigit('12345678901234'), isTrue);
      });

      test('passes through an empty string without throwing', () {
        expect(BarcodeUtils.hasValidCheckDigit(''), isTrue);
      });
    });
  });
}

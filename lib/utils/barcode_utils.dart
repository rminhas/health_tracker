class BarcodeUtils {
  /// Returns true if [barcode] passes the standard check-digit test for its
  /// length (UPC-A = 12, EAN-13 = 13). Returns true for any other length so
  /// that Code 128 and other formats are never incorrectly rejected.
  ///
  /// Note: a corrupted scan can coincidentally produce a valid check digit
  /// (~10 % probability), so this catches most — but not all — bad reads.
  static bool hasValidCheckDigit(String barcode) {
    switch (barcode.length) {
      case 12:
        return _check(barcode, evenWeight: 3, oddWeight: 1);
      case 13:
        return _check(barcode, evenWeight: 1, oddWeight: 3);
      default:
        return true;
    }
  }

  static bool _check(
    String barcode, {
    required int evenWeight,
    required int oddWeight,
  }) {
    var sum = 0;
    for (var i = 0; i < barcode.length - 1; i++) {
      final d = int.tryParse(barcode[i]);
      if (d == null) return false;
      sum += d * (i.isEven ? evenWeight : oddWeight);
    }
    final checkDigit = int.tryParse(barcode[barcode.length - 1]);
    if (checkDigit == null) return false;
    return (10 - sum % 10) % 10 == checkDigit;
  }
}

import 'geometry.dart';

class Validators {
  static String? positive(double? v, String label) {
    if (v == null) return '$label is required';
    if (v <= 0) return '$label must be greater than 0';
    return null;
  }

  static String? nonNegative(double? v, String label) {
    if (v == null) return '$label is required';
    if (v < 0) return '$label cannot be negative';
    return null;
  }

  static String? quantity(int? q) {
    if (q == null) return 'Quantity must be a whole number';
    if (q <= 0) return 'Quantity must be at least 1';
    return null;
  }

  /// Blocking problems for a polygon piece (empty list = valid).
  static List<String> polygonErrors(List<Pt> pts) {
    final e = <String>[];
    if (pts.length < 3) {
      e.add('A polygon needs at least 3 points');
      return e;
    }
    for (final p in pts) {
      if (p.x.isNaN || p.y.isNaN || p.x.isInfinite || p.y.isInfinite) {
        e.add('Every point needs valid X and Y values');
        return e;
      }
    }
    if (Geo.polygonArea(pts) < 1e-9) e.add('The polygon has zero area');
    if (Geo.isSelfIntersecting(pts)) {
      e.add('The outline crosses itself (self-intersecting); the area would be wrong');
    }
    return e;
  }
}

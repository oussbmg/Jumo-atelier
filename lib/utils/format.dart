import '../models/models.dart';

class Fmt {
  static double? parse(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  static String n(double v, [int d = 2]) {
    var s = v.toStringAsFixed(d);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    if (s == '-0') s = '0';
    return s;
  }

  static String cm(double v) => '${n(v)} cm';
  static String m2(double v) => '${n(v, 4)} m²';
  static String pct(double v) => '${n(v)} %';
  static String money(double v, String cur) => '${n(v)} $cur';

  static String dims(MarkerPiece p) {
    if (p.shape == ShapeType.rectangle) {
      return '${n(p.rectLength)} × ${n(p.rectWidth)}';
    }
    final b = p.bbox;
    return '${n(b.width)} × ${n(b.height)} (bbox, ${p.polygon.length} pts)';
  }

  static String shapeName(MarkerPiece p) =>
      p.shape == ShapeType.rectangle ? 'Rectangle' : 'Polygon';

  static String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

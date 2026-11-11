import 'dart:math' as math;

/// A 2D point. All geometry is in centimetres.
class Pt {
  final double x;
  final double y;
  const Pt(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Pt.fromJson(Map<String, dynamic> j) =>
      Pt((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class BBox {
  final double minX, minY, maxX, maxY;
  const BBox(this.minX, this.minY, this.maxX, this.maxY);
  double get width => maxX - minX;
  double get height => maxY - minY;
  Pt get center => Pt((minX + maxX) / 2, (minY + maxY) / 2);
}

/// Pure geometry helpers (no Flutter dependency, fully testable).
class Geo {
  static double polygonArea(List<Pt> p) {
    if (p.length < 3) return 0;
    double s = 0;
    for (int i = 0; i < p.length; i++) {
      final j = (i + 1) % p.length;
      s += p[i].x * p[j].y - p[j].x * p[i].y;
    }
    return s.abs() / 2;
  }

  static double dist(Pt a, Pt b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

  static double perimeter(List<Pt> p) {
    if (p.length < 2) return 0;
    double s = 0;
    for (int i = 0; i < p.length; i++) {
      s += dist(p[i], p[(i + 1) % p.length]);
    }
    return s;
  }

  static BBox bbox(List<Pt> p) {
    if (p.isEmpty) return const BBox(0, 0, 0, 0);
    double minX = p[0].x, maxX = p[0].x, minY = p[0].y, maxY = p[0].y;
    for (final q in p) {
      minX = math.min(minX, q.x);
      maxX = math.max(maxX, q.x);
      minY = math.min(minY, q.y);
      maxY = math.max(maxY, q.y);
    }
    return BBox(minX, minY, maxX, maxY);
  }

  /// Rotates [local] by [rotDeg] around the centre of its bounding box and
  /// moves that centre to ([cx],[cy]). Rotation never changes area/perimeter.
  static List<Pt> transform(List<Pt> local, double cx, double cy, double rotDeg) {
    if (local.isEmpty) return [];
    final c = bbox(local).center;
    final a = rotDeg * math.pi / 180.0;
    final ca = math.cos(a), sa = math.sin(a);
    return local.map((p) {
      final dx = p.x - c.x, dy = p.y - c.y;
      return Pt(dx * ca - dy * sa + cx, dx * sa + dy * ca + cy);
    }).toList();
  }

  static Pt centroid(List<Pt> p) {
    if (p.length < 3) return bbox(p).center;
    double a = 0, cx = 0, cy = 0;
    for (int i = 0; i < p.length; i++) {
      final j = (i + 1) % p.length;
      final cr = p[i].x * p[j].y - p[j].x * p[i].y;
      a += cr;
      cx += (p[i].x + p[j].x) * cr;
      cy += (p[i].y + p[j].y) * cr;
    }
    if (a.abs() < 1e-12) return bbox(p).center;
    return Pt(cx / (3 * a), cy / (3 * a));
  }

  static bool onSegment(Pt p, Pt a, Pt b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) return dist(p, a) < 1e-6;
    final len = math.sqrt(len2);
    final cross = dx * (p.y - a.y) - dy * (p.x - a.x);
    if (cross.abs() / len > 1e-6) return false;
    final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
    return t >= -1e-9 && t <= 1 + 1e-9;
  }

  static bool onBoundary(Pt p, List<Pt> poly) {
    for (int i = 0; i < poly.length; i++) {
      if (onSegment(p, poly[i], poly[(i + 1) % poly.length])) return true;
    }
    return false;
  }

  static bool _ray(Pt p, List<Pt> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool strictlyInside(Pt p, List<Pt> poly) =>
      poly.length >= 3 && !onBoundary(p, poly) && _ray(p, poly);

  static bool insideOrOn(Pt p, List<Pt> poly) =>
      poly.length >= 3 && (onBoundary(p, poly) || _ray(p, poly));

  static int _sgn(double v) => v > 1e-9 ? 1 : (v < -1e-9 ? -1 : 0);
  static double _cross(Pt a, Pt b, Pt c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  /// True only when segments cross at a single interior point (touching or
  /// collinear contact does not count).
  static bool properIntersect(Pt a, Pt b, Pt c, Pt d) {
    final s1 = _sgn(_cross(a, b, c)), s2 = _sgn(_cross(a, b, d));
    final s3 = _sgn(_cross(c, d, a)), s4 = _sgn(_cross(c, d, b));
    return s1 * s2 < 0 && s3 * s4 < 0;
  }

  static bool isSelfIntersecting(List<Pt> p) {
    final n = p.length;
    if (n < 4) return false;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (j == i + 1 || (i == 0 && j == n - 1)) continue;
        if (properIntersect(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n])) {
          return true;
        }
      }
    }
    return false;
  }

  /// True when the interiors of the two polygons overlap. Pieces that only
  /// touch along edges/corners are NOT overlapping (tolerance 1e-6 cm).
  static bool overlap(List<Pt> a, List<Pt> b) {
    if (a.length < 3 || b.length < 3) return false;
    final ba = bbox(a), bb = bbox(b);
    const t = 1e-7;
    if (ba.maxX <= bb.minX + t || bb.maxX <= ba.minX + t) return false;
    if (ba.maxY <= bb.minY + t || bb.maxY <= ba.minY + t) return false;
    for (int i = 0; i < a.length; i++) {
      for (int j = 0; j < b.length; j++) {
        if (properIntersect(a[i], a[(i + 1) % a.length], b[j], b[(j + 1) % b.length])) {
          return true;
        }
      }
    }
    bool probe(List<Pt> p, List<Pt> q) {
      for (int i = 0; i < p.length; i++) {
        final nx = p[(i + 1) % p.length];
        if (strictlyInside(p[i], q)) return true;
        final mid = Pt((p[i].x + nx.x) / 2, (p[i].y + nx.y) / 2);
        if (strictlyInside(mid, q)) return true;
      }
      // interior samples (mid-points of diagonals) catch identical/stacked shapes
      for (int i = 0; i < p.length; i++) {
        for (int j = i + 2; j < p.length; j++) {
          final m = Pt((p[i].x + p[j].x) / 2, (p[i].y + p[j].y) / 2);
          if (strictlyInside(m, p) && strictlyInside(m, q)) return true;
        }
      }
      return false;
    }

    return probe(a, b) || probe(b, a);
  }
}

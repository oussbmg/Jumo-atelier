import 'dart:math' as math;
import '../calculations/geometry.dart';
import '../models/models.dart';

enum PlaceStatus { ok, outside, overlap }

class PlacedInstance {
  final String key; // "<pieceId>#<index>"
  final MarkerPiece piece;
  final int index;
  final List<Pt> pts;
  final BBox box;
  PlacedInstance(this.key, this.piece, this.index, this.pts, this.box);
}

/// Placement logic: world geometry, validity checks, automatic free-spot search.
/// Designed so an automatic nesting algorithm can be plugged in later.
class PlacementService {
  static String keyOf(MarkerPiece p, int i) => '${p.id}#$i';

  static List<Pt> worldPoints(MarkerPiece p, Placement pl) =>
      Geo.transform(p.localPoints, pl.x, pl.y, pl.rotation);

  static List<PlacedInstance> instances(MarkerData m) {
    final out = <PlacedInstance>[];
    for (final p in m.pieces) {
      for (int i = 0; i < p.placements.length; i++) {
        final pts = worldPoints(p, p.placements[i]);
        out.add(PlacedInstance(keyOf(p, i), p, i, pts, Geo.bbox(pts)));
      }
    }
    return out;
  }

  static Map<String, PlaceStatus> statuses(MarkerData m, List<PlacedInstance> inst) {
    const t = 1e-6;
    final res = <String, PlaceStatus>{};
    for (final a in inst) {
      final b = a.box;
      final out = b.minX < -t ||
          b.minY < -t ||
          b.maxX > m.markerLengthCm + t ||
          b.maxY > m.fabricWidthCm + t;
      res[a.key] = out ? PlaceStatus.outside : PlaceStatus.ok;
    }
    for (int i = 0; i < inst.length; i++) {
      for (int j = i + 1; j < inst.length; j++) {
        if (Geo.overlap(inst[i].pts, inst[j].pts)) {
          if (res[inst[i].key] == PlaceStatus.ok) res[inst[i].key] = PlaceStatus.overlap;
          if (res[inst[j].key] == PlaceStatus.ok) res[inst[j].key] = PlaceStatus.overlap;
        }
      }
    }
    return res;
  }

  /// Finds the first free spot (scanning along the marker length) for one more
  /// copy of [piece]. Falls back to the marker origin (shown red) if none fits.
  static Placement autoPlace(MarkerData m, MarkerPiece piece, {double rotation = 0}) {
    final local = piece.localPoints;
    final rel = Geo.bbox(Geo.transform(local, 0, 0, rotation));
    final w = rel.width, h = rel.height;
    final others = instances(m);
    const step = 5.0;
    for (double tx = 0; tx + w <= m.markerLengthCm + 1e-9; tx += step) {
      for (double ty = 0; ty + h <= m.fabricWidthCm + 1e-9; ty += step) {
        final cx = tx - rel.minX, cy = ty - rel.minY;
        final poly = Geo.transform(local, cx, cy, rotation);
        final pb = Geo.bbox(poly);
        bool free = true;
        for (final o in others) {
          if (pb.maxX <= o.box.minX || o.box.maxX <= pb.minX) continue;
          if (pb.maxY <= o.box.minY || o.box.maxY <= pb.minY) continue;
          if (Geo.overlap(poly, o.pts)) {
            free = false;
            break;
          }
        }
        if (free) return Placement(x: cx, y: cy, rotation: rotation);
      }
    }
    return Placement(x: -rel.minX, y: -rel.minY, rotation: rotation);
  }

  /// Makes placements.length == quantity (adds auto-placed copies / trims).
  static void syncPlacements(MarkerData m, MarkerPiece p) {
    while (p.placements.length > math.max(p.quantity, 0)) {
      p.placements.removeLast();
    }
    while (p.placements.length < p.quantity) {
      p.placements.add(autoPlace(m, p));
    }
  }
}

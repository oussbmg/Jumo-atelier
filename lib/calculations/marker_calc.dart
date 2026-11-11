import '../models/models.dart';

/// Cost/area figures for one piece definition (all its copies together).
class PieceCostRow {
  final MarkerPiece piece;
  final double areaEachM2;
  final double totalAreaM2;
  final double shareOfMarker; // 0..1 of marker area
  final double shareOfPieces; // 0..1 of total pieces area
  final double allocatedCost; // waste-inclusive: sums to the marker cost
  final double costPerUnit;
  final double areaOnlyCost; // pure area x price per m2 (waste excluded)
  const PieceCostRow({
    required this.piece,
    required this.areaEachM2,
    required this.totalAreaM2,
    required this.shareOfMarker,
    required this.shareOfPieces,
    required this.allocatedCost,
    required this.costPerUnit,
    required this.areaOnlyCost,
  });
}

class MarkerResult {
  final double widthCm;
  final double lengthCm;
  final double markerAreaM2;
  final double totalPiecesAreaM2;
  final int totalPieces;
  final double efficiencyPct;
  final double wastePct;
  final double wasteAreaM2;
  final double fabricCost;
  final double costPerM2;
  final List<PieceCostRow> rows;
  const MarkerResult({
    required this.widthCm,
    required this.lengthCm,
    required this.markerAreaM2,
    required this.totalPiecesAreaM2,
    required this.totalPieces,
    required this.efficiencyPct,
    required this.wastePct,
    required this.wasteAreaM2,
    required this.fabricCost,
    required this.costPerM2,
    required this.rows,
  });
}

class MarkerCalc {
  static double markerAreaM2(double widthCm, double lengthCm) =>
      widthCm * lengthCm / 10000.0;

  /// Per meter: length(m) x price.  Per m2: marker area x price.
  static double fabricCost(
      double widthCm, double lengthCm, double price, PriceMode mode) {
    if (mode == PriceMode.perMeter) return lengthCm / 100.0 * price;
    return markerAreaM2(widthCm, lengthCm) * price;
  }

  static double efficiencyPct(double piecesAreaM2, double markerAreaM2) =>
      markerAreaM2 <= 0 ? 0 : piecesAreaM2 / markerAreaM2 * 100.0;

  static MarkerResult compute(MarkerData m) {
    final markerArea = markerAreaM2(m.fabricWidthCm, m.markerLengthCm);
    double total = 0;
    int count = 0;
    for (final p in m.pieces) {
      total += p.areaM2 * p.quantity;
      count += p.quantity;
    }
    final eff = efficiencyPct(total, markerArea);
    final cost = fabricCost(m.fabricWidthCm, m.markerLengthCm, m.price, m.priceMode);
    final perM2 = markerArea > 0 ? cost / markerArea : 0.0;
    final rows = m.pieces.map((p) {
      final tot = p.areaM2 * p.quantity;
      final alloc = total > 0 ? cost * tot / total : 0.0;
      return PieceCostRow(
        piece: p,
        areaEachM2: p.areaM2,
        totalAreaM2: tot,
        shareOfMarker: markerArea > 0 ? tot / markerArea : 0,
        shareOfPieces: total > 0 ? tot / total : 0,
        allocatedCost: alloc,
        costPerUnit: p.quantity > 0 ? alloc / p.quantity : 0,
        areaOnlyCost: tot * perM2,
      );
    }).toList();
    return MarkerResult(
      widthCm: m.fabricWidthCm,
      lengthCm: m.markerLengthCm,
      markerAreaM2: markerArea,
      totalPiecesAreaM2: total,
      totalPieces: count,
      efficiencyPct: eff,
      wastePct: 100.0 - eff,
      wasteAreaM2: markerArea - total,
      fabricCost: cost,
      costPerM2: perM2,
      rows: rows,
    );
  }
}

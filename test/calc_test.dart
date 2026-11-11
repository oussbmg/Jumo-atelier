import 'package:flutter_test/flutter_test.dart';
import 'package:marker_creator/calculations/geometry.dart';
import 'package:marker_creator/calculations/marker_calc.dart';
import 'package:marker_creator/calculations/product_calc.dart';
import 'package:marker_creator/models/models.dart';

MarkerData example() {
  final m = MarkerData(
      name: 'Test', fabricWidthCm: 160, markerLengthCm: 500, price: 800,
      priceMode: PriceMode.perMeter);
  m.pieces.add(MarkerPiece(name: 'A', rectLength: 112, rectWidth: 52, quantity: 2));
  m.pieces.add(MarkerPiece(name: 'B', rectLength: 112, rectWidth: 80, quantity: 1));
  return m;
}

void main() {
  test('marker area and fabric cost (per meter and per m2)', () {
    expect(MarkerCalc.markerAreaM2(160, 500), closeTo(8, 1e-12));
    expect(MarkerCalc.fabricCost(160, 500, 800, PriceMode.perMeter), closeTo(4000, 1e-9));
    expect(MarkerCalc.fabricCost(160, 500, 500, PriceMode.perSquareMeter), closeTo(4000, 1e-9));
  });

  test('efficiency / waste for the 6.5 m2 example', () {
    final eff = MarkerCalc.efficiencyPct(6.5, 8);
    expect(eff, closeTo(81.25, 1e-9));
    expect(100 - eff, closeTo(18.75, 1e-9));
  });

  test('full example marker', () {
    final r = MarkerCalc.compute(example());
    // A: 0.5824 x2 = 1.1648 ; B: 0.896 ; total 2.0608
    expect(r.totalPieces, 3);
    expect(r.totalPiecesAreaM2, closeTo(2.0608, 1e-9));
    expect(r.efficiencyPct, closeTo(2.0608 / 8 * 100, 1e-9));
    expect(r.wastePct, closeTo(100 - 2.0608 / 8 * 100, 1e-9));
    expect(r.wasteAreaM2, closeTo(8 - 2.0608, 1e-9));
    expect(r.fabricCost, closeTo(4000, 1e-9));
  });

  test('piece cost allocation sums to the marker cost and is area-proportional', () {
    final r = MarkerCalc.compute(example());
    final a = r.rows[0], b = r.rows[1];
    expect(a.allocatedCost + b.allocatedCost, closeTo(4000, 1e-9));
    expect(a.allocatedCost, closeTo(4000 * 1.1648 / 2.0608, 1e-9));
    expect(a.costPerUnit, closeTo(a.allocatedCost / 2, 1e-12));
    expect(b.allocatedCost, closeTo(4000 * 0.896 / 2.0608, 1e-9));
    expect(a.areaOnlyCost, closeTo(1.1648 * 500, 1e-9)); // 4000/8 = 500 DA/m2
    expect(a.shareOfMarker, closeTo(1.1648 / 8, 1e-12));
  });

  test('quantity multiplies area', () {
    final m = MarkerData(name: 'q', fabricWidthCm: 100, markerLengthCm: 100);
    m.pieces.add(MarkerPiece(name: 'x', rectLength: 10, rectWidth: 10, quantity: 10));
    expect(MarkerCalc.compute(m).totalPiecesAreaM2, closeTo(0.1, 1e-12));
  });

  test('irregular polygon in a marker', () {
    final m = MarkerData(name: 'p', fabricWidthCm: 160, markerLengthCm: 500, price: 500,
        priceMode: PriceMode.perSquareMeter);
    m.pieces.add(MarkerPiece(
      name: 'Poly', shape: ShapeType.polygon, quantity: 2,
      polygon: [Pt(0, 0), Pt(72, 0), Pt(72, 58), Pt(40, 58), Pt(32, 40), Pt(0, 29)],
    ));
    final r = MarkerCalc.compute(m);
    expect(r.totalPiecesAreaM2, closeTo(0.6704, 1e-9));
    expect(r.rows.first.allocatedCost, closeTo(4000, 1e-9)); // only piece => whole cost
  });

  test('product cost and selling price', () {
    final p = Product(name: 'P', manualFabricCost: 450, marginPct: 30, lines: [
      CostLine(category: 'Filling', amount: 300),
      CostLine(category: 'Accessories', amount: 80),
      CostLine(category: 'Labor', amount: 200),
      CostLine(category: 'Other', amount: 50),
    ]);
    final r = ProductCalc.compute(p, null);
    expect(r.productionCost, closeTo(1080, 1e-9));
    expect(r.sellingPrice, closeTo(1404, 1e-9));
    expect(r.profit, closeTo(324, 1e-9));
  });

  test('product fabric cost from marker / units per marker', () {
    final p = Product(name: 'P', unitsPerMarker: 4);
    expect(ProductCalc.fabricCost(p, example()), closeTo(1000, 1e-9));
  });

  test('JSON round trip keeps geometry', () {
    final m = example();
    m.pieces.add(MarkerPiece(name: 'Poly', shape: ShapeType.polygon,
        polygon: [Pt(0, 0), Pt(10, 0), Pt(0, 10)]));
    final back = MarkerData.fromJson(m.toJson());
    expect(back.pieces.length, 3);
    expect(back.pieces[2].areaCm2, closeTo(50, 1e-9));
    expect(back.pieces[0].areaCm2, closeTo(5824, 1e-9));
  });
}

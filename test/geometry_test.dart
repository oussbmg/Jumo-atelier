import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:marker_creator/calculations/geometry.dart';
import 'package:marker_creator/calculations/validation.dart';
import 'package:marker_creator/models/models.dart';
import 'package:marker_creator/services/placement_service.dart';

void main() {
  test('rectangle area 112 x 52 = 5824 cm2 = 0.5824 m2', () {
    final p = MarkerPiece(name: 'A', rectLength: 112, rectWidth: 52);
    expect(p.areaCm2, closeTo(5824, 1e-9));
    expect(p.areaM2, closeTo(0.5824, 1e-12));
  });

  final poly = [Pt(0, 0), Pt(72, 0), Pt(72, 58), Pt(40, 58), Pt(32, 40), Pt(0, 29)];

  test('polygon area (shoelace) and perimeter', () {
    expect(Geo.polygonArea(poly), closeTo(3352, 1e-9));
    expect(Geo.perimeter(poly),
        closeTo(72 + 58 + 32 + math.sqrt(388) + math.sqrt(1145) + 29, 1e-9));
  });

  test('polygon area is independent of vertex order direction', () {
    expect(Geo.polygonArea(poly.reversed.toList()), closeTo(3352, 1e-9));
  });

  test('rotation keeps area and perimeter', () {
    final r = Geo.transform(poly, 100, 100, 37.5);
    expect(Geo.polygonArea(r), closeTo(3352, 1e-6));
    expect(Geo.perimeter(r), closeTo(Geo.perimeter(poly), 1e-6));
  });

  test('90 degree rotation swaps bbox width/height', () {
    final r = Geo.transform([Pt(0, 0), Pt(112, 0), Pt(112, 52), Pt(0, 52)], 0, 0, 90);
    final b = Geo.bbox(r);
    expect(b.width, closeTo(52, 1e-9));
    expect(b.height, closeTo(112, 1e-9));
  });

  test('self-intersection detection', () {
    expect(Geo.isSelfIntersecting([Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)]), isTrue);
    expect(Geo.isSelfIntersecting(poly), isFalse);
  });

  test('overlap: crossing, touching, stacked, separate', () {
    final a = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];
    expect(Geo.overlap(a, [Pt(5, 5), Pt(15, 5), Pt(15, 15), Pt(5, 15)]), isTrue);
    expect(Geo.overlap(a, [Pt(10, 0), Pt(20, 0), Pt(20, 10), Pt(10, 10)]), isFalse);
    expect(Geo.overlap(a, List<Pt>.from(a)), isTrue);
    expect(Geo.overlap(a, [Pt(20, 0), Pt(30, 0), Pt(30, 10), Pt(20, 10)]), isFalse);
    expect(Geo.overlap(a, [Pt(2, 2), Pt(4, 2), Pt(4, 4), Pt(2, 4)]), isTrue);
  });

  test('validation', () {
    expect(Validators.positive(0, 'Width'), isNotNull);
    expect(Validators.positive(-1, 'Width'), isNotNull);
    expect(Validators.positive(160, 'Width'), isNull);
    expect(Validators.quantity(0), isNotNull);
    expect(Validators.quantity(2), isNull);
    expect(Validators.polygonErrors([Pt(0, 0), Pt(1, 1)]), isNotEmpty);
    expect(Validators.polygonErrors([Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)]), isNotEmpty);
    expect(Validators.polygonErrors(poly), isEmpty);
  });

  test('placement statuses: ok / outside / overlap', () {
    final m = MarkerData(name: 'm', fabricWidthCm: 100, markerLengthCm: 200);
    final a = MarkerPiece(name: 'A', rectLength: 50, rectWidth: 50, quantity: 3);
    m.pieces.add(a);
    a.placements = [
      Placement(x: 25, y: 25),
      Placement(x: 40, y: 25), // overlaps first
      Placement(x: 195, y: 25), // outside
    ];
    final st = PlacementService.statuses(m, PlacementService.instances(m));
    expect(st['${a.id}#0'], PlaceStatus.overlap);
    expect(st['${a.id}#1'], PlaceStatus.overlap);
    expect(st['${a.id}#2'], PlaceStatus.outside);
  });

  test('autoPlace creates one valid placement per quantity', () {
    final m = MarkerData(name: 'm', fabricWidthCm: 160, markerLengthCm: 500);
    final a = MarkerPiece(name: 'A', rectLength: 112, rectWidth: 52, quantity: 2);
    final b = MarkerPiece(name: 'B', rectLength: 112, rectWidth: 80, quantity: 1);
    m.pieces.addAll([a, b]);
    PlacementService.syncPlacements(m, a);
    PlacementService.syncPlacements(m, b);
    expect(a.placements.length, 2);
    expect(b.placements.length, 1);
    final st = PlacementService.statuses(m, PlacementService.instances(m));
    expect(st.values.every((s) => s == PlaceStatus.ok), isTrue);
  });
}

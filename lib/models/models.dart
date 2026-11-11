import 'dart:math' as math;
import '../calculations/geometry.dart';

enum ShapeType { rectangle, polygon }

enum PriceMode { perMeter, perSquareMeter }

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// Position of ONE physical piece on the marker.
/// (x,y) is the centre of the piece's bounding box, in cm.
/// x runs along the marker length, y across the fabric width.
class Placement {
  double x;
  double y;
  double rotation; // degrees
  Placement({required this.x, required this.y, this.rotation = 0});
  Placement copy() => Placement(x: x, y: y, rotation: rotation);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'r': rotation};
  factory Placement.fromJson(Map<String, dynamic> j) => Placement(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        rotation: (j['r'] as num?)?.toDouble() ?? 0,
      );
}

class MarkerPiece {
  String id;
  String name;
  String code;
  ShapeType shape;
  double rectLength;
  double rectWidth;
  List<Pt> polygon;
  int quantity;
  List<Placement> placements;

  MarkerPiece({
    String? id,
    required this.name,
    this.code = '',
    this.shape = ShapeType.rectangle,
    this.rectLength = 100,
    this.rectWidth = 50,
    List<Pt>? polygon,
    this.quantity = 1,
    List<Placement>? placements,
  })  : id = id ?? newId(),
        polygon = polygon ?? [],
        placements = placements ?? [];

  List<Pt> get localPoints => shape == ShapeType.rectangle
      ? [Pt(0, 0), Pt(rectLength, 0), Pt(rectLength, rectWidth), Pt(0, rectWidth)]
      : polygon;

  double get areaCm2 => Geo.polygonArea(localPoints);
  double get areaM2 => areaCm2 / 10000.0;
  double get perimeterCm => Geo.perimeter(localPoints);
  BBox get bbox => Geo.bbox(localPoints);

  MarkerPiece copy({bool newIdentity = false}) => MarkerPiece(
        id: newIdentity ? null : id,
        name: name,
        code: code,
        shape: shape,
        rectLength: rectLength,
        rectWidth: rectWidth,
        polygon: polygon.map((p) => Pt(p.x, p.y)).toList(),
        quantity: quantity,
        placements: placements.map((p) => p.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'shape': shape.name,
        'rectLength': rectLength,
        'rectWidth': rectWidth,
        'polygon': polygon.map((p) => p.toJson()).toList(),
        'quantity': quantity,
        'placements': placements.map((p) => p.toJson()).toList(),
      };

  factory MarkerPiece.fromJson(Map<String, dynamic> j) => MarkerPiece(
        id: j['id'] as String?,
        name: j['name'] as String? ?? 'Piece',
        code: j['code'] as String? ?? '',
        shape: j['shape'] == 'polygon' ? ShapeType.polygon : ShapeType.rectangle,
        rectLength: (j['rectLength'] as num?)?.toDouble() ?? 100,
        rectWidth: (j['rectWidth'] as num?)?.toDouble() ?? 50,
        polygon: ((j['polygon'] as List?) ?? [])
            .map((e) => Pt.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        placements: ((j['placements'] as List?) ?? [])
            .map((e) => Placement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class MarkerData {
  String id;
  String name;
  String fabricName;
  double fabricWidthCm;
  double markerLengthCm;
  double price;
  PriceMode priceMode;
  String notes;
  List<MarkerPiece> pieces;

  // Imported marker image + calibration
  String? imageFile; // file name inside the app's images folder
  int? imageW;
  int? imageH;
  double? pxPerCm; // null = not calibrated (image is just fitted)
  double imgOffX; // image top-left position inside the marker (cm)
  double imgOffY;

  DateTime created;
  DateTime modified;

  MarkerData({
    String? id,
    required this.name,
    this.fabricName = '',
    required this.fabricWidthCm,
    required this.markerLengthCm,
    this.price = 0,
    this.priceMode = PriceMode.perMeter,
    this.notes = '',
    List<MarkerPiece>? pieces,
    this.imageFile,
    this.imageW,
    this.imageH,
    this.pxPerCm,
    this.imgOffX = 0,
    this.imgOffY = 0,
    DateTime? created,
    DateTime? modified,
  })  : id = id ?? newId(),
        pieces = pieces ?? [],
        created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now();

  bool get hasImage => imageFile != null && imageW != null && imageH != null;
  bool get isCalibrated => pxPerCm != null;

  /// Image pixels per real cm. Before calibration the image is simply fitted
  /// inside the marker (aspect ratio kept) and the value is only indicative.
  double get effectivePxPerCm {
    if (pxPerCm != null) return pxPerCm!;
    if (!hasImage) return 1;
    return math.min(imageW! / markerLengthCm, imageH! / fabricWidthCm);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fabricName': fabricName,
        'fabricWidthCm': fabricWidthCm,
        'markerLengthCm': markerLengthCm,
        'price': price,
        'priceMode': priceMode.name,
        'notes': notes,
        'pieces': pieces.map((p) => p.toJson()).toList(),
        'imageFile': imageFile,
        'imageW': imageW,
        'imageH': imageH,
        'pxPerCm': pxPerCm,
        'imgOffX': imgOffX,
        'imgOffY': imgOffY,
        'created': created.toIso8601String(),
        'modified': modified.toIso8601String(),
      };

  factory MarkerData.fromJson(Map<String, dynamic> j) => MarkerData(
        id: j['id'] as String?,
        name: j['name'] as String? ?? 'Marker',
        fabricName: j['fabricName'] as String? ?? '',
        fabricWidthCm: (j['fabricWidthCm'] as num).toDouble(),
        markerLengthCm: (j['markerLengthCm'] as num).toDouble(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        priceMode:
            j['priceMode'] == 'perSquareMeter' ? PriceMode.perSquareMeter : PriceMode.perMeter,
        notes: j['notes'] as String? ?? '',
        pieces: ((j['pieces'] as List?) ?? [])
            .map((e) => MarkerPiece.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        imageFile: j['imageFile'] as String?,
        imageW: (j['imageW'] as num?)?.toInt(),
        imageH: (j['imageH'] as num?)?.toInt(),
        pxPerCm: (j['pxPerCm'] as num?)?.toDouble(),
        imgOffX: (j['imgOffX'] as num?)?.toDouble() ?? 0,
        imgOffY: (j['imgOffY'] as num?)?.toDouble() ?? 0,
        created: DateTime.tryParse(j['created'] as String? ?? ''),
        modified: DateTime.tryParse(j['modified'] as String? ?? ''),
      );
}

class CostLine {
  String category;
  String name;
  double amount;
  CostLine({required this.category, this.name = '', required this.amount});
  CostLine copy() => CostLine(category: category, name: name, amount: amount);
  Map<String, dynamic> toJson() => {'category': category, 'name': name, 'amount': amount};
  factory CostLine.fromJson(Map<String, dynamic> j) => CostLine(
        category: j['category'] as String? ?? 'Other',
        name: j['name'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

const costCategories = [
  'Filling',
  'Accessories',
  'Zippers',
  'Buttons',
  'Labels',
  'Thread',
  'Packaging',
  'Labor',
  'Electricity',
  'Other',
];

class Product {
  String id;
  String name;
  String code;
  String? markerId;
  double unitsPerMarker; // finished products obtained from one marker
  double manualFabricCost; // used when no marker is linked
  List<CostLine> lines;
  double marginPct; // profit margin on cost
  String notes;
  DateTime created;
  DateTime modified;

  Product({
    String? id,
    required this.name,
    this.code = '',
    this.markerId,
    this.unitsPerMarker = 1,
    this.manualFabricCost = 0,
    List<CostLine>? lines,
    this.marginPct = 30,
    this.notes = '',
    DateTime? created,
    DateTime? modified,
  })  : id = id ?? newId(),
        lines = lines ?? [],
        created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now();

  Product copy({bool newIdentity = false}) => Product(
        id: newIdentity ? null : id,
        name: name,
        code: code,
        markerId: markerId,
        unitsPerMarker: unitsPerMarker,
        manualFabricCost: manualFabricCost,
        lines: lines.map((l) => l.copy()).toList(),
        marginPct: marginPct,
        notes: notes,
        created: created,
        modified: modified,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'markerId': markerId,
        'unitsPerMarker': unitsPerMarker,
        'manualFabricCost': manualFabricCost,
        'lines': lines.map((l) => l.toJson()).toList(),
        'marginPct': marginPct,
        'notes': notes,
        'created': created.toIso8601String(),
        'modified': modified.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String?,
        name: j['name'] as String? ?? 'Product',
        code: j['code'] as String? ?? '',
        markerId: j['markerId'] as String?,
        unitsPerMarker: (j['unitsPerMarker'] as num?)?.toDouble() ?? 1,
        manualFabricCost: (j['manualFabricCost'] as num?)?.toDouble() ?? 0,
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => CostLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        marginPct: (j['marginPct'] as num?)?.toDouble() ?? 30,
        notes: j['notes'] as String? ?? '',
        created: DateTime.tryParse(j['created'] as String? ?? ''),
        modified: DateTime.tryParse(j['modified'] as String? ?? ''),
      );
}

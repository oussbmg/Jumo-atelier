import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/store.dart';
import '../models/models.dart';
import 'image_service.dart';
import 'placement_service.dart';

/// Single app-wide state holder. Every mutation persists to local storage.
class AppState extends ChangeNotifier {
  static final AppState instance = AppState();

  final Store store = Store();
  List<MarkerData> markers = [];
  List<Product> products = [];
  String currency = 'DA';
  double gridCm = 5;
  Future<void> _chain = Future.value();

  Future<void> load() async {
    await store.init();
    final data = await store.read();
    if (data != null) {
      try {
        markers = ((data['markers'] as List?) ?? [])
            .map((e) => MarkerData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        products = ((data['products'] as List?) ?? [])
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        currency = data['currency'] as String? ?? 'DA';
        gridCm = (data['gridCm'] as num?)?.toDouble() ?? 5;
      } catch (_) {}
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'currency': currency,
        'gridCm': gridCm,
        'markers': markers.map((m) => m.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
      };

  void save() {
    _chain = _chain.then((_) => store.write(toJson())).catchError((_) {});
  }

  void changed() {
    notifyListeners();
    save();
  }

  /// Repaint listeners without writing to disk (used while dragging).
  void refresh() => notifyListeners();

  MarkerData? marker(String? id) {
    if (id == null) return null;
    for (final m in markers) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? imagePathOf(MarkerData m) =>
      m.imageFile == null ? null : store.imagePath(m.imageFile!);

  // ---- markers ----
  void touch(MarkerData m) {
    m.modified = DateTime.now();
    changed();
  }

  void addMarker(MarkerData m) {
    markers.insert(0, m);
    changed();
  }

  MarkerData duplicateMarker(MarkerData m) {
    final j = Map<String, dynamic>.from(m.toJson());
    j['id'] = newId();
    j['name'] = '${m.name} (copy)';
    final c = MarkerData.fromJson(j);
    for (final p in c.pieces) {
      p.id = newId();
    }
    c.created = DateTime.now();
    c.modified = DateTime.now();
    markers.insert(0, c);
    changed();
    return c;
  }

  Future<void> deleteMarker(MarkerData m) async {
    markers.remove(m);
    for (final p in products) {
      if (p.markerId == m.id) p.markerId = null;
    }
    await _cleanImage(m.imageFile);
    changed();
  }

  Future<void> _cleanImage(String? name) async {
    if (name == null) return;
    if (markers.any((x) => x.imageFile == name)) return;
    try {
      final f = File(store.imagePath(name));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Returns an error message, or null on success.
  Future<String?> importImage(MarkerData m, String srcPath) async {
    final info = await ImageService.inspect(srcPath);
    if (info.error != null) return info.error;
    final name = '${m.id}_${DateTime.now().millisecondsSinceEpoch}.${info.ext}';
    await File(store.imagePath(name)).writeAsBytes(info.bytes, flush: true);
    final old = m.imageFile;
    m.imageFile = name;
    m.imageW = info.w;
    m.imageH = info.h;
    m.pxPerCm = null;
    m.imgOffX = 0;
    m.imgOffY = 0;
    await _cleanImage(old);
    touch(m);
    return null;
  }

  Future<void> removeImage(MarkerData m) async {
    final old = m.imageFile;
    m.imageFile = null;
    m.imageW = null;
    m.imageH = null;
    m.pxPerCm = null;
    m.imgOffX = 0;
    m.imgOffY = 0;
    await _cleanImage(old);
    touch(m);
  }

  // ---- pieces ----
  void addPiece(MarkerData m, MarkerPiece p) {
    m.pieces.add(p);
    PlacementService.syncPlacements(m, p);
    touch(m);
  }

  void updatePiece(MarkerData m, MarkerPiece edited) {
    final i = m.pieces.indexWhere((x) => x.id == edited.id);
    if (i < 0) return;
    edited.placements = m.pieces[i].placements;
    m.pieces[i] = edited;
    PlacementService.syncPlacements(m, edited);
    touch(m);
  }

  void deletePiece(MarkerData m, MarkerPiece p) {
    m.pieces.removeWhere((x) => x.id == p.id);
    touch(m);
  }

  // ---- products ----
  void saveProduct(Product p) {
    p.modified = DateTime.now();
    final i = products.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      products[i] = p;
    } else {
      products.insert(0, p);
    }
    changed();
  }

  void duplicateProduct(Product p) {
    final c = p.copy(newIdentity: true);
    c.name = '${p.name} (copy)';
    c.created = DateTime.now();
    c.modified = DateTime.now();
    products.insert(0, c);
    changed();
  }

  void deleteProduct(Product p) {
    products.removeWhere((x) => x.id == p.id);
    changed();
  }

  void setSettings({String? cur, double? grid}) {
    if (cur != null) currency = cur;
    if (grid != null) gridCm = grid;
    changed();
  }

  Future<void> wipeAll() async {
    for (final m in List<MarkerData>.from(markers)) {
      await _cleanImage(m.imageFile);
    }
    markers = [];
    products = [];
    changed();
  }
}

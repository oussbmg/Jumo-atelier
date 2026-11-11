import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../calculations/geometry.dart';
import '../calculations/marker_calc.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/image_service.dart';
import '../services/placement_service.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/marker_canvas.dart';
import '../widgets/stats_card.dart';
import 'marker_form_screen.dart';
import 'piece_editor_screen.dart';

class MarkerScreen extends StatefulWidget {
  final String markerId;
  const MarkerScreen({super.key, required this.markerId});
  @override
  State<MarkerScreen> createState() => _MarkerScreenState();
}

class _MarkerScreenState extends State<MarkerScreen> with SingleTickerProviderStateMixin {
  final app = AppState.instance;
  late final TabController _tab = TabController(length: 2, vsync: this);

  String? _sel;
  bool _grid = true, _snap = true, _dims = true, _calib = false, _moveImg = false;
  final List<Pt> _calibPts = [];
  int _fitTick = 0;
  ui.Image? _img;
  String? _imgFile;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _snackMsg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _ensureImage(MarkerData m) {
    if (m.imageFile == _imgFile) return;
    _imgFile = m.imageFile;
    _img = null;
    final f = m.imageFile;
    if (f == null) return;
    ImageService.load(app.store.imagePath(f), m.imageW!, m.imageH!).then((im) {
      if (mounted && _imgFile == f) setState(() => _img = im);
    }).catchError((_) {
      if (mounted) _snackMsg('The marker image could not be displayed');
    });
  }

  // ---------- piece actions ----------
  Future<void> _addPiece(MarkerData m) async {
    final p = await Navigator.push<MarkerPiece>(
      context,
      MaterialPageRoute(builder: (_) => PieceEditorScreen(index: m.pieces.length)),
    );
    if (p != null) app.addPiece(m, p);
  }

  Future<void> _editPiece(MarkerData m, MarkerPiece p) async {
    final r = await Navigator.push<MarkerPiece>(
      context,
      MaterialPageRoute(builder: (_) => PieceEditorScreen(piece: p.copy(), index: m.pieces.indexOf(p))),
    );
    if (r != null) app.updatePiece(m, r);
  }

  PlacedInstance? _selected(List<PlacedInstance> inst) {
    for (final i in inst) {
      if (i.key == _sel) return i;
    }
    return null;
  }

  void _rotate90(MarkerData m, PlacedInstance s) {
    final pl = s.piece.placements[s.index];
    pl.rotation = (pl.rotation + 90) % 360;
    app.touch(m);
  }

  Future<void> _rotateFree(MarkerData m, PlacedInstance s) async {
    final pl = s.piece.placements[s.index];
    final c = TextEditingController(text: Fmt.n(pl.rotation, 2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rotation angle'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Degrees (0, 90, 180, 270 or any value)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
        ],
      ),
    );
    final v = Fmt.parse(c.text);
    c.dispose();
    if (ok == true && v != null) {
      pl.rotation = ((v % 360) + 360) % 360;
      app.touch(m);
    }
  }

  void _duplicate(MarkerData m, PlacedInstance s) {
    final p = s.piece;
    final rot = p.placements[s.index].rotation;
    p.quantity++;
    p.placements.add(PlacementService.autoPlace(m, p, rotation: rot));
    setState(() => _sel = PlacementService.keyOf(p, p.placements.length - 1));
    app.touch(m);
  }

  Future<void> _deleteInstance(MarkerData m, PlacedInstance s) async {
    final ok = await _confirm('Delete this piece?', '"${s.piece.name}" copy ${s.index + 1} will be removed from the marker.');
    if (ok != true) return;
    final p = s.piece;
    p.placements.removeAt(s.index);
    p.quantity--;
    if (p.quantity <= 0) m.pieces.removeWhere((x) => x.id == p.id);
    setState(() => _sel = null);
    app.touch(m);
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.bad))),
          ],
        ),
      );

  // ---------- image ----------
  Future<void> _pickImage(MarkerData m) async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      final err = await app.importImage(m, f.path);
      if (err != null) {
        _snackMsg(err);
      } else {
        setState(() => _fitTick++);
        _snackMsg('Image imported. Use "Calibrate" to set its real scale.');
      }
    } catch (e) {
      _snackMsg('Could not import the image: $e');
    }
  }

  void _startCalib(MarkerData m) {
    if (!m.hasImage) {
      _snackMsg('Import a marker image first');
      return;
    }
    setState(() {
      _calib = true;
      _moveImg = false;
      _calibPts.clear();
      _sel = null;
    });
    _tab.animateTo(0);
  }

  void _onCalibTap(MarkerData m, Pt w) {
    setState(() => _calibPts.add(w));
    if (_calibPts.length == 2) _finishCalib(m);
  }

  Future<void> _finishCalib(MarkerData m) async {
    final measured = Geo.dist(_calibPts[0], _calibPts[1]);
    if (measured < 1e-6) {
      setState(() {
        _calibPts.clear();
      });
      _snackMsg('The two points are identical, pick two different points');
      return;
    }
    final c = TextEditingController(text: Fmt.n(m.fabricWidthCm, 4));
    String preset = 'width';
    final real = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('Calibrate image'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('The distance between the two points you tapped is:')),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              ChoiceChip(
                label: const Text('Fabric width'),
                selected: preset == 'width',
                onSelected: (_) => setD(() {
                  preset = 'width';
                  c.text = Fmt.n(m.fabricWidthCm, 4);
                }),
              ),
              ChoiceChip(
                label: const Text('Marker length'),
                selected: preset == 'length',
                onSelected: (_) => setD(() {
                  preset = 'length';
                  c.text = Fmt.n(m.markerLengthCm, 4);
                }),
              ),
              ChoiceChip(
                label: const Text('Piece dimension'),
                selected: preset == 'piece',
                onSelected: (_) => setD(() {
                  preset = 'piece';
                  c.text = '';
                }),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Real distance (cm)'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final v = Fmt.parse(c.text);
                if (v != null && v > 0) Navigator.pop(ctx, v);
              },
              child: const Text('Calibrate'),
            ),
          ],
        );
      }),
    );
    c.dispose();
    if (real != null) {
      // measured is the distance in cm at the CURRENT scale; the same image
      // pixels must correspond to `real` cm.
      m.pxPerCm = m.effectivePxPerCm * measured / real;
      app.touch(m);
      _snackMsg('Calibrated: ${Fmt.n(m.pxPerCm!, 4)} px per cm');
    }
    setState(() {
      _calib = false;
      _calibPts.clear();
    });
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final m = app.marker(widget.markerId);
        if (m == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('This marker no longer exists')));
        }
        _ensureImage(m);
        final res = MarkerCalc.compute(m);
        final inst = PlacementService.instances(m);
        final st = PlacementService.statuses(m, inst);
        final bad = st.values.where((s) => s != PlaceStatus.ok).length;
        final sel = _selected(inst);
        return Scaffold(
          appBar: AppBar(
            title: Text(m.name),
            actions: [
              IconButton(
                tooltip: 'Marker settings',
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => MarkerFormScreen(markerId: m.id))),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [Tab(text: 'Marker'), Tab(text: 'Pieces & cost')],
            ),
          ),
          body: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _canvasTab(m, res, inst, st, bad, sel),
              _detailsTab(m, res, st, bad),
            ],
          ),
        );
      },
    );
  }

  Widget _tbBtn(IconData icon, String tip, VoidCallback? onTap, {bool active = false}) {
    return IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: onTap,
      style: active ? IconButton.styleFrom(backgroundColor: AppColors.light, foregroundColor: AppColors.dark) : null,
    );
  }

  Widget _canvasTab(MarkerData m, MarkerResult res, List<PlacedInstance> inst,
      Map<String, PlaceStatus> st, int bad, PlacedInstance? sel) {
    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '${Fmt.n(m.fabricWidthCm)} × ${Fmt.n(m.markerLengthCm)} cm · ${Fmt.m2(res.markerAreaM2)} · '
          '${m.fabricName.isEmpty ? 'fabric' : m.fabricName} · ${Fmt.money(m.price, app.currency)}'
          '${m.priceMode == PriceMode.perMeter ? '/m' : '/m²'}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      if (_calib)
        Container(
          width: double.infinity,
          color: const Color(0xFFFFF3E0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Text(
                _calibPts.isEmpty
                    ? 'Calibration: tap point 1 on the image'
                    : 'Calibration: tap point 2 on the image',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
                onPressed: () => setState(() {
                      _calib = false;
                      _calibPts.clear();
                    }),
                child: const Text('Cancel')),
          ]),
        ),
      if (_moveImg)
        Container(
          width: double.infinity,
          color: const Color(0xFFFFF3E0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            const Expanded(child: Text('Drag to move the image under the pieces', style: TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => setState(() => _moveImg = false), child: const Text('Done')),
          ]),
        ),
      Expanded(
        child: Container(
          color: const Color(0xFFECEFEC),
          child: MarkerCanvas(
            marker: m,
            image: _img,
            instances: inst,
            statuses: st,
            selectedKey: sel?.key,
            showGrid: _grid,
            showDims: _dims,
            snap: _snap,
            gridCm: app.gridCm,
            calibMode: _calib,
            moveImageMode: _moveImg,
            calibPoints: _calibPts,
            fitTick: _fitTick,
            onSelect: (k) => setState(() => _sel = k),
            onMove: (p, i, x, y) {
              p.placements[i].x = x;
              p.placements[i].y = y;
              app.refresh();
            },
            onMoveEnd: () => app.touch(m),
            onCalibTap: (w) => _onCalibTap(m, w),
            onImageMove: (dx, dy) {
              m.imgOffX += dx;
              m.imgOffY += dy;
              app.refresh();
            },
          ),
        ),
      ),
      if (bad > 0)
        Container(
          width: double.infinity,
          color: const Color(0xFFFFEBEE),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '$bad piece(s) outside the marker or overlapping (shown in red)',
            style: const TextStyle(color: AppColors.bad, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      Container(
        color: Colors.white,
        height: 50,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _tbBtn(Icons.rotate_90_degrees_cw, 'Rotate 90°', sel == null ? null : () => _rotate90(m, sel)),
          _tbBtn(Icons.rotate_right, 'Free rotation', sel == null ? null : () => _rotateFree(m, sel)),
          _tbBtn(Icons.copy, 'Duplicate', sel == null ? null : () => _duplicate(m, sel)),
          _tbBtn(Icons.edit, 'Edit piece', sel == null ? null : () => _editPiece(m, sel.piece)),
          _tbBtn(Icons.delete_outline, 'Delete', sel == null ? null : () => _deleteInstance(m, sel)),
          const VerticalDivider(width: 12),
          _tbBtn(Icons.grid_4x4, 'Grid', () => setState(() => _grid = !_grid), active: _grid),
          _tbBtn(Icons.border_all, 'Snap to grid', () => setState(() => _snap = !_snap), active: _snap),
          _tbBtn(Icons.straighten, 'Dimensions', () => setState(() => _dims = !_dims), active: _dims),
          _tbBtn(Icons.fit_screen, 'Fit view', () => setState(() => _fitTick++)),
          PopupMenuButton<String>(
            tooltip: 'Marker image',
            icon: const Icon(Icons.image_outlined),
            onSelected: (v) {
              if (v == 'import') _pickImage(m);
              if (v == 'calib') _startCalib(m);
              if (v == 'move') setState(() {
                    _moveImg = m.hasImage;
                    _calib = false;
                  });
              if (v == 'remove') {
                app.removeImage(m);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'import', child: Text('Import marker image (JPG/PNG)')),
              PopupMenuItem(value: 'calib', enabled: m.hasImage, child: const Text('Calibrate image')),
              PopupMenuItem(value: 'move', enabled: m.hasImage, child: const Text('Move image')),
              PopupMenuItem(value: 'remove', enabled: m.hasImage, child: const Text('Remove image')),
            ],
          ),
        ]),
      ),
      if (m.hasImage)
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.only(left: 12, bottom: 2),
          child: Text(
            m.isCalibrated
                ? 'Image scale: ${Fmt.n(m.pxPerCm!, 4)} px/cm (1 px = ${Fmt.n(1 / m.pxPerCm!, 4)} cm) · calibrated'
                : 'Image NOT calibrated (only fitted, ${Fmt.n(m.effectivePxPerCm, 3)} px/cm) – use Calibrate',
            style: TextStyle(fontSize: 11, color: m.isCalibrated ? AppColors.dark : Colors.deepOrange),
          ),
        ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            StatTile('Efficiency', Fmt.pct(res.efficiencyPct), color: res.efficiencyPct > 100 ? AppColors.bad : null),
            const SizedBox(width: 6),
            StatTile('Waste', '${Fmt.pct(res.wastePct)} · ${Fmt.m2(res.wasteAreaM2)}'),
            const SizedBox(width: 6),
            StatTile('Pieces area', Fmt.m2(res.totalPiecesAreaM2)),
            const SizedBox(width: 6),
            StatTile('Fabric cost', Fmt.money(res.fabricCost, app.currency)),
          ]),
        ),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () => _addPiece(m),
            icon: const Icon(Icons.add, size: 26),
            label: const Text('Add Piece', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    ]);
  }

  Widget _detailsTab(MarkerData m, MarkerResult res, Map<String, PlaceStatus> st, int bad) {
    final cur = app.currency;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        StatsCard(marker: m, r: res, currency: cur),
        if (bad > 0)
          Card(
            color: const Color(0xFFFFEBEE),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('$bad piece(s) are outside the marker or overlap another piece.',
                  style: const TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
            ),
          ),
        if (res.efficiencyPct > 100)
          const Card(
            color: Color(0xFFFFEBEE),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Pieces area is larger than the marker area: the layout cannot be valid.',
                  style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Pieces', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.dark)),
        if (res.rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No pieces yet. Use "Add Piece" on the Marker tab.')),
        for (final r in res.rows)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text('${r.piece.name}${r.piece.code.isEmpty ? '' : '  (${r.piece.code})'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${Fmt.shapeName(r.piece)} · ${Fmt.dims(r.piece)} cm · Qty ${r.piece.quantity}\n'
                'Area each ${Fmt.m2(r.areaEachM2)} · total ${Fmt.m2(r.totalAreaM2)}\n'
                '${Fmt.pct(r.shareOfMarker * 100)} of marker\n'
                'Allocated cost ${Fmt.money(r.allocatedCost, cur)} · per unit ${Fmt.money(r.costPerUnit, cur)}',
                style: const TextStyle(height: 1.4),
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') _editPiece(m, r.piece);
                  if (v == 'del') {
                    final ok = await _confirm('Delete piece?', '"${r.piece.name}" and all ${r.piece.quantity} copies will be removed.');
                    if (ok == true) {
                      setState(() => _sel = null);
                      app.deletePiece(m, r.piece);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'del', child: Text('Delete')),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ExpansionTile(
            title: const Text('Calculation details', style: TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(_formulas(m, res, cur), style: const TextStyle(fontSize: 12.5, height: 1.5))],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  String _formulas(MarkerData m, MarkerResult r, String cur) {
    final b = StringBuffer();
    final a = m.fabricWidthCm * m.markerLengthCm;
    b.writeln('Marker area = width × length = ${Fmt.n(m.fabricWidthCm, 4)} × ${Fmt.n(m.markerLengthCm, 4)} = ${Fmt.n(a, 4)} cm² = ${Fmt.n(r.markerAreaM2, 6)} m²');
    if (m.priceMode == PriceMode.perMeter) {
      b.writeln('Fabric cost = length (m) × price = ${Fmt.n(m.markerLengthCm / 100, 4)} × ${Fmt.n(m.price, 4)} = ${Fmt.n(r.fabricCost, 4)} $cur');
    } else {
      b.writeln('Fabric cost = area (m²) × price = ${Fmt.n(r.markerAreaM2, 6)} × ${Fmt.n(m.price, 4)} = ${Fmt.n(r.fabricCost, 4)} $cur');
    }
    b.writeln('Price per m² of marker = ${Fmt.n(r.fabricCost, 4)} / ${Fmt.n(r.markerAreaM2, 6)} = ${Fmt.n(r.costPerM2, 4)} $cur/m²');
    b.writeln('Pieces area = Σ (area × quantity) = ${Fmt.n(r.totalPiecesAreaM2, 6)} m²');
    b.writeln('Efficiency = pieces area / marker area × 100 = ${Fmt.n(r.totalPiecesAreaM2, 6)} / ${Fmt.n(r.markerAreaM2, 6)} × 100 = ${Fmt.n(r.efficiencyPct, 4)} %');
    b.writeln('Waste % = 100 − efficiency = ${Fmt.n(r.wastePct, 4)} %   (waste area = ${Fmt.n(r.wasteAreaM2, 6)} m²)');
    b.writeln('');
    b.writeln('Cost allocation: a piece gets  marker cost × (its total area / total pieces area).');
    b.writeln('The cost of the waste is therefore shared by all pieces in proportion to their area, and the allocated costs add up to the full marker cost.');
    for (final row in r.rows) {
      final p = row.piece;
      b.writeln('');
      b.writeln('• ${p.name}');
      if (p.shape == ShapeType.rectangle) {
        b.writeln('  Area = ${Fmt.n(p.rectLength, 4)} × ${Fmt.n(p.rectWidth, 4)} = ${Fmt.n(p.areaCm2, 4)} cm² = ${Fmt.n(row.areaEachM2, 6)} m²');
      } else {
        b.writeln('  Area (shoelace formula, ${p.polygon.length} points) = ${Fmt.n(p.areaCm2, 4)} cm² = ${Fmt.n(row.areaEachM2, 6)} m²');
      }
      b.writeln('  Total = ${Fmt.n(row.areaEachM2, 6)} × ${p.quantity} = ${Fmt.n(row.totalAreaM2, 6)} m²   (${Fmt.n(row.shareOfMarker * 100, 4)} % of marker)');
      b.writeln('  Allocated = ${Fmt.n(r.fabricCost, 4)} × ${Fmt.n(row.totalAreaM2, 6)} / ${Fmt.n(r.totalPiecesAreaM2, 6)} = ${Fmt.n(row.allocatedCost, 4)} $cur');
      b.writeln('  Per unit = ${Fmt.n(row.allocatedCost, 4)} / ${p.quantity} = ${Fmt.n(row.costPerUnit, 4)} $cur');
      b.writeln('  (area only, without waste share: ${Fmt.n(row.areaOnlyCost, 4)} $cur)');
    }
    return b.toString();
  }
}

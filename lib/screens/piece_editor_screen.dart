import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../calculations/geometry.dart';
import '../calculations/validation.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

/// Create / edit a piece: rectangle (length x width) or polygon (X/Y points in cm).
class PieceEditorScreen extends StatefulWidget {
  final MarkerPiece? piece;
  final int index;
  const PieceEditorScreen({super.key, this.piece, this.index = 0});
  @override
  State<PieceEditorScreen> createState() => _PieceEditorScreenState();
}

class _PieceEditorScreenState extends State<PieceEditorScreen> {
  late final TextEditingController _name, _code, _qty, _len, _wid;
  final List<TextEditingController> _xs = [], _ys = [];
  ShapeType _shape = ShapeType.rectangle;

  @override
  void initState() {
    super.initState();
    final p = widget.piece;
    _name = TextEditingController(text: p?.name ?? '');
    _code = TextEditingController(text: p?.code ?? 'P${widget.index + 1}');
    _qty = TextEditingController(text: '${p?.quantity ?? 1}');
    _len = TextEditingController(text: Fmt.n(p?.rectLength ?? 100, 4));
    _wid = TextEditingController(text: Fmt.n(p?.rectWidth ?? 50, 4));
    _shape = p?.shape ?? ShapeType.rectangle;
    List<Pt> pts = (p != null && p.polygon.isNotEmpty)
        ? p.polygon
        : [Pt(0, 0), Pt(p?.rectLength ?? 100, 0), Pt(p?.rectLength ?? 100, p?.rectWidth ?? 50), Pt(0, p?.rectWidth ?? 50)];
    for (final q in pts) {
      _xs.add(TextEditingController(text: Fmt.n(q.x, 4)));
      _ys.add(TextEditingController(text: Fmt.n(q.y, 4)));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _qty, _len, _wid, ..._xs, ..._ys]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Pt>? _points() {
    final out = <Pt>[];
    for (int i = 0; i < _xs.length; i++) {
      final x = Fmt.parse(_xs[i].text), y = Fmt.parse(_ys[i].text);
      if (x == null || y == null) return null;
      out.add(Pt(x, y));
    }
    return out;
  }

  List<Pt>? _currentShape() {
    if (_shape == ShapeType.rectangle) {
      final l = Fmt.parse(_len.text), w = Fmt.parse(_wid.text);
      if (l == null || w == null || l <= 0 || w <= 0) return null;
      return [Pt(0, 0), Pt(l, 0), Pt(l, w), Pt(0, w)];
    }
    final p = _points();
    if (p == null || p.length < 3) return null;
    return p;
  }

  List<String> _errors() {
    final e = <String>[];
    final q = int.tryParse(_qty.text.trim());
    final qe = Validators.quantity(q);
    if (qe != null) e.add(qe);
    if (_shape == ShapeType.rectangle) {
      final le = Validators.positive(Fmt.parse(_len.text), 'Length');
      final we = Validators.positive(Fmt.parse(_wid.text), 'Width');
      if (le != null) e.add(le);
      if (we != null) e.add(we);
    } else {
      final p = _points();
      if (p == null) {
        e.add('Every point needs numeric X and Y values');
      } else {
        e.addAll(Validators.polygonErrors(p));
      }
    }
    return e;
  }

  void _addPoint([double x = 0, double y = 0]) {
    setState(() {
      _xs.add(TextEditingController(text: Fmt.n(x, 4)));
      _ys.add(TextEditingController(text: Fmt.n(y, 4)));
    });
  }

  Future<void> _addByEdge() async {
    final lenC = TextEditingController();
    final angC = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add point by side length + angle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'The new point is placed from the last point. Angle 0° = right (+X), 90° = down (+Y), 180° = left, 270° = up.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
              controller: lenC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Side length (cm)')),
          const SizedBox(height: 10),
          TextField(
              controller: angC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Direction angle (°)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    final l = Fmt.parse(lenC.text), a = Fmt.parse(angC.text);
    lenC.dispose();
    angC.dispose();
    if (ok != true) return;
    if (l == null || l <= 0 || a == null) {
      _snack('Enter a positive length and a valid angle');
      return;
    }
    double bx = 0, by = 0;
    if (_xs.isNotEmpty) {
      bx = Fmt.parse(_xs.last.text) ?? 0;
      by = Fmt.parse(_ys.last.text) ?? 0;
    }
    final r = a * math.pi / 180.0;
    _addPoint(bx + l * math.cos(r), by + l * math.sin(r));
  }

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _save() {
    final errs = _errors();
    if (errs.isNotEmpty) {
      _snack(errs.first);
      return;
    }
    final p = widget.piece?.copy() ?? MarkerPiece(name: '');
    p.name = _name.text.trim().isEmpty ? 'Piece ${widget.index + 1}' : _name.text.trim();
    p.code = _code.text.trim();
    p.quantity = int.parse(_qty.text.trim());
    p.shape = _shape;
    p.rectLength = Fmt.parse(_len.text) ?? p.rectLength;
    p.rectWidth = Fmt.parse(_wid.text) ?? p.rectWidth;
    final pts = _points();
    if (pts != null) p.polygon = pts;
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final errs = _errors();
    final shape = _currentShape();
    final area = (shape != null && errs.isEmpty) ? Geo.polygonArea(shape) : null;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.piece == null ? 'Add piece' : 'Edit piece')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Piece name')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Piece code'))),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<ShapeType>(
            segments: const [
              ButtonSegment(value: ShapeType.rectangle, label: Text('Rectangle'), icon: Icon(Icons.crop_square)),
              ButtonSegment(value: ShapeType.polygon, label: Text('Polygon'), icon: Icon(Icons.pentagon_outlined)),
            ],
            selected: {_shape},
            onSelectionChanged: (s) => setState(() => _shape = s.first),
          ),
          const SizedBox(height: 12),
          if (_shape == ShapeType.rectangle) ...[
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _len,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Length (cm)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _wid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Width (cm)'),
                ),
              ),
            ]),
          ] else ...[
            Card(
              color: AppColors.light,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'An irregular polygon cannot be rebuilt from side lengths alone: the angles (or coordinates) are also required. '
                  'Enter the X / Y position of every corner in cm, or add corners one by one with a side length and a direction angle.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _xs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: TextField(
                      controller: _xs[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'X (cm)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ys[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Y (cm)', isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _xs.removeAt(i).dispose();
                      _ys.removeAt(i).dispose();
                    }),
                  ),
                ]),
              ),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _addPoint(), icon: const Icon(Icons.add), label: const Text('Add point')),
              OutlinedButton.icon(onPressed: _addByEdge, icon: const Icon(Icons.straighten), label: const Text('Add by length + angle')),
            ]),
          ],
          const SizedBox(height: 12),
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                size: Size.infinite,
                painter: _PreviewPainter(_shape == ShapeType.rectangle ? shape : _points(), errs.isEmpty),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (errs.isNotEmpty)
            Card(
              color: const Color(0xFFFFEBEE),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final e in errs) Text('• $e', style: const TextStyle(color: AppColors.bad))],
                ),
              ),
            ),
          if (area != null && shape != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Width: ${Fmt.cm(Geo.bbox(shape).width)}   Height: ${Fmt.cm(Geo.bbox(shape).height)}\n'
                  'Area: ${Fmt.n(area, 2)} cm²  =  ${Fmt.m2(area / 10000)}\n'
                  'Perimeter: ${Fmt.cm(Geo.perimeter(shape))}\n'
                  'Quantity: $qty  →  total ${Fmt.m2(area / 10000 * qty)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save piece')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final List<Pt>? pts;
  final bool valid;
  _PreviewPainter(this.pts, this.valid);

  @override
  void paint(Canvas canvas, Size size) {
    final p = pts;
    if (p == null || p.length < 2) return;
    final b = Geo.bbox(p);
    final w = math.max(b.width, 1e-6), h = math.max(b.height, 1e-6);
    const pad = 36.0;
    final sc = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final ox = (size.width - w * sc) / 2 - b.minX * sc;
    final oy = (size.height - h * sc) / 2 - b.minY * sc;
    Offset s(Pt q) => Offset(q.x * sc + ox, q.y * sc + oy);
    final path = Path();
    for (int i = 0; i < p.length; i++) {
      final o = s(p[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    final col = valid ? AppColors.ok : AppColors.bad;
    canvas.drawPath(path, Paint()..color = col.withAlpha(60));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = col);
    void text(String t, Offset c, {Color color = Colors.black87, double size = 10}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    for (int i = 0; i < p.length; i++) {
      final a = p[i], c = p[(i + 1) % p.length];
      final len = Geo.dist(a, c);
      text(Fmt.n(len, 1), s(Pt((a.x + c.x) / 2, (a.y + c.y) / 2)), color: AppColors.dark);
      final o = s(a);
      canvas.drawCircle(o, 3.5, Paint()..color = Colors.black87);
      text('${i + 1}', o + const Offset(-9, -10), size: 11);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

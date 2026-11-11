import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../calculations/geometry.dart';
import '../models/models.dart';
import '../services/placement_service.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

/// Interactive, to-scale marker canvas. World units are centimetres:
/// x = along marker length, y = across fabric width.
class MarkerCanvas extends StatefulWidget {
  final MarkerData marker;
  final ui.Image? image;
  final List<PlacedInstance> instances;
  final Map<String, PlaceStatus> statuses;
  final String? selectedKey;
  final bool showGrid;
  final bool showDims;
  final bool snap;
  final double gridCm;
  final bool calibMode;
  final bool moveImageMode;
  final List<Pt> calibPoints;
  final int fitTick;
  final void Function(String? key) onSelect;
  final void Function(MarkerPiece piece, int index, double x, double y) onMove;
  final VoidCallback onMoveEnd;
  final void Function(Pt world) onCalibTap;
  final void Function(double dxCm, double dyCm) onImageMove;

  const MarkerCanvas({
    super.key,
    required this.marker,
    required this.image,
    required this.instances,
    required this.statuses,
    required this.selectedKey,
    required this.showGrid,
    required this.showDims,
    required this.snap,
    required this.gridCm,
    required this.calibMode,
    required this.moveImageMode,
    required this.calibPoints,
    required this.fitTick,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onCalibTap,
    required this.onImageMove,
  });

  @override
  State<MarkerCanvas> createState() => _MarkerCanvasState();
}

class _MarkerCanvasState extends State<MarkerCanvas> {
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;
  bool _fitted = false;
  int _lastTick = 0;
  double _lastL = 0, _lastW = 0;

  // gesture state
  double _baseScale = 1;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocal = Offset.zero;
  double _baseDetailsScale = 1;
  PlacedInstance? _drag;
  double _dragStartX = 0, _dragStartY = 0;
  bool _imgDrag = false;

  void _fit(Size s) {
    final l = widget.marker.markerLengthCm, w = widget.marker.fabricWidthCm;
    const pad = 30.0;
    final sc = math.min((s.width - pad * 2) / l, (s.height - pad * 2) / w);
    _scale = sc > 0 ? sc : 1;
    _offset = Offset((s.width - l * _scale) / 2, (s.height - w * _scale) / 2);
    _fitted = true;
    _lastTick = widget.fitTick;
    _lastL = l;
    _lastW = w;
    _size = s;
  }

  Pt _toWorld(Offset o) => Pt((o.dx - _offset.dx) / _scale, (o.dy - _offset.dy) / _scale);

  PlacedInstance? _hit(Pt w) {
    PlacedInstance? found;
    for (final i in widget.instances) {
      if (Geo.insideOrOn(w, i.pts)) found = i;
    }
    return found;
  }

  void _onStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _baseFocal = d.localFocalPoint;
    _baseDetailsScale = 1;
    _drag = null;
    _imgDrag = false;
    if (d.pointerCount == 1 && !widget.calibMode) {
      if (widget.moveImageMode && widget.marker.hasImage) {
        _imgDrag = true;
      } else {
        final h = _hit(_toWorld(d.localFocalPoint));
        if (h != null) {
          _drag = h;
          final pl = h.piece.placements[h.index];
          _dragStartX = pl.x;
          _dragStartY = pl.y;
          widget.onSelect(h.key);
        }
      }
    }
  }

  void _onUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount > 1 && (_drag != null || _imgDrag)) {
      _drag = null;
      _imgDrag = false;
      _baseScale = _scale;
      _baseOffset = _offset;
      _baseFocal = d.localFocalPoint;
      _baseDetailsScale = d.scale;
    }
    if (_imgDrag) {
      final dl = d.focalPointDelta / _scale;
      widget.onImageMove(dl.dx, dl.dy);
      return;
    }
    if (_drag != null) {
      final inst = _drag!;
      final delta = (d.localFocalPoint - _baseFocal) / _scale;
      double cx = _dragStartX + delta.dx, cy = _dragStartY + delta.dy;
      if (widget.snap && widget.gridCm > 0) {
        final g = widget.gridCm;
        final bb = Geo.bbox(Geo.transform(
            inst.piece.localPoints, cx, cy, inst.piece.placements[inst.index].rotation));
        cx += (bb.minX / g).round() * g - bb.minX;
        cy += (bb.minY / g).round() * g - bb.minY;
      }
      widget.onMove(inst.piece, inst.index, cx, cy);
      return;
    }
    final rel = d.scale / (_baseDetailsScale == 0 ? 1 : _baseDetailsScale);
    final ns = (_baseScale * rel).clamp(0.05, 300.0).toDouble();
    final wf = (_baseFocal - _baseOffset) / _baseScale;
    setState(() {
      _scale = ns;
      _offset = d.localFocalPoint - wf * ns;
    });
  }

  void _onEnd(ScaleEndDetails d) {
    if (_drag != null || _imgDrag) widget.onMoveEnd();
    _drag = null;
    _imgDrag = false;
  }

  void _onTap(TapUpDetails d) {
    final w = _toWorld(d.localPosition);
    if (widget.calibMode) {
      widget.onCalibTap(w);
      return;
    }
    widget.onSelect(_hit(w)?.key);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = Size(c.maxWidth, c.maxHeight);
      if (!_fitted ||
          widget.fitTick != _lastTick ||
          widget.marker.markerLengthCm != _lastL ||
          widget.marker.fabricWidthCm != _lastW ||
          (s.width - _size.width).abs() > 80 ||
          (s.height - _size.height).abs() > 80) {
        _fit(s);
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onStart,
        onScaleUpdate: _onUpdate,
        onScaleEnd: _onEnd,
        onTapUp: _onTap,
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: _CanvasPainter(
              marker: widget.marker,
              image: widget.image,
              instances: widget.instances,
              statuses: widget.statuses,
              selectedKey: widget.selectedKey,
              showGrid: widget.showGrid,
              showDims: widget.showDims,
              gridCm: widget.gridCm,
              scale: _scale,
              offset: _offset,
              calibPoints: widget.calibPoints,
            ),
          ),
        ),
      );
    });
  }
}

class _CanvasPainter extends CustomPainter {
  final MarkerData marker;
  final ui.Image? image;
  final List<PlacedInstance> instances;
  final Map<String, PlaceStatus> statuses;
  final String? selectedKey;
  final bool showGrid;
  final bool showDims;
  final double gridCm;
  final double scale;
  final Offset offset;
  final List<Pt> calibPoints;

  _CanvasPainter({
    required this.marker,
    required this.image,
    required this.instances,
    required this.statuses,
    required this.selectedKey,
    required this.showGrid,
    required this.showDims,
    required this.gridCm,
    required this.scale,
    required this.offset,
    required this.calibPoints,
  });

  Offset _s(Pt p) => Offset(p.x * scale + offset.dx, p.y * scale + offset.dy);

  void _text(Canvas c, String t, Offset center,
      {double size = 10,
      Color color = Colors.black87,
      bool bg = false,
      FontWeight w = FontWeight.normal}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color, fontWeight: w)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final off = center - Offset(tp.width / 2, tp.height / 2);
    if (bg) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(off.dx - 2, off.dy - 1, tp.width + 4, tp.height + 2),
            const Radius.circular(3)),
        Paint()..color = const Color(0xCCFFFFFF),
      );
    }
    tp.paint(c, off);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = marker.markerLengthCm, w = marker.fabricWidthCm;
    final mr = Rect.fromLTWH(offset.dx, offset.dy, l * scale, w * scale);

    canvas.drawRect(mr, Paint()..color = Colors.white);

    // imported marker image (true aspect ratio, calibrated scale)
    if (image != null && marker.hasImage) {
      final pxcm = marker.effectivePxPerCm;
      final dst = Rect.fromLTWH(
        offset.dx + marker.imgOffX * scale,
        offset.dy + marker.imgOffY * scale,
        marker.imageW! / pxcm * scale,
        marker.imageH! / pxcm * scale,
      );
      final src = Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
      canvas.drawImageRect(
        image!,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = const ColorFilter.mode(Color(0xD9FFFFFF), BlendMode.modulate),
      );
    }

    // grid
    if (showGrid && gridCm > 0) {
      var step = gridCm;
      while (step * scale < 10) {
        step *= 2;
      }
      final gp = Paint()
        ..color = const Color(0x332E7D32)
        ..strokeWidth = 0.7;
      for (double x = 0; x <= l + 1e-9; x += step) {
        canvas.drawLine(Offset(offset.dx + x * scale, mr.top), Offset(offset.dx + x * scale, mr.bottom), gp);
      }
      for (double y = 0; y <= w + 1e-9; y += step) {
        canvas.drawLine(Offset(mr.left, offset.dy + y * scale), Offset(mr.right, offset.dy + y * scale), gp);
      }
    }

    canvas.drawRect(
        mr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.dark);

    _text(canvas, '${Fmt.n(l)} cm', Offset(mr.center.dx, mr.top - 12),
        size: 11, color: AppColors.dark, w: FontWeight.w600);
    canvas.save();
    canvas.translate(mr.left - 12, mr.center.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, '${Fmt.n(w)} cm', Offset.zero, size: 11, color: AppColors.dark, w: FontWeight.w600);
    canvas.restore();

    // pieces
    for (final inst in instances) {
      final st = statuses[inst.key] ?? PlaceStatus.ok;
      final ok = st == PlaceStatus.ok;
      final base = ok ? AppColors.ok : AppColors.bad;
      final path = Path();
      for (int i = 0; i < inst.pts.length; i++) {
        final o = _s(inst.pts[i]);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = base.withAlpha(ok ? 80 : 110));
      final sel = inst.key == selectedKey;
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sel ? 3.5 : 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = sel ? Colors.black : base);

      final bw = inst.box.width * scale;
      final cen = _s(Geo.centroid(inst.pts));
      if (bw > 38) {
        final label = inst.piece.code.isEmpty ? inst.piece.name : '${inst.piece.name}\n${inst.piece.code}';
        _text(canvas, label, cen, size: 11, w: FontWeight.w600, bg: true);
      }
      if (showDims) {
        for (int i = 0; i < inst.pts.length; i++) {
          final a = inst.pts[i], b = inst.pts[(i + 1) % inst.pts.length];
          final len = Geo.dist(a, b);
          if (len * scale > 52) {
            _text(canvas, Fmt.n(len, 1), _s(Pt((a.x + b.x) / 2, (a.y + b.y) / 2)),
                size: 9, color: AppColors.dark, bg: true);
          }
        }
      }
    }

    // calibration points
    final cp = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 2;
    for (int i = 0; i < calibPoints.length; i++) {
      final o = _s(calibPoints[i]);
      canvas.drawLine(o + const Offset(-9, 0), o + const Offset(9, 0), cp);
      canvas.drawLine(o + const Offset(0, -9), o + const Offset(0, 9), cp);
      canvas.drawCircle(o, 5, cp..style = PaintingStyle.stroke);
      _text(canvas, '${i + 1}', o + const Offset(12, -12), size: 12, color: Colors.deepOrange, w: FontWeight.bold, bg: true);
    }
    if (calibPoints.length == 2) {
      canvas.drawLine(_s(calibPoints[0]), _s(calibPoints[1]),
          Paint()..color = Colors.deepOrange..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

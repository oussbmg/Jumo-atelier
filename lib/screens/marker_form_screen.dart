import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../calculations/validation.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/format.dart';

/// Create or edit the marker settings (fabric width, length, price...).
class MarkerFormScreen extends StatefulWidget {
  final String? markerId;
  const MarkerFormScreen({super.key, this.markerId});
  @override
  State<MarkerFormScreen> createState() => _MarkerFormScreenState();
}

class _MarkerFormScreenState extends State<MarkerFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name, _fabric, _width, _length, _price, _notes;
  PriceMode _mode = PriceMode.perMeter;
  MarkerData? _existing;

  @override
  void initState() {
    super.initState();
    _existing = AppState.instance.marker(widget.markerId);
    final m = _existing;
    _name = TextEditingController(text: m?.name ?? '');
    _fabric = TextEditingController(text: m?.fabricName ?? '');
    _width = TextEditingController(text: m != null ? Fmt.n(m.fabricWidthCm, 4) : '160');
    _length = TextEditingController(text: m != null ? Fmt.n(m.markerLengthCm, 4) : '500');
    _price = TextEditingController(text: m != null ? Fmt.n(m.price, 4) : '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _mode = m?.priceMode ?? PriceMode.perMeter;
  }

  @override
  void dispose() {
    for (final c in [_name, _fabric, _width, _length, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => Fmt.parse(c.text);

  void _save() {
    if (!_key.currentState!.validate()) return;
    final app = AppState.instance;
    final w = _d(_width)!, l = _d(_length)!, price = _d(_price) ?? 0;
    if (_existing == null) {
      final m = MarkerData(
        name: _name.text.trim().isEmpty ? 'Marker ${app.markers.length + 1}' : _name.text.trim(),
        fabricName: _fabric.text.trim(),
        fabricWidthCm: w,
        markerLengthCm: l,
        price: price,
        priceMode: _mode,
        notes: _notes.text.trim(),
      );
      app.addMarker(m);
      Navigator.pop(context, m.id);
    } else {
      final m = _existing!;
      m.name = _name.text.trim().isEmpty ? m.name : _name.text.trim();
      m.fabricName = _fabric.text.trim();
      m.fabricWidthCm = w;
      m.markerLengthCm = l;
      m.price = price;
      m.priceMode = _mode;
      m.notes = _notes.text.trim();
      app.touch(m);
      Navigator.pop(context, m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _d(_width), l = _d(_length);
    final area = (w != null && l != null && w > 0 && l > 0) ? MarkerCalc.markerAreaM2(w, l) : null;
    final price = _d(_price);
    final cost = (area != null && price != null)
        ? MarkerCalc.fabricCost(w!, l!, price, _mode)
        : null;
    final cur = AppState.instance.currency;
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'New marker' : 'Marker settings')),
      body: Form(
        key: _key,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Marker name')),
            const SizedBox(height: 12),
            TextFormField(controller: _fabric, decoration: const InputDecoration(labelText: 'Fabric type / name')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _width,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fabric width (cm)'),
              validator: (v) => Validators.positive(Fmt.parse(v ?? ''), 'Fabric width'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _length,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Marker length (cm)'),
              validator: (v) => Validators.positive(Fmt.parse(v ?? ''), 'Marker length'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PriceMode>(
              segments: const [
                ButtonSegment(value: PriceMode.perMeter, label: Text('Price / meter')),
                ButtonSegment(value: PriceMode.perSquareMeter, label: Text('Price / m²')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: _mode == PriceMode.perMeter ? 'Fabric price ($cur / m)' : 'Fabric price ($cur / m²)'),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                return Validators.nonNegative(Fmt.parse(v!), 'Price');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 14),
            if (area != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Marker area: ${Fmt.m2(area)}'
                    '${cost != null ? '\nFabric cost: ${Fmt.money(cost, cur)}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save marker')),
          ],
        ),
      ),
    );
  }
}

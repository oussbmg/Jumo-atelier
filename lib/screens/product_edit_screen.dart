import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../calculations/product_calc.dart';
import '../calculations/validation.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

class ProductEditScreen extends StatefulWidget {
  final String? productId;
  const ProductEditScreen({super.key, this.productId});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final app = AppState.instance;
  late Product _p;
  late final TextEditingController _name, _code, _notes, _units, _manual, _margin, _sell;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    Product? found;
    for (final x in app.products) {
      if (x.id == widget.productId) found = x;
    }
    _isNew = found == null;
    _p = found?.copy() ?? Product(name: '');
    _name = TextEditingController(text: _p.name);
    _code = TextEditingController(text: _p.code);
    _notes = TextEditingController(text: _p.notes);
    _units = TextEditingController(text: Fmt.n(_p.unitsPerMarker, 4));
    _manual = TextEditingController(text: Fmt.n(_p.manualFabricCost, 4));
    _margin = TextEditingController(text: Fmt.n(_p.marginPct, 4));
    _sell = TextEditingController();
    _syncSell();
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _notes, _units, _manual, _margin, _sell]) {
      c.dispose();
    }
    super.dispose();
  }

  MarkerData? get _marker => app.marker(_p.markerId);

  void _readFields() {
    _p.unitsPerMarker = Fmt.parse(_units.text) ?? _p.unitsPerMarker;
    _p.manualFabricCost = Fmt.parse(_manual.text) ?? 0;
    _p.marginPct = Fmt.parse(_margin.text) ?? _p.marginPct;
  }

  void _syncSell() {
    _readFields();
    final cost = ProductCalc.compute(_p, _marker).productionCost;
    _sell.text = Fmt.n(ProductCalc.sellingPrice(cost, _p.marginPct), 2);
  }

  void _onSellChanged(String v) {
    final s = Fmt.parse(v);
    _readFields();
    final cost = ProductCalc.compute(_p, _marker).productionCost;
    if (s != null && cost > 0) {
      setState(() {
        _p.marginPct = (s / cost - 1) * 100;
        _margin.text = Fmt.n(_p.marginPct, 4);
      });
    }
  }

  Future<void> _pickMarker() async {
    final r = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Marker used by this product'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, ''), child: const Text('— none (manual fabric cost) —')),
          for (final m in app.markers)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, m.id), child: Text(m.name)),
        ],
      ),
    );
    if (r == null) return;
    setState(() {
      _p.markerId = r.isEmpty ? null : r;
      _syncSell();
    });
  }

  Future<void> _editLine([int? index]) async {
    final existing = index == null ? null : _p.lines[index];
    String cat = existing?.category ?? costCategories.first;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final amtC = TextEditingController(text: existing == null ? '' : Fmt.n(existing.amount, 4));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text(existing == null ? 'Add cost' : 'Edit cost'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              isExpanded: true,
              value: cat,
              items: [for (final c in costCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setD(() => cat = v ?? cat),
            ),
            const SizedBox(height: 8),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 8),
            TextField(
              controller: amtC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount (${app.currency})'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final a = Fmt.parse(amtC.text);
                if (a != null && a >= 0) Navigator.pop(ctx, true);
              },
              child: const Text('OK'),
            ),
          ],
        );
      }),
    );
    final amt = Fmt.parse(amtC.text);
    final nm = nameC.text.trim();
    nameC.dispose();
    amtC.dispose();
    if (ok == true && amt != null) {
      setState(() {
        final line = CostLine(category: cat, name: nm, amount: amt);
        if (index == null) {
          _p.lines.add(line);
        } else {
          _p.lines[index] = line;
        }
        _syncSell();
      });
    }
  }

  void _save() {
    _readFields();
    final errs = <String>[];
    if (_name.text.trim().isEmpty) errs.add('Product name is required');
    if (_marker != null) {
      final e = Validators.positive(Fmt.parse(_units.text), 'Units per marker');
      if (e != null) errs.add(e);
    } else {
      final e = Validators.nonNegative(Fmt.parse(_manual.text), 'Fabric cost');
      if (e != null) errs.add(e);
    }
    if (Fmt.parse(_margin.text) == null) errs.add('Profit margin must be a number');
    if (errs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errs.first)));
      return;
    }
    _p.name = _name.text.trim();
    _p.code = _code.text.trim();
    _p.notes = _notes.text.trim();
    app.saveProduct(_p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cur = app.currency;
    final marker = _marker;
    final res = ProductCalc.compute(_p, marker);
    final mres = marker == null ? null : MarkerCalc.compute(marker);
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New product' : 'Edit product')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product name')),
          const SizedBox(height: 10),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Product code')),
          const SizedBox(height: 14),
          const Text('Fabric', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: 16)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.grid_on),
              title: Text(marker == null ? 'No marker linked' : marker.name),
              subtitle: Text(marker == null
                  ? 'Tap to link a marker'
                  : 'Marker cost ${Fmt.money(mres!.fabricCost, cur)} · ${Fmt.n(marker.fabricWidthCm)} × ${Fmt.n(marker.markerLengthCm)} cm'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickMarker,
            ),
          ),
          if (marker != null)
            TextField(
              controller: _units,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(_syncSell),
              decoration: const InputDecoration(
                  labelText: 'Finished products obtained from one marker',
                  helperText: 'Fabric cost per product = marker cost / this number'),
            )
          else
            TextField(
              controller: _manual,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(_syncSell),
              decoration: InputDecoration(labelText: 'Fabric cost per product ($cur)'),
            ),
          const SizedBox(height: 6),
          Text('Fabric cost per product: ${Fmt.money(res.fabricCost, cur)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (mres != null && mres.rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Pieces of the marker', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
            for (final r in mres.rows)
              ListTile(
                dense: true,
                title: Text('${r.piece.name} × ${r.piece.quantity}'),
                subtitle: Text('${Fmt.m2(r.totalAreaM2)} · ${Fmt.shapeName(r.piece)} ${Fmt.dims(r.piece)} cm'),
                trailing: Text('${Fmt.money(r.allocatedCost, cur)}'),
              ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(
                child: Text('Other costs', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: 16))),
            TextButton.icon(onPressed: () => _editLine(), icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
          if (_p.lines.isEmpty) const Text('Filling, accessories, zippers, buttons, labels, thread, packaging, labor, electricity…'),
          for (int i = 0; i < _p.lines.length; i++)
            Card(
              child: ListTile(
                title: Text(_p.lines[i].category + (_p.lines[i].name.isEmpty ? '' : ' – ${_p.lines[i].name}')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(Fmt.money(_p.lines[i].amount, cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _p.lines.removeAt(i);
                      _syncSell();
                    }),
                  ),
                ]),
                onTap: () => _editLine(i),
              ),
            ),
          const SizedBox(height: 14),
          Card(
            color: AppColors.light,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Production cost: ${Fmt.money(res.productionCost, cur)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.dark)),
                const SizedBox(height: 4),
                Text('Profit: ${Fmt.money(res.profit, cur)}'),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _margin,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => setState(_syncSell),
                decoration: const InputDecoration(labelText: 'Profit margin (% on cost)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _sell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onSellChanged,
                decoration: InputDecoration(labelText: 'Selling price ($cur)'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save product')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

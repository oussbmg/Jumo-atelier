import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import 'marker_screen.dart';

/// Read-only overview of every piece of every marker with its area and cost.
class PiecesScreen extends StatefulWidget {
  const PiecesScreen({super.key});
  @override
  State<PiecesScreen> createState() => _PiecesScreenState();
}

class _PiecesScreenState extends State<PiecesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final rows = <MapEntry<MarkerData, PieceCostRow>>[];
        for (final m in app.markers) {
          for (final r in MarkerCalc.compute(m).rows) {
            final p = r.piece;
            if (_q.isEmpty || p.name.toLowerCase().contains(_q) || p.code.toLowerCase().contains(_q) || m.name.toLowerCase().contains(_q)) {
              rows.add(MapEntry(m, r));
            }
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Pieces')),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search pieces'),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No pieces. Add pieces inside a marker.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: rows.length,
                      itemBuilder: (c, i) {
                        final m = rows[i].key, r = rows[i].value, p = r.piece;
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            title: Text('${p.name}${p.code.isEmpty ? '' : '  (${p.code})'}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${Fmt.shapeName(p)} · ${Fmt.dims(p)} cm · Qty ${p.quantity}\n'
                              '${Fmt.m2(r.areaEachM2)} each · ${Fmt.money(r.costPerUnit, app.currency)} / unit\n'
                              'Marker: ${m.name}',
                              style: const TextStyle(height: 1.4),
                            ),
                            isThreeLine: true,
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => MarkerScreen(markerId: m.id))),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

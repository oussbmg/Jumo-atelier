import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'marker_form_screen.dart';
import 'marker_screen.dart';

class MarkersScreen extends StatefulWidget {
  const MarkersScreen({super.key});
  @override
  State<MarkersScreen> createState() => _MarkersScreenState();
}

class _MarkersScreenState extends State<MarkersScreen> {
  String _q = '';

  Future<void> _create() async {
    final id = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const MarkerFormScreen()));
    if (id != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MarkerScreen(markerId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.markers
            .where((m) =>
                _q.isEmpty ||
                m.name.toLowerCase().contains(_q) ||
                m.fabricName.toLowerCase().contains(_q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Markers')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('New marker'),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Search markers / fabric'),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No markers'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final m = list[i];
                        final r = MarkerCalc.compute(m);
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${m.fabricName.isEmpty ? 'Fabric' : m.fabricName} · ${Fmt.n(m.fabricWidthCm)} × ${Fmt.n(m.markerLengthCm)} cm\n'
                              '${r.totalPieces} pcs · eff. ${Fmt.pct(r.efficiencyPct)} · ${Fmt.money(r.fabricCost, app.currency)}',
                            ),
                            isThreeLine: true,
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => MarkerScreen(markerId: m.id))),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'dup') {
                                  app.duplicateMarker(m);
                                } else if (v == 'edit') {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => MarkerFormScreen(markerId: m.id)));
                                } else if (v == 'del') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete marker?'),
                                      content: Text('"${m.name}" and all its pieces will be deleted.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete', style: TextStyle(color: AppColors.bad))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await app.deleteMarker(m);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit settings')),
                                PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                                PopupMenuItem(value: 'del', child: Text('Delete')),
                              ],
                            ),
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

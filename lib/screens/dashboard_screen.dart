import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/stats_card.dart';
import 'marker_form_screen.dart';
import 'marker_screen.dart';
import 'product_edit_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int) onGo;
  const DashboardScreen({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        double effSum = 0;
        int effN = 0;
        double pieces = 0;
        for (final m in app.markers) {
          final r = MarkerCalc.compute(m);
          if (m.pieces.isNotEmpty) {
            effSum += r.efficiencyPct;
            effN++;
          }
          pieces += r.totalPieces;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Marker Creator')),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    StatTile('Markers', '${app.markers.length}'),
                    StatTile('Products', '${app.products.length}'),
                    StatTile('Pieces on markers', Fmt.n(pieces, 0)),
                    StatTile('Average efficiency', effN == 0 ? '—' : Fmt.pct(effSum / effN)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('New marker'),
                    onPressed: () async {
                      final id = await Navigator.push<String>(context,
                          MaterialPageRoute(builder: (_) => const MarkerFormScreen()));
                      if (id != null && context.mounted) {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => MarkerScreen(markerId: id)));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.add),
                    label: const Text('New product'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProductEditScreen())),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Recent markers',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.dark)),
              const SizedBox(height: 6),
              if (app.markers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No markers yet. Create your first marker to start.'),
                ),
              for (final m in app.markers.take(5)) _MarkerTile(markerId: m.id),
            ],
          ),
        );
      },
    );
  }
}

class _MarkerTile extends StatelessWidget {
  final String markerId;
  const _MarkerTile({required this.markerId});
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final m = app.marker(markerId)!;
    final r = MarkerCalc.compute(m);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${Fmt.n(m.fabricWidthCm)} × ${Fmt.n(m.markerLengthCm)} cm · ${r.totalPieces} pcs · eff. ${Fmt.pct(r.efficiencyPct)}'),
        trailing: Text(Fmt.money(r.fabricCost, app.currency),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => MarkerScreen(markerId: m.id))),
      ),
    );
  }
}

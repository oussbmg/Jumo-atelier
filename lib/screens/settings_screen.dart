import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final app = AppState.instance;
  late final TextEditingController _cur = TextEditingController(text: app.currency);

  @override
  void dispose() {
    _cur.dispose();
    super.dispose();
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete ALL data?'),
        content: const Text('All markers, pieces, products and imported images will be permanently deleted from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all', style: TextStyle(color: AppColors.bad))),
        ],
      ),
    );
    if (ok == true) await app.wipeAll();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            TextField(
              controller: _cur,
              decoration: const InputDecoration(labelText: 'Currency label (shown next to costs)'),
              onChanged: (v) {
                if (v.trim().isNotEmpty) app.setSettings(cur: v.trim());
              },
            ),
            const SizedBox(height: 16),
            const Text('Grid / snap size', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final g in [1.0, 2.0, 5.0, 10.0])
                ChoiceChip(
                  label: Text('${g.toStringAsFixed(0)} cm'),
                  selected: app.gridCm == g,
                  onSelected: (_) => app.setSettings(grid: g),
                ),
            ]),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Stored on this device only (offline):\n'
                    '${app.markers.length} markers · ${app.products.length} products'),
              ),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'About / limits of this version\n'
                  '• Pieces are rectangles or polygons with straight edges (no curves yet).\n'
                  '• Placement is manual; there is no automatic nesting yet.\n'
                  '• Overlap checks use exact polygon geometry (touching edges are allowed).\n'
                  '• Dimension labels show the true geometry; to change a dimension, edit the piece.\n'
                  '• Piece cost = marker cost shared by area (waste cost included).',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _wipe,
              icon: const Icon(Icons.delete_forever, color: AppColors.bad),
              label: const Text('Delete all data', style: TextStyle(color: AppColors.bad)),
            ),
          ],
        ),
      ),
    );
  }
}

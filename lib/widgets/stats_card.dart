import 'package:flutter/material.dart';
import '../calculations/marker_calc.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatTile(this.label, this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color ?? AppColors.dark)),
        ],
      ),
    );
  }
}

/// Full statistics card for a marker.
class StatsCard extends StatelessWidget {
  final MarkerData marker;
  final MarkerResult r;
  final String currency;
  const StatsCard({super.key, required this.marker, required this.r, required this.currency});

  @override
  Widget build(BuildContext context) {
    final bad = r.efficiencyPct > 100;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatTile('Marker width', Fmt.cm(r.widthCm)),
            StatTile('Marker length', Fmt.cm(r.lengthCm)),
            StatTile('Marker area', Fmt.m2(r.markerAreaM2)),
            StatTile('Total pieces', '${r.totalPieces}'),
            StatTile('Pieces area', Fmt.m2(r.totalPiecesAreaM2)),
            StatTile('Efficiency', Fmt.pct(r.efficiencyPct), color: bad ? AppColors.bad : null),
            StatTile('Waste', Fmt.pct(r.wastePct), color: bad ? AppColors.bad : null),
            StatTile('Waste area', Fmt.m2(r.wasteAreaM2)),
            StatTile('Fabric cost', Fmt.money(r.fabricCost, currency)),
            StatTile('Cost per m²', Fmt.money(r.costPerM2, currency)),
          ],
        ),
      ),
    );
  }
}

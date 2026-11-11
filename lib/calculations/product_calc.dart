import '../models/models.dart';
import 'marker_calc.dart';

class ProductResult {
  final double fabricCost;
  final double otherCost;
  final double productionCost;
  final double sellingPrice;
  final double profit;
  const ProductResult(this.fabricCost, this.otherCost, this.productionCost,
      this.sellingPrice, this.profit);
}

class ProductCalc {
  /// Fabric cost of ONE finished product: marker cost / units per marker,
  /// or the manually entered fabric cost when no marker is linked.
  static double fabricCost(Product p, MarkerData? m) {
    if (m != null) {
      final u = p.unitsPerMarker > 0 ? p.unitsPerMarker : 1;
      return MarkerCalc.compute(m).fabricCost / u;
    }
    return p.manualFabricCost;
  }

  static double sellingPrice(double cost, double marginPct) =>
      cost * (1 + marginPct / 100.0);

  static ProductResult compute(Product p, MarkerData? m) {
    final fabric = fabricCost(p, m);
    double other = 0;
    for (final l in p.lines) {
      other += l.amount;
    }
    final cost = fabric + other;
    final sell = sellingPrice(cost, p.marginPct);
    return ProductResult(fabric, other, cost, sell, sell - cost);
  }
}

import 'package:flutter/material.dart';
import '../calculations/product_calc.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'product_edit_screen.dart';

enum _Sort { name, modified, cost, price }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _q = '';
  _Sort _sort = _Sort.modified;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final items = app.products
            .where((p) => _q.isEmpty || p.name.toLowerCase().contains(_q) || p.code.toLowerCase().contains(_q))
            .map((p) => MapEntry(p, ProductCalc.compute(p, app.marker(p.markerId))))
            .toList();
        items.sort((a, b) {
          switch (_sort) {
            case _Sort.name:
              return a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
            case _Sort.modified:
              return b.key.modified.compareTo(a.key.modified);
            case _Sort.cost:
              return b.value.productionCost.compareTo(a.value.productionCost);
            case _Sort.price:
              return b.value.sellingPrice.compareTo(a.value.sellingPrice);
          }
        });
        return Scaffold(
          appBar: AppBar(
            title: const Text('Products'),
            actions: [
              PopupMenuButton<_Sort>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _Sort.name, child: Text('Name')),
                  PopupMenuItem(value: _Sort.modified, child: Text('Last modified')),
                  PopupMenuItem(value: _Sort.cost, child: Text('Production cost')),
                  PopupMenuItem(value: _Sort.price, child: Text('Selling price')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditScreen())),
            icon: const Icon(Icons.add),
            label: const Text('New product'),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No products'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: items.length,
                      itemBuilder: (c, i) {
                        final p = items[i].key, r = items[i].value;
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            title: Text('${p.name}${p.code.isEmpty ? '' : '  (${p.code})'}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                'Cost ${Fmt.money(r.productionCost, app.currency)} · margin ${Fmt.pct(p.marginPct)}\n'
                                'Selling price ${Fmt.money(r.sellingPrice, app.currency)} · ${Fmt.date(p.modified)}'),
                            isThreeLine: true,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ProductEditScreen(productId: p.id))),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'dup') app.duplicateProduct(p);
                                if (v == 'del') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete product?'),
                                      content: Text('"${p.name}" will be deleted.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete', style: TextStyle(color: AppColors.bad))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) app.deleteProduct(p);
                                }
                              },
                              itemBuilder: (_) => const [
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

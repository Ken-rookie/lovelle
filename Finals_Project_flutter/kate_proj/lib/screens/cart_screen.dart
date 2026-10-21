import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.onShop});

  final VoidCallback onShop;

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getCart();
  }

  void reloadCart() {
    setState(() {
      _future = SupabaseService.getCart();
    });
  }

  Future<void> _refresh() async {
    final future = SupabaseService.getCart();
    setState(() {
      _future = future;
    });
    await future;
  }

  double _subtotal(List<Map<String, dynamic>> rows) => rows.fold(
        0,
        (sum, row) {
          final product = Map<String, dynamic>.from(row['products'] as Map);
          final price = Product.normalizePrice(product['price']);
          return sum + price * (row['quantity'] as int);
        },
      );

  Future<void> _changeQuantity(
    String id,
    int quantity,
  ) async {
    setState(() => _updating = true);
    try {
      await SupabaseService.setCartQuantity(id, quantity);
      await _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your gift bag')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AppLoadingState(label: 'Gathering your gift bag…');
            }
            if (snapshot.hasError) {
              return LoadErrorState(
                error: snapshot.error!,
                onRetry: () {
                  setState(() {
                    _future = SupabaseService.getCart();
                  });
                },
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Your bag is waiting',
                subtitle: 'Add something thoughtful for someone special.',
                action: ElevatedButton(
                  onPressed: widget.onShop,
                  child: const Text('Explore gifts'),
                ),
              );
            }

            final hasStockIssue = rows.any((row) {
              final product = Map<String, dynamic>.from(row['products'] as Map);
              final stock =
                  int.tryParse(product['stock_quantity'].toString()) ?? 0;
              return product['is_available'] != true ||
                  (row['quantity'] as int) > stock;
            });

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final product =
                            Map<String, dynamic>.from(row['products'] as Map);
                        final quantity = row['quantity'] as int;
                        final stock = int.tryParse(
                              product['stock_quantity'].toString(),
                            ) ??
                            0;
                        final price = Product.normalizePrice(product['price']);
                        final unavailable =
                            product['is_available'] != true || stock == 0;

                        return Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: LovelleColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: SizedBox(
                                  width: 84,
                                  height: 92,
                                  child: NetworkProductImage(
                                    url: product['image_url']?.toString() ?? '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name']?.toString() ?? 'Gift',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: LovelleColors.plum,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      peso.format(price),
                                      style: const TextStyle(
                                        color: LovelleColors.roseDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      unavailable
                                          ? 'Currently unavailable'
                                          : '$stock available',
                                      style: TextStyle(
                                        color: unavailable
                                            ? LovelleColors.roseDark
                                            : LovelleColors.mauve,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Decrease quantity',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _updating
                                              ? null
                                              : () => _changeQuantity(
                                                    row['id'].toString(),
                                                    quantity - 1,
                                                  ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          child: Text(
                                            '$quantity',
                                            key: ValueKey(quantity),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Increase quantity',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _updating ||
                                                  unavailable ||
                                                  quantity >= stock
                                              ? null
                                              : () => _changeQuantity(
                                                    row['id'].toString(),
                                                    quantity + 1,
                                                  ),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove gift',
                                onPressed: _updating
                                    ? null
                                    : () => _changeQuantity(
                                          row['id'].toString(),
                                          0,
                                        ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: LovelleColors.mauve,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: LovelleColors.border),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LovelleColors.plum.withValues(alpha: .04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Items subtotal',
                            style: TextStyle(color: LovelleColors.mauve),
                          ),
                          Text(
                            peso.format(_subtotal(rows)),
                            style: const TextStyle(
                              color: LovelleColors.plum,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (hasStockIssue) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Update or remove unavailable gifts before checkout.',
                            style: TextStyle(
                              color: LovelleColors.roseDark,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: hasStockIssue || _updating
                            ? null
                            : () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(cart: rows),
                                  ),
                                );
                                if (changed == true) await _refresh();
                              },
                        child: const Text('Continue to checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.onProduct,
    this.initialSearch = '',
    this.initialCategoryId,
  });

  final ValueChanged<Product> onProduct;
  final String initialSearch;
  final String? initialCategoryId;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _search = TextEditingController();
  String? _category;
  late Future<List<Map<String, dynamic>>> _categories;
  late Future<List<Product>> _products;

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialSearch;
    _category = widget.initialCategoryId;
    _categories = SupabaseService.getCategories();
    _load();
  }

  @override
  void didUpdateWidget(covariant ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearch != widget.initialSearch ||
        oldWidget.initialCategoryId != widget.initialCategoryId) {
      _search.text = widget.initialSearch;
      _category = widget.initialCategoryId;
      _load();
    }
  }

  void _load() {
    _products = SupabaseService.getProducts(
      categoryId: _category,
      search: _search.text,
    );
  }

  void _reloadCategories() {
    setState(() => _categories = SupabaseService.getCategories());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Gift Shop'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'A little something for every special moment.',
                style: TextStyle(color: LovelleColors.mauve),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(_load),
              decoration: InputDecoration(
                hintText: 'Search gifts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(_load);
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _categories,
              builder: (context, snap) {
                if (snap.hasError) {
                  return LoadErrorState(
                    error: snap.error!,
                    onRetry: _reloadCategories,
                    compact: true,
                  );
                }
                final cats = snap.data ?? const <Map<String, dynamic>>[];
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All gifts'),
                        selected: _category == null,
                        onSelected: (_) => setState(() {
                          _category = null;
                          _load();
                        }),
                      ),
                    ),
                    ...cats.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c['name'].toString()),
                            selected: _category == c['id'].toString(),
                            onSelected: (_) => setState(() {
                              _category = c['id'].toString();
                              _load();
                            }),
                          ),
                        )),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(label: 'Finding gifts…');
                }
                if (snap.hasError) {
                  return LoadErrorState(
                    error: snap.error!,
                    onRetry: () => setState(_load),
                  );
                }
                final list = snap.data ?? const <Product>[];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No gifts found',
                    subtitle: 'Try another search or category.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .68,
                  ),
                  itemBuilder: (context, i) {
                    final product = list[i];
                    return ProductCard(
                      product: product,
                      onTap: () => widget.onProduct(product),
                      onWishlist: () =>
                          SupabaseService.toggleWishlist(product.id),
                      onAddToCart: () async {
                        try {
                          await SupabaseService.addToCart(product.id);
                          if (context.mounted) {
                            showMessage(context, 'Added to your bag');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showOperationError(context, error);
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

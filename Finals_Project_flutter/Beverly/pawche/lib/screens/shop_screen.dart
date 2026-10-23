import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../models/product_review.dart';
import '../config/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'product_details_screen.dart';

class ShopScreen extends StatefulWidget {
  final String initialCategory;

  const ShopScreen({super.key, this.initialCategory = 'All'});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _search = TextEditingController();
  String _category = 'All';
  String _query = '';
  List<Product> _catalog = [];
  Map<String, ProductRatingSummary> _ratingSummaries = {};
  Set<String> _favoriteSlugs = {};
  bool _catalogLoading = true;
  Object? _catalogLoadError;
  Object? _ratingLoadError;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogLoadError = null;
      _ratingLoadError = null;
    });
    try {
      final products = await ProductRepository.loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = products;
        _catalogLoadError = null;
        _catalogLoading = false;
        _ratingSummaries = {};
      });
    } catch (error, stackTrace) {
      debugPrint('Pawche shop catalog load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _catalog = [];
          _catalogLoadError = error;
          _catalogLoading = false;
        });
      }
      return;
    }

    await _loadRatingSummaries();
    final client = SupabaseService.initializedClient;
    if (client?.auth.currentUser != null) {
      try {
        final favorites = await ProductRepository.loadWishlist();
        if (mounted) {
          setState(() => _favoriteSlugs = {
                for (final product in favorites) product.id,
              });
        }
      } catch (error) {
        if (mounted) {
          showMessage(context, 'Could not load your wishlist: $error');
        }
      }
    }
  }

  Future<void> _toggleWishlist(Product product) async {
    try {
      final saved = await ProductRepository.toggleWishlist(product.id);
      if (!mounted) return;
      setState(() {
        if (saved) {
          _favoriteSlugs.add(product.id);
        } else {
          _favoriteSlugs.remove(product.id);
        }
      });
      showMessage(
        context,
        saved
            ? 'Product saved to your wishlist.'
            : 'Removed from your wishlist.',
      );
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    }
  }

  Future<void> _loadRatingSummaries() async {
    try {
      final summaries = await ProductRepository.loadRatingSummaries(
        _catalog.map((product) => product.id).toList(),
      );
      if (mounted) {
        setState(() {
          _ratingSummaries = summaries;
          _ratingLoadError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _ratingLoadError = error);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showFilters() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => RadioGroup<String>(
        groupValue: _category,
        onChanged: (value) {
          if (value != null) Navigator.pop(context, value);
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Filter products',
                    style: TextStyle(
                      color: PawcheColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final category in [
                  'All',
                  'Dogs',
                  'Cats',
                  'Food',
                  'Toys',
                  'Grooming',
                ])
                  RadioListTile<String>(
                    value: category,
                    title: Text(category),
                    activeColor: PawcheColors.pink,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _category = selected);
  }

  @override
  Widget build(BuildContext context) {
    final products = _catalog.where((product) {
      final matchesQuery =
          product.name.toLowerCase().contains(_query.toLowerCase());
      final name = product.name.toLowerCase();
      final matchesCategory = switch (_category) {
        'Dogs' => name.contains('dog'),
        'Cats' => name.contains('cat'),
        'Food' => product.category.toLowerCase().contains('food'),
        'Toys' => name.contains('toy'),
        'Grooming' => name.contains('groom'),
        _ => true,
      };
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const PawcheLogo(size: 25),
        actions: [
          IconButton(
            tooltip: 'Filter products',
            onPressed: _showFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PawchePageTitle(
            'Shop',
            subtitle: 'Find a little something for your furry friend.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search products...',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final category in [
                  'All',
                  'Dogs',
                  'Cats',
                  'Food',
                  'Toys',
                  'Grooming',
                ])
                  ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${products.length} ${products.length == 1 ? 'product' : 'products'} found',
                  style: const TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_ratingLoadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Customer ratings are temporarily unavailable.',
                            style: TextStyle(
                              color: PawcheColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadRatingSummaries,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _catalogLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: PawcheColors.pink,
                    ),
                  )
                : _catalogLoadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: PawcheColors.darkPink,
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Live catalog unavailable',
                                style: TextStyle(
                                  color: PawcheColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'We could not load current products and stock. No sample items are shown.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: PawcheColors.muted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                _catalogLoadError.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: PawcheColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadCatalog,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : products.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    color: PawcheColors.muted,
                                    size: 42,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _catalog.isEmpty &&
                                            _query.isEmpty &&
                                            _category == 'All'
                                        ? 'No active products are available right now.'
                                        : 'No products match your search and filters.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: PawcheColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _catalog.isEmpty &&
                                            _query.isEmpty &&
                                            _category == 'All'
                                        ? 'Please check back later for available products.'
                                        : 'Try a different search or show all products.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: PawcheColors.muted),
                                  ),
                                  if (_query.isNotEmpty ||
                                      _category != 'All') ...[
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () {
                                        _search.clear();
                                        setState(() {
                                          _query = '';
                                          _category = 'All';
                                        });
                                      },
                                      child: const Text(
                                          'Clear search and filters'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .65,
                            ),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ProductCard(
                                product: product,
                                isFavorite: _favoriteSlugs.contains(product.id),
                                ratingSummary: _ratingSummaries[product.id],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsScreen(product: product),
                                  ),
                                ),
                                onFavorite: () => _toggleWishlist(product),
                                onAdd: () {
                                  if (CartStore.instance.add(product)) {
                                    showMessage(context, 'Added to your cart.');
                                  } else {
                                    showMessage(
                                      context,
                                      'This item has reached its available stock limit.',
                                    );
                                  }
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

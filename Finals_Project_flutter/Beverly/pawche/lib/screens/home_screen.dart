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
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _featuredProducts = [];
  Map<String, ProductRatingSummary> _ratingSummaries = {};
  Set<String> _favoriteSlugs = {};
  bool _catalogLoading = true;
  Object? _catalogLoadError;
  Object? _ratingLoadError;

  @override
  void initState() {
    super.initState();
    _loadFeaturedProducts();
  }

  Future<void> _loadFeaturedProducts() async {
    setState(() {
      _catalogLoading = true;
      _catalogLoadError = null;
      _ratingLoadError = null;
    });
    try {
      final products = await ProductRepository.loadCatalog();
      if (mounted) {
        setState(() {
          _featuredProducts = products.take(4).toList();
          _catalogLoadError = null;
          _catalogLoading = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Pawche featured catalog load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _featuredProducts = [];
          _catalogLoading = false;
          _catalogLoadError = error;
        });
      }
      return;
    }

    try {
      final summaries = await ProductRepository.loadRatingSummaries(
        _featuredProducts.map((product) => product.id).toList(),
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
        saved ? 'Product saved to your wishlist.' : 'Removed from your wishlist.',
      );
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const PawcheLogo(size: 26),
          actions: [
            IconButton(
              tooltip: 'Search products',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Container(
              height: 154,
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDCE7), Color(0xFFFFF1F5)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Happy Pets,\nHappy Lives',
                          style: TextStyle(
                            color: PawcheColors.darkPink,
                            fontSize: 21,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        FilledButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShopScreen(),
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: PawcheColors.pink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(82, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Shop Now'),
                        ),
                      ],
                    ),
                  ),
                  const PetPhoto(width: 136, height: 126),
                ],
              ),
            ),
            const SectionTitle('Shop by category'),
            SizedBox(
              height: 94,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CategoryItem(
                    icon: Icons.pets_rounded,
                    label: 'Dogs',
                    category: 'Dogs',
                  ),
                  _CategoryItem(
                    icon: Icons.cruelty_free_rounded,
                    label: 'Cats',
                    category: 'Cats',
                  ),
                  _CategoryItem(
                    icon: Icons.ramen_dining_rounded,
                    label: 'Food',
                    category: 'Food',
                  ),
                  _CategoryItem(
                    icon: Icons.sports_basketball,
                    label: 'Toys',
                    category: 'Toys',
                  ),
                  _CategoryItem(
                    icon: Icons.content_cut_rounded,
                    label: 'Grooming',
                    category: 'Grooming',
                  ),
                ],
              ),
            ),
            SectionTitle(
              'Featured Products',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
                child: const Text('See all'),
              ),
            ),
            if (_ratingLoadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
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
                      onPressed: _loadFeaturedProducts,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (_catalogLoading)
              const SizedBox(
                height: 234,
                child: Center(
                  child: CircularProgressIndicator(color: PawcheColors.pink),
                ),
              )
            else if (_catalogLoadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PawcheColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Live products are temporarily unavailable. No sample products are being shown.',
                              style: TextStyle(
                                color: PawcheColors.muted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadFeaturedProducts,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _catalogLoadError.toString(),
                        style: const TextStyle(
                          color: PawcheColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_featuredProducts.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'No active products are available right now.',
                    style: TextStyle(color: PawcheColors.muted),
                  ),
                ),
              )
            else
              SizedBox(
              height: 234,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _featuredProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 166,
                  child: ProductCard(
                    product: _featuredProducts[index],
                    isFavorite:
                        _favoriteSlugs.contains(_featuredProducts[index].id),
                    ratingSummary:
                        _ratingSummaries[_featuredProducts[index].id],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(
                          product: _featuredProducts[index],
                        ),
                      ),
                    ),
                    onFavorite: () =>
                        _toggleWishlist(_featuredProducts[index]),
                    onAdd: () {
                      final product = _featuredProducts[index];
                      if (CartStore.instance.add(product)) {
                        showMessage(context, 'Added to your cart.');
                      } else {
                        showMessage(
                          context,
                          'This item has reached its available stock limit.',
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String category;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.category,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 70,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShopScreen(initialCategory: category),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: PawcheColors.blush,
                child: Icon(icon, color: PawcheColors.darkPink, size: 23),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

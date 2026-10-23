import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'product_details_screen.dart';
import 'shop_screen.dart';

typedef WishlistLoader = Future<List<Product>> Function();

class WishlistScreen extends StatefulWidget {
  final WishlistLoader? productsLoader;

  const WishlistScreen({super.key, this.productsLoader});

  @override
  WishlistScreenState createState() => WishlistScreenState();
}

class WishlistScreenState extends State<WishlistScreen> {
  List<Product> _favorites = [];
  final Set<String> _busySlugs = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final products =
          await (widget.productsLoader ?? ProductRepository.loadWishlist)();
      if (mounted) {
        setState(() {
          _favorites = products;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> refresh() => _loadFavorites();

  Future<void> _remove(Product product) async {
    if (_busySlugs.contains(product.id)) return;
    setState(() => _busySlugs.add(product.id));
    try {
      await ProductRepository.removeWishlist(product.id);
      if (mounted) {
        setState(() {
          _favorites.removeWhere((favorite) => favorite.id == product.id);
        });
        showMessage(context, 'Removed from your wishlist.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busySlugs.remove(product.id));
    }
  }

  Future<void> _openDetails(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
    if (mounted) await _loadFavorites();
  }

  void _addToCart(Product product) {
    if (!CartStore.instance.add(product)) {
      showMessage(context, 'This product is currently out of stock.');
      return;
    }
    showMessage(context, '${product.name} added to your cart.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('My Wishlist'),
          actions: [
            IconButton(
              tooltip: 'Refresh wishlist',
              onPressed: _loading ? null : _loadFavorites,
              icon: _loading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: PawcheColors.pink),
                    SizedBox(height: 12),
                    Text(
                      'Loading your saved products…',
                      style: TextStyle(color: PawcheColors.muted),
                    ),
                  ],
                ),
              )
            : _error != null
                ? _WishlistError(
                    message: _friendlyError(_error!),
                    onRetry: _loadFavorites,
                  )
                : _favorites.isEmpty
                    ? const _EmptyWishlist()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          PawchePageTitle(
                            'Saved for your pet',
                            subtitle:
                                '${_favorites.length} ${_favorites.length == 1 ? 'product' : 'products'} saved to your account.',
                          ),
                          Container(
                            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: PawcheColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cloud_done_outlined,
                                  color: PawcheColors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Saved to your account. Current prices and stock are shown.',
                                    style: TextStyle(
                                      color: PawcheColors.navy,
                                      fontSize: 11,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final product in _favorites)
                            _WishlistProductCard(
                              product: product,
                              isBusy: _busySlugs.contains(product.id),
                              onOpen: () => _openDetails(product),
                              onRemove: () => _remove(product),
                              onAddToCart: () => _addToCart(product),
                            ),
                        ],
                      ),
      );

  String _friendlyError(Object error) {
    final message =
        error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
    if (message.contains('Sign in')) return message;
    if (message.contains('product_wishlist') || message.contains('PGRST205')) {
      return 'Wishlist setup is incomplete. Apply the customer product wishlist migration in Supabase, then retry.';
    }
    if (message.contains('not configured')) {
      return 'Connect to the live Pawché catalog to load your saved products.';
    }
    return 'Your saved products could not be loaded. Check your connection and try again.';
  }
}

class _WishlistError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WishlistError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
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
              Text(
                message.startsWith('Sign in')
                    ? 'Sign in to view your wishlist'
                    : 'Wishlist unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PawcheColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                color: PawcheColors.pink,
                size: 64,
              ),
              const SizedBox(height: 12),
              const Text(
                'No saved products yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PawcheColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap the heart on a product to keep it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PawcheColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 224,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: PawcheColors.navy,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Explore live products'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _WishlistProductCard extends StatelessWidget {
  final Product product;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const _WishlistProductCard({
    required this.product,
    required this.isBusy,
    required this.onOpen,
    required this.onRemove,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.stockQuantity;
    final inStock = stock != null && stock > 0;
    final availability = stock == null
        ? 'Stock unavailable'
        : stock == 0
            ? 'Out of stock'
            : stock <= 3
                ? 'Only $stock left'
                : 'In stock · $stock';
    final statusColor = inStock ? PawcheColors.green : PawcheColors.darkPink;

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PawcheColors.pale,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ProductArtwork(
                      emoji: product.emoji,
                      imageAsset: product.imageAsset,
                      imageUrl: product.imageUrl,
                      size: 64,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.category.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PawcheColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PawcheColors.navy,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            product.price,
                            style: const TextStyle(
                              color: PawcheColors.darkPink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${product.name} from wishlist',
                    onPressed: isBusy ? null : onRemove,
                    visualDensity: VisualDensity.compact,
                    icon: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.favorite_rounded,
                            color: PawcheColors.pink,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  inStock
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    availability,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: PawcheColors.navy,
                  ),
                  child: const Text('Details'),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: inStock ? onAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: Text(inStock ? 'Add to cart' : 'Currently unavailable'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PawcheColors.darkPink,
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

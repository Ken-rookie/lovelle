import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    super.key,
    required this.onProduct,
    required this.onShop,
  });

  final ValueChanged<Product> onProduct;
  final VoidCallback onShop;

  @override
  State<WishlistScreen> createState() => WishlistScreenState();
}

class WishlistScreenState extends State<WishlistScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getWishlist();
  }

  Future<void> _refresh() async {
    final future = SupabaseService.getWishlist();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.getWishlist();
    });
  }

  void reloadWishlist() => _reload();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your wishlist'),
        actions: [
          IconButton(
            tooltip: 'Refresh wishlist',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const AppLoadingState(label: 'Gathering your saved gifts…');
          }
          if (snap.hasError) {
            return LoadErrorState(
              error: snap.error!,
              onRetry: _reload,
            );
          }

          final list = snap.data ?? const <Product>[];
          if (list.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: LovelleColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: const BoxDecoration(
                            color: LovelleColors.palePink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_border_rounded,
                            color: LovelleColors.rose,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Your saved gifts will live here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LovelleColors.plum,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the heart on anything you love, then come back whenever you’re ready to choose.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LovelleColors.mauve,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: widget.onShop,
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Find a thoughtful gift'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: _WishlistIntro(
                      count: list.length,
                      onBrowse: widget.onShop,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid.builder(
                    itemCount: list.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: .67,
                    ),
                    itemBuilder: (context, i) {
                      final product = list[i];
                      return ProductCard(
                        product: product,
                        isWishlisted: true,
                        onTap: () => widget.onProduct(product),
                        onWishlist: () async {
                          await SupabaseService.toggleWishlist(product.id);
                          await _refresh();
                        },
                        onAddToCart: () async {
                          await SupabaseService.addToCart(product.id);
                          if (context.mounted) {
                            showMessage(context, 'Added to your gift bag');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WishlistIntro extends StatelessWidget {
  const _WishlistIntro({
    required this.count,
    required this.onBrowse,
  });

  final int count;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LovelleColors.palePink, LovelleColors.cream],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: LovelleColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: LovelleColors.rose,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'gift' : 'gifts'} saved for later',
                    style: const TextStyle(
                      color: LovelleColors.plum,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Your little collection of thoughtful ideas.',
                    style: TextStyle(
                      color: LovelleColors.mauve,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Browse more gifts',
              onPressed: onBrowse,
              icon: const Icon(
                Icons.auto_awesome_outlined,
                color: LovelleColors.roseDark,
              ),
            ),
          ],
        ),
      );
}

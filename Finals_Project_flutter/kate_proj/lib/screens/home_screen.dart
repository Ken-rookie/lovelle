import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onShop,
    required this.onSearch,
    required this.onCategory,
    required this.onProduct,
    required this.onNotifications,
  });

  final VoidCallback onShop;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategory;
  final ValueChanged<Product> onProduct;
  final VoidCallback onNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  Timer? _productRefreshTimer;
  Future<List<Product>>? _products;
  Future<List<Map<String, dynamic>>>? _categories;
  Future<Map<String, dynamic>?>? _profile;

  Future<List<Product>> get _productsFuture =>
      _products ??= SupabaseService.getProducts();
  Future<List<Map<String, dynamic>>> get _categoriesFuture =>
      _categories ??= SupabaseService.getCategories();
  Future<Map<String, dynamic>?> get _profileFuture =>
      _profile ??= SupabaseService.getProfile();

  @override
  void initState() {
    super.initState();
    _load();
    _productRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) return;
        setState(() {
          _products = SupabaseService.getProducts();
        });
      },
    );
  }

  void _load() {
    _products = SupabaseService.getProducts();
    _categories = SupabaseService.getCategories();
    _profile = SupabaseService.getProfile();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _productsFuture,
      _categoriesFuture,
      _profileFuture,
    ]);
  }

  void _reloadProducts() {
    setState(() {
      _products = SupabaseService.getProducts();
    });
  }

  void _reloadCategories() {
    setState(() => _categories = SupabaseService.getCategories());
  }

  @override
  void dispose() {
    _productRefreshTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const LovelleLogo(compact: true),
          actions: [
            IconButton(
              tooltip: 'Order updates',
              onPressed: widget.onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      friendlyErrorMessage(snapshot.error!),
                      style: const TextStyle(color: LovelleColors.mauve),
                    );
                  }
                  final name = snapshot.data?['full_name']?.toString().trim();
                  final firstName = name == null || name.isEmpty
                      ? 'there'
                      : name.split(RegExp(r'\s+')).first;
                  return Text(
                    'A little joy for you, $firstName',
                    style: const TextStyle(
                      color: LovelleColors.mauve,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSearch,
                decoration: InputDecoration(
                  hintText: 'Find a gift for someone special',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: () => widget.onSearch(_search.text.trim()),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 16, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFDDE8),
                      Color(0xFFFFF0E9),
                      Color(0xFFFFF8F1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LovelleColors.rose.withValues(alpha: .10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Make their day\nfeel a little more special.',
                            style: TextStyle(
                              color: giftlyInk,
                              fontSize: 22,
                              height: 1.18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Thoughtful little things, chosen with love.',
                            style: TextStyle(
                              color: LovelleColors.mauve,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: widget.onShop,
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 17),
                            label: const Text('Explore gifts'),
                            style: FilledButton.styleFrom(
                              backgroundColor: LovelleColors.rose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _GiftIllustration(),
                  ],
                ),
              ),
              FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadErrorState(
                      error: snapshot.error!,
                      onRetry: _reloadProducts,
                      compact: true,
                    );
                  }
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final roseGift = snapshot.data!.where(
                    (product) => product.isRoseGift,
                  );
                  if (roseGift.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _RoseGiftHighlight(
                      product: roseGift.first,
                      onTap: () => widget.onProduct(roseGift.first),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              const SectionHeading('Find a gift for every moment'),
              const SizedBox(height: 12),
              SizedBox(
                height: 108,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return LoadErrorState(
                        error: snapshot.error!,
                        onRetry: _reloadCategories,
                        compact: true,
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingState(compact: true);
                    }
                    final categories = snapshot.data ?? [];
                    if (categories.isEmpty) {
                      return const Text(
                        'Gift categories will appear here when available.',
                        style: TextStyle(color: LovelleColors.mauve),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                widget.onCategory(category['id'].toString()),
                            child: Container(
                              width: 112,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: LovelleColors.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: LovelleColors.rose,
                                    size: 25,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category['name'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: LovelleColors.plum,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),
              SectionHeading(
                'Thoughtful picks',
                action: 'See all',
                onAction: widget.onShop,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(
                        label: 'Finding thoughtful gifts…');
                  }
                  if (snapshot.hasError) {
                    return LoadErrorState(
                      error: snapshot.error!,
                      onRetry: _reloadProducts,
                    );
                  }
                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return const EmptyState(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Your gift gallery is on its way',
                      subtitle: 'Available gifts will show up here.',
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length < 4 ? products.length : 4,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: .69,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
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
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: widget.onShop,
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Browse the full collection'),
              ),
            ],
          ),
        ),
      );
}

class _RoseGiftHighlight extends StatelessWidget {
  const _RoseGiftHighlight({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: LovelleColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 104,
                    height: 116,
                    child: NetworkProductImage(url: product.imageUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A rose, your way',
                        style: TextStyle(
                          color: LovelleColors.roseDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LovelleColors.plum,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${peso.format(product.price)} · Fresh or artificial',
                        style: const TextStyle(
                          color: LovelleColors.mauve,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Text(
                            'Explore rose gift',
                            style: TextStyle(
                              color: LovelleColors.roseDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: LovelleColors.roseDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GiftIllustration extends StatelessWidget {
  const _GiftIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        height: 124,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.auto_awesome,
                color: LovelleColors.rose.withValues(alpha: .65),
                size: 23,
              ),
            ),
            Container(
              width: 72,
              height: 70,
              margin: const EdgeInsets.only(top: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F6),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: LovelleColors.rose.withValues(alpha: .14),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: LovelleColors.rose,
                size: 45,
              ),
            ),
            const Positioned(
              top: 5,
              left: 7,
              child: Icon(Icons.favorite, size: 15, color: Color(0xFFEF91AF)),
            ),
          ],
        ),
      );
}

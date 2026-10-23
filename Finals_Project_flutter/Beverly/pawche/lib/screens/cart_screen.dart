import 'dart:async';

import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../data/product_repository.dart';
import '../models/checkout.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'shop_screen.dart';

typedef CartProductLoader = Future<List<Product>> Function(List<String>);

class CartScreen extends StatefulWidget {
  final CartProductLoader? productsLoader;

  const CartScreen({super.key, this.productsLoader});

  @override
  CartScreenState createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  late final CartProductLoader _loadProducts =
      widget.productsLoader ?? ProductRepository.loadProductsBySlugs;
  Set<String> _lastProductSlugs = {};
  Set<String> _unavailableSlugs = {};
  Object? _refreshError;
  bool _refreshing = false;
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lastProductSlugs = _currentProductSlugs();
    CartStore.instance.addListener(_onCartChanged);
    if (_lastProductSlugs.isNotEmpty) {
      _refreshing = true;
      unawaited(_refreshCart());
    }
  }

  @override
  void dispose() {
    CartStore.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  Set<String> _currentProductSlugs() =>
      CartStore.instance.lines.map((line) => line.product.id).toSet();

  void _onCartChanged() {
    final currentSlugs = _currentProductSlugs();
    if (currentSlugs.length == _lastProductSlugs.length &&
        currentSlugs.containsAll(_lastProductSlugs)) {
      return;
    }
    _lastProductSlugs = currentSlugs;
    if (currentSlugs.isEmpty) {
      _refreshGeneration++;
      setState(() {
        _refreshing = false;
        _refreshError = null;
        _unavailableSlugs = {};
      });
      return;
    }
    unawaited(_refreshCart());
  }

  Future<void> _refreshCart() async {
    final slugs = _currentProductSlugs().toList();
    final generation = ++_refreshGeneration;
    if (slugs.isEmpty) return;
    if (mounted) {
      setState(() {
        _refreshing = true;
        _refreshError = null;
      });
    }
    try {
      final products = await _loadProducts(slugs);
      if (!mounted || generation != _refreshGeneration) return;
      final bySlug = {for (final product in products) product.id: product};
      for (final product in products) {
        CartStore.instance.updateProduct(product);
      }
      final currentSlugs = _currentProductSlugs();
      setState(() {
        _unavailableSlugs = currentSlugs.difference(bySlug.keys.toSet());
        _refreshError = null;
      });
    } catch (error) {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _refreshError = error);
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> refreshLiveData() => _refreshCart();

  Future<void> _proceedToCheckout() async {
    await _refreshCart();
    if (!mounted) return;
    if (_refreshError != null) {
      showMessage(
        context,
        'Refresh live prices and stock before checkout.',
      );
      return;
    }
    final unavailableLines = CartStore.instance.lines.where(
      (line) =>
          _unavailableSlugs.contains(line.product.id) ||
          line.product.stockQuantity == null ||
          line.product.stockQuantity! < line.quantity,
    );
    if (unavailableLines.isNotEmpty) {
      showMessage(
        context,
        'Update quantities or remove products that are no longer available.',
      );
      return;
    }

    final lines = CartStore.instance.lines;
    final subtotal = CartStore.instance.subtotal;
    final itemCount = CartStore.instance.itemCount;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          subtotal: subtotal,
          shipping: 0,
          itemCount: itemCount,
          removePurchasedItemsFromCart: true,
          lineItems: [
            for (final line in lines)
              CheckoutLineItem(
                productSlug: line.product.id,
                name: line.product.name,
                quantity: line.quantity,
                unitPrice: productPriceAmount(line.product),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: CartStore.instance,
        builder: (context, _) {
          final lines = CartStore.instance.lines;
          final subtotal = CartStore.instance.subtotal;
          final itemCount = CartStore.instance.itemCount;
          const shipping = 0;

          final unavailableLines = lines.where(
            (line) =>
                _unavailableSlugs.contains(line.product.id) ||
                line.product.stockQuantity == null ||
                line.product.stockQuantity! < line.quantity,
          );

          return Scaffold(
            appBar: AppBar(
              title: const Text('My Cart'),
              actions: [
                IconButton(
                  tooltip: 'Refresh live prices and stock',
                  onPressed: _refreshing ? null : _refreshCart,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: lines.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: PawcheColors.pink,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your cart is ready for a little love.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PawcheColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explore live products and add something for your pet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PawcheColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ShopScreen()),
                            ),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Explore the shop'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      PawchePageTitle(
                        'Ready for checkout?',
                        subtitle: '$itemCount '
                            '${itemCount == 1 ? 'item' : 'items'} in your cart · '
                            'Live prices and stock',
                      ),
                      _CartStatusCard(
                        refreshing: _refreshing,
                        error: _refreshError,
                        unavailableCount: unavailableLines.length,
                        onRetry: _refreshCart,
                      ),
                      const SizedBox(height: 8),
                      for (final line in lines)
                        _CartItem(
                          product: line.product,
                          quantity: line.quantity,
                          unavailable:
                              _unavailableSlugs.contains(line.product.id),
                          onDecrease: () => CartStore.instance.decrease(
                            line.product.id,
                          ),
                          onIncrease: _refreshing ||
                                  _refreshError != null ||
                                  _unavailableSlugs.contains(line.product.id) ||
                                  line.product.stockQuantity == null ||
                                  line.quantity >= line.product.stockQuantity!
                              ? null
                              : () => CartStore.instance.increase(
                                    line.product.id,
                                  ),
                          onRemove: () =>
                              CartStore.instance.remove(line.product.id),
                        ),
                      const SizedBox(height: 6),
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _PriceRow(
                                  label: 'Subtotal',
                                  value: formatPeso(subtotal)),
                              const SizedBox(height: 10),
                              _PriceRow(
                                label: 'Delivery',
                                value: 'Free',
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(),
                              ),
                              _PriceRow(
                                label: 'Total',
                                value: formatPeso(subtotal + shipping),
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PinkButton(
                        label: _refreshing
                            ? 'Checking live availability…'
                            : 'Continue to checkout · ${formatPeso(subtotal)}',
                        onPressed: _refreshing ||
                                _refreshError != null ||
                                unavailableLines.isNotEmpty
                            ? null
                            : _proceedToCheckout,
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Free delivery · Final prices confirmed at checkout',
                          style: TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      );
}

class _CartItem extends StatelessWidget {
  final Product product;
  final int quantity;
  final bool unavailable;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;

  const _CartItem({
    required this.product,
    required this.quantity,
    required this.unavailable,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.stockQuantity;
    final stockLabel = unavailable
        ? 'No longer in the live catalog'
        : stock == null
            ? 'Stock could not be confirmed'
            : stock == 0
                ? 'Currently out of stock'
                : quantity > stock
                    ? 'Only $stock available · reduce quantity'
                    : 'In stock · $stock available';
    final stockColor =
        unavailable || stock == null || stock == 0 || quantity > stock
            ? PawcheColors.darkPink
            : PawcheColors.green;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PawcheColors.pale,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ProductArtwork(
                    emoji: product.emoji,
                    imageAsset: product.imageAsset,
                    imageUrl: product.imageUrl,
                    size: 60,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      const SizedBox(height: 5),
                      Text(
                        '${product.price} each',
                        style: const TextStyle(
                          color: PawcheColors.darkPink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${product.name}',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: PawcheColors.muted,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                _QtyButton(
                  label: 'Remove one',
                  icon: Icons.remove,
                  onPressed: onDecrease,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: PawcheColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QtyButton(
                  label: 'Add one',
                  icon: Icons.add,
                  onPressed: onIncrease,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  unavailable || stock == null || stock == 0 || quantity > stock
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: stockColor,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    stockLabel,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Item total',
                      style: TextStyle(
                        color: PawcheColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formatPeso(productPriceAmount(product) * quantity),
                      style: const TextStyle(
                        color: PawcheColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartStatusCard extends StatelessWidget {
  final bool refreshing;
  final Object? error;
  final int unavailableCount;
  final Future<void> Function() onRetry;

  const _CartStatusCard({
    required this.refreshing,
    required this.error,
    required this.unavailableCount,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final unavailable = unavailableCount > 0;
    final color = hasError || unavailable
        ? PawcheColors.darkPink
        : refreshing
            ? PawcheColors.navy
            : PawcheColors.green;
    final icon = hasError
        ? Icons.cloud_off_outlined
        : unavailable
            ? Icons.inventory_2_outlined
            : refreshing
                ? Icons.sync_rounded
                : Icons.verified_outlined;
    final title = hasError
        ? 'Could not verify live product details'
        : unavailable
            ? '$unavailableCount ${unavailableCount == 1 ? 'item needs' : 'items need'} attention'
            : refreshing
                ? 'Checking current prices and stock…'
                : 'Prices and availability are up to date';
    final description = hasError
        ? 'Checkout is paused until current prices and stock can be checked.'
        : unavailable
            ? 'Review the marked items and reduce quantities or remove them.'
            : refreshing
                ? 'Your cart is being matched with the live catalog.'
                : 'Your subtotal uses the latest product prices. Delivery is free.';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          if (refreshing && !hasError)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: PawcheColors.pink,
                strokeWidth: 2,
              ),
            )
          else
            Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (hasError)
            IconButton(
              tooltip: 'Retry live product check',
              onPressed: refreshing ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded),
              color: PawcheColors.navy,
            ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          tooltip: label,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: PawcheColors.blush,
            foregroundColor: PawcheColors.darkPink,
          ),
          icon: Icon(icon, size: 16),
        ),
      );
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: PawcheColors.navy,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: emphasize ? PawcheColors.darkPink : PawcheColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: emphasize ? 18 : 14,
            ),
          ),
        ],
      );
}

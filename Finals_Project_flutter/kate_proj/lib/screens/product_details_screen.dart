import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _busy = false;
  int _quantity = 1;

  Future<void> _addToCart() async {
    setState(() => _busy = true);
    try {
      await SupabaseService.addToCart(
        widget.product.id,
        quantity: _quantity,
      );
      if (mounted) showMessage(context, 'Added to your bag');
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWishlist() async {
    try {
      await SupabaseService.toggleWishlist(widget.product.id);
      if (mounted) showMessage(context, 'Wishlist updated');
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inStock = product.stockQuantity > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Gift details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Hero(
            tag: 'product-${product.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: NetworkProductImage(url: product.imageUrl, height: 330),
            ),
          ),
          const SizedBox(height: 22),
          if (product.categoryName != null)
            Text(
              product.categoryName!.toUpperCase(),
              style: const TextStyle(
                color: LovelleColors.roseDark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 7),
          Text(
            product.name,
            style: const TextStyle(
              color: LovelleColors.plum,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            peso.format(product.price),
            style: const TextStyle(
              color: LovelleColors.roseDark,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.description.isEmpty
                ? 'A thoughtful gift to make their day feel extra special.'
                : product.description,
            style: const TextStyle(
              color: LovelleColors.mauve,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: LovelleColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  inStock ? Icons.check_circle_outline : Icons.info_outline,
                  color: inStock ? LovelleColors.sage : LovelleColors.mauve,
                ),
                const SizedBox(width: 10),
                Text(
                  inStock
                      ? 'Ready to make someone smile · ${product.stockQuantity} available'
                      : 'This gift is currently unavailable',
                  style: const TextStyle(color: LovelleColors.plum),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quantity',
                  style: TextStyle(
                    color: LovelleColors.plum,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Decrease quantity',
                onPressed:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(
                  '$_quantity',
                  key: ValueKey(_quantity),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Increase quantity',
                onPressed: _quantity < product.stockQuantity
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy || !inStock ? null : _addToCart,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(inStock ? 'Add to bag' : 'Currently unavailable'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _toggleWishlist,
            icon: const Icon(Icons.favorite_border_rounded),
            label: const Text('Save to wishlist'),
          ),
        ],
      ),
    );
  }
}

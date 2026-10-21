import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onWishlist,
    this.onAddToCart,
    this.isWishlisted = false,
  });

  final Product product;
  final VoidCallback onTap;
  final Future<void> Function() onWishlist;
  final Future<void> Function()? onAddToCart;
  final bool isWishlisted;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _saved = false;
  bool _saving = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isWishlisted;
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWishlisted != widget.isWishlisted) {
      _saved = widget.isWishlisted;
    }
  }

  Future<void> _toggleWishlist() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onWishlist();
      if (mounted) setState(() => _saved = !_saved);
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addToCart() async {
    final addToCart = widget.onAddToCart;
    if (_adding || addToCart == null) return;
    setState(() => _adding = true);
    try {
      await addToCart();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: LovelleColors.border),
            boxShadow: [
              BoxShadow(
                color: LovelleColors.plum.withValues(alpha: .035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'product-${product.id}',
                      child: NetworkProductImage(url: product.imageUrl),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: .94),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: _saved
                              ? 'Remove from wishlist'
                              : 'Save to wishlist',
                          visualDensity: VisualDensity.compact,
                          onPressed: _saving ? null : _toggleWishlist,
                          icon: AnimatedScale(
                            scale: _saved ? 1.12 : 1,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Icon(
                              _saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: LovelleColors.rose,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (product.isFeatured)
                      const Positioned(
                        left: 7,
                        top: 7,
                        child: _FeaturedBadge(),
                      ),
                    if (product.isRoseGift)
                      const Positioned(
                        left: 7,
                        bottom: 7,
                        child: _RoseGiftBadge(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LovelleColors.plum,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      peso.format(product.price),
                      style: const TextStyle(
                        color: LovelleColors.roseDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (widget.onAddToCart != null)
                    IconButton(
                      key: ValueKey('add-to-cart-${product.id}'),
                      tooltip: 'Add to bag',
                      visualDensity: VisualDensity.compact,
                      onPressed: product.stockQuantity > 0 && !_adding
                          ? _addToCart
                          : null,
                      icon: _adding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add_shopping_cart_rounded,
                              color: LovelleColors.rose,
                              size: 19,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    product.stockQuantity > 0
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 13,
                    color: product.stockQuantity > 0
                        ? LovelleColors.sage
                        : LovelleColors.mauve,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      product.stockQuantity > 0 ? 'In stock' : 'Out of stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LovelleColors.mauve,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: LovelleColors.cream.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'LOVED',
            style: TextStyle(
              color: LovelleColors.roseDark,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ),
      );
}

class _RoseGiftBadge extends StatelessWidget {
  const _RoseGiftBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'ROSE GIFT',
            style: TextStyle(
              color: LovelleColors.roseDark,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ),
      );
}

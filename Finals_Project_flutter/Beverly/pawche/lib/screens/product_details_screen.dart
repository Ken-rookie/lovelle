import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../data/product_repository.dart';
import '../models/checkout.dart';
import '../models/product.dart';
import '../models/product_review.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final Future<ProductDetailsData> Function(Product product) detailsLoader;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.detailsLoader = ProductRepository.loadDetails,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  bool _favorite = false;
  bool _favoriteBusy = false;
  Object? _favoriteLoadError;
  late Future<ProductDetailsData> _details;

  @override
  void initState() {
    super.initState();
    _details = widget.detailsLoader(widget.product);
    _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _details = widget.detailsLoader(widget.product);
      _favorite = false;
      _favoriteLoadError = null;
      _loadFavorite();
    }
  }

  Future<void> _loadFavorite() async {
    try {
      final favorite = await ProductRepository.isWishlisted(widget.product.id);
      if (mounted) {
        setState(() {
          _favorite = favorite;
          _favoriteLoadError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _favoriteLoadError = error);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      if (_favoriteLoadError != null) {
        _favorite = await ProductRepository.isWishlisted(widget.product.id);
      }
      final saved = await ProductRepository.toggleWishlist(widget.product.id);
      if (!mounted) return;
      setState(() {
        _favorite = saved;
        _favoriteLoadError = null;
      });
      showMessage(
        context,
        saved
            ? 'Product saved to your wishlist.'
            : 'Removed from your wishlist.',
      );
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _writeReview(Product product) async {
    final review = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => const _WriteReviewDialog(),
    );
    if (review == null || !mounted) return;

    try {
      await ProductRepository.submitReview(
        productSlug: product.id,
        rating: review.rating,
        title: review.title,
        body: review.body,
      );
      if (!mounted) return;
      showMessage(
        context,
        'Thanks! Your review was submitted and will appear after approval.',
      );
      setState(() => _details = widget.detailsLoader(widget.product));
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    }
  }

  void _addToCart(Product product, int? stockQuantity) {
    final existingQuantity = CartStore.instance.lines
        .where((line) => line.product.id == product.id)
        .fold<int>(0, (total, line) => total + line.quantity);
    if (stockQuantity != null && existingQuantity + _quantity > stockQuantity) {
      showMessage(
        context,
        existingQuantity >= stockQuantity
            ? 'Your cart already has all $stockQuantity available.'
            : 'Only ${stockQuantity - existingQuantity} more available to add.',
      );
      return;
    }
    if (!CartStore.instance.add(product, quantity: _quantity)) {
      showMessage(
          context, 'Refresh this product to confirm its current stock.');
      return;
    }
    showMessage(
      context,
      '$_quantity ${_quantity == 1 ? 'item' : 'items'} added to your cart.',
    );
  }

  void _buyNow(Product product, int? stockQuantity) {
    if (stockQuantity != null && _quantity > stockQuantity) {
      showMessage(context, 'The selected quantity is no longer available.');
      return;
    }
    final subtotal = productPriceAmount(product) * _quantity;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          subtotal: subtotal,
          itemCount: _quantity,
          lineItems: [
            CheckoutLineItem(
              productSlug: product.id,
              name: product.name,
              quantity: _quantity,
              unitPrice: productPriceAmount(product),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductDetailsData>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(title: const Text('Product Details')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Product Details')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: PawcheColors.muted,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Product details couldn’t be loaded.',
                        style: TextStyle(
                          color: PawcheColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PawcheColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _details = widget.detailsLoader(widget.product),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final details = snapshot.data!;
          final product = details.product;
          final imageAsset = product.imageAsset;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Product Details'),
              actions: [
                IconButton(
                  tooltip:
                      _favorite ? 'Remove from wishlist' : 'Add to wishlist',
                  onPressed: _favoriteBusy ? null : _toggleFavorite,
                  icon: Icon(
                    _favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: PawcheColors.pink,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    children: [
                      Container(
                        height: 248,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PawcheColors.blush,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: imageAsset == null
                            ? ProductArtwork(
                                emoji: product.emoji,
                                imageAsset: imageAsset,
                                imageUrl: product.imageUrl,
                                size: 112,
                              )
                            : Padding(
                                padding: const EdgeInsets.all(20),
                                child: ProductArtwork(
                                  emoji: product.emoji,
                                  imageAsset: imageAsset,
                                  imageUrl: product.imageUrl,
                                  size: 190,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: PawcheColors.blush,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                color: PawcheColors.darkPink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (details.rating.reviewCount > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB400),
                              size: 18,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${details.rating.averageRating.toStringAsFixed(1)} (${details.rating.reviewCount})',
                              style: const TextStyle(
                                color: PawcheColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PawcheColors.navy,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PawcheColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Price',
                                    style: TextStyle(
                                      color: PawcheColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.price,
                                    style: const TextStyle(
                                      color: PawcheColors.darkPink,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _StockLabel(
                                  quantity: details.stockQuantity,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!details.isLive)
                        const _LiveDataNotice()
                      else
                        _ReviewsSection(
                          summary: details.rating,
                          reviews: details.reviews,
                          userReviewStatus: details.userReviewStatus,
                          onWriteReview: details.userReviewStatus != null
                              ? null
                              : () => _writeReview(product),
                        ),
                      const SizedBox(height: 20),
                      SectionTitle(
                        'Product details',
                        trailing: const Icon(
                          Icons.info_outline_rounded,
                          color: PawcheColors.muted,
                          size: 18,
                        ),
                      ),
                      Text(
                        product.description,
                        style: const TextStyle(
                          color: PawcheColors.navy,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (details.isLive) ...[
                        const Divider(),
                        const Text(
                          'Price and availability are from the Pawché catalog. Availability can change before checkout.',
                          style: TextStyle(
                              color: PawcheColors.muted, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PawcheColors.border),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quantity',
                                    style: TextStyle(
                                      color: PawcheColors.navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Choose how many to order',
                                    style: TextStyle(
                                      color: PawcheColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.remove,
                              label: 'Decrease quantity',
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                '$_quantity',
                                semanticsLabel: 'Quantity $_quantity',
                                style: const TextStyle(
                                  color: PawcheColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.add,
                              label: 'Increase quantity',
                              onPressed: details.stockQuantity == null ||
                                      _quantity >= details.stockQuantity!
                                  ? null
                                  : () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: PawcheColors.border),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PawcheColors.navy.withValues(alpha: .06),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Order subtotal',
                                style: TextStyle(
                                  color: PawcheColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              formatPeso(
                                productPriceAmount(product) * _quantity,
                              ),
                              style: const TextStyle(
                                color: PawcheColors.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: details.stockQuantity == null ||
                                        details.stockQuantity == 0
                                    ? null
                                    : () => _addToCart(
                                          product,
                                          details.stockQuantity,
                                        ),
                                icon: const Icon(
                                  Icons.add_shopping_cart_outlined,
                                  size: 18,
                                ),
                                label: const Text('Add to cart'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: details.stockQuantity == null ||
                                        details.stockQuantity == 0
                                    ? null
                                    : () => _buyNow(
                                          product,
                                          details.stockQuantity,
                                        ),
                                icon: const Icon(
                                  Icons.flash_on_rounded,
                                  size: 18,
                                ),
                                label: const Text('Buy now'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _StockLabel extends StatelessWidget {
  final int? quantity;

  const _StockLabel({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final color = quantity == null
        ? PawcheColors.muted
        : quantity! > 0
            ? PawcheColors.green
            : PawcheColors.darkPink;
    final label = quantity == null
        ? 'Availability not provided'
        : quantity! > 0
            ? 'In stock · $quantity available'
            : 'Currently out of stock';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      children: [
        Icon(
          quantity == null
              ? Icons.help_outline_rounded
              : quantity! > 0
                  ? Icons.check_circle
                  : Icons.remove_circle_outline,
          color: color,
          size: 17,
        ),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LiveDataNotice extends StatelessWidget {
  const _LiveDataNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PawcheColors.blush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Live product information and customer reviews are unavailable. Apply the product catalog and reviews migration in Supabase to load them.',
          style: TextStyle(
            color: PawcheColors.navy,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      );
}

class _ReviewsSection extends StatelessWidget {
  final ProductRatingSummary summary;
  final List<ProductReview> reviews;
  final String? userReviewStatus;
  final VoidCallback? onWriteReview;

  const _ReviewsSection({
    required this.summary,
    required this.reviews,
    required this.userReviewStatus,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Customer reviews',
            trailing: onWriteReview == null
                ? Text(
                    switch (userReviewStatus) {
                      'pending' => 'Review pending',
                      'approved' => 'You reviewed',
                      'rejected' => 'Review not approved',
                      _ => 'Review submitted',
                    },
                    style: TextStyle(
                      color: PawcheColors.muted,
                      fontSize: 12,
                    ),
                  )
                : TextButton.icon(
                    onPressed: onWriteReview,
                    icon: const Icon(Icons.rate_review_outlined, size: 17),
                    label: const Text('Write a review'),
                  ),
          ),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        summary.reviewCount == 0
                            ? '—'
                            : summary.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: PawcheColors.navy,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StarRow(rating: summary.averageRating),
                            const SizedBox(height: 2),
                            Text(
                              summary.reviewCount == 0
                                  ? 'No approved reviews yet'
                                  : 'Based on ${summary.reviewCount} ${summary.reviewCount == 1 ? 'review' : 'reviews'}',
                              style: const TextStyle(
                                color: PawcheColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (summary.reviewCount > 0) ...[
                    const SizedBox(height: 12),
                    for (var stars = 5; stars >= 1; stars++)
                      _RatingBar(
                        stars: stars,
                        count: summary.ratingCounts[stars] ?? 0,
                        total: summary.reviewCount,
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (userReviewStatus == 'pending')
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(
                'Your review is awaiting approval and will appear here once approved.',
                style: TextStyle(color: PawcheColors.muted, fontSize: 12),
              ),
            ),
          if (userReviewStatus == 'rejected')
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(
                'Your review was not approved for display. You can contact support if you have questions.',
                style: TextStyle(color: PawcheColors.muted, fontSize: 12),
              ),
            ),
          if (reviews.isEmpty && userReviewStatus != 'pending')
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(
                'Reviews from customers will appear here after approval.',
                style: TextStyle(color: PawcheColors.muted, fontSize: 12),
              ),
            ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final review in reviews) _ReviewCard(review: review),
          ],
        ],
      );
}

class _StarRow extends StatelessWidget {
  final double rating;

  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              star <= rating.round()
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: const Color(0xFFFFB400),
              size: 17,
            ),
        ],
      );
}

class _RatingBar extends StatelessWidget {
  final int stars;
  final int count;
  final int total;

  const _RatingBar({
    required this.stars,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 37,
              child: Text(
                '$stars star',
                style: const TextStyle(
                  color: PawcheColors.muted,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: count / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: PawcheColors.blush,
                color: PawcheColors.pink,
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: PawcheColors.muted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  final ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt.toLocal();
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: PawcheColors.blush,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: PawcheColors.darkPink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pawché customer',
                    style: TextStyle(
                      color: PawcheColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${date.month}/${date.day}/${date.year}',
                  style: const TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _StarRow(rating: review.rating.toDouble()),
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review.title!,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              review.body,
              style: const TextStyle(
                color: PawcheColors.navy,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewDraft {
  final int rating;
  final String? title;
  final String body;

  const _ReviewDraft(this.rating, this.title, this.body);
}

class _WriteReviewDialog extends StatefulWidget {
  const _WriteReviewDialog();

  @override
  State<_WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<_WriteReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Write a product review'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your rating'),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: '$star star${star == 1 ? '' : 's'}',
                        onPressed: () => setState(() => _rating = star),
                        color: const Color(0xFFFFB400),
                        icon: Icon(
                          star <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                      ),
                  ],
                ),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Review title (optional)',
                  ),
                ),
                TextFormField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Your review',
                    hintText: 'Share your experience with this product',
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 10) {
                      return 'Write at least 10 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Reviews are checked before they appear publicly. One review per account for each product.',
                  style: TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _ReviewDraft(
                  _rating,
                  _title.text.trim(),
                  _body.text.trim(),
                ),
              );
            },
            child: const Text('Submit review'),
          ),
        ],
      );
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _QuantityButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: PawcheColors.blush,
          foregroundColor: PawcheColors.darkPink,
        ),
        icon: Icon(icon, size: 18),
      );
}

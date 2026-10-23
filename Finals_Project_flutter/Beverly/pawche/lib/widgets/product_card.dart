import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_review.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final ProductRatingSummary? ratingSummary;
  final bool isFavorite;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onFavorite,
    required this.onAdd,
    this.ratingSummary,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageAsset = product.imageAsset;

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PawcheColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Material(
                      color: PawcheColors.pale,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onTap,
                        child: Center(
                          child: ProductArtwork(
                            emoji: product.emoji,
                            imageAsset: imageAsset,
                            imageUrl: product.imageUrl,
                            size: 76,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: isFavorite
                          ? 'Remove ${product.name} from wishlist'
                          : 'Add ${product.name} to wishlist',
                      visualDensity: VisualDensity.compact,
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: PawcheColors.pink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PawcheColors.muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.stockQuantity == null
                  ? 'Availability unavailable'
                  : product.stockQuantity! > 0
                      ? 'In stock · ${product.stockQuantity}'
                      : 'Out of stock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: product.stockQuantity == null
                    ? PawcheColors.muted
                    : product.stockQuantity! > 0
                        ? PawcheColors.green
                        : PawcheColors.darkPink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: onTap,
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (ratingSummary != null) ...[
              const SizedBox(height: 3),
              _ProductRatingLine(summary: ratingSummary!),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PawcheColors.darkPink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Add ${product.name} to cart',
                  visualDensity: VisualDensity.compact,
                  onPressed: product.stockQuantity == null ||
                          product.stockQuantity == 0
                      ? null
                      : onAdd,
                  style: IconButton.styleFrom(
                    backgroundColor: PawcheColors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRatingLine extends StatelessWidget {
  final ProductRatingSummary summary;

  const _ProductRatingLine({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.reviewCount == 0) {
      return const Text(
        'No reviews yet',
        style: TextStyle(color: PawcheColors.muted, fontSize: 11),
      );
    }

    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB400), size: 15),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            '${summary.averageRating.toStringAsFixed(1)} · ${summary.reviewCount} ${summary.reviewCount == 1 ? 'review' : 'reviews'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PawcheColors.muted,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

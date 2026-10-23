import 'product.dart';

class ProductRatingSummary {
  final double averageRating;
  final int reviewCount;
  final Map<int, int> ratingCounts;

  const ProductRatingSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.ratingCounts,
  });

  const ProductRatingSummary.empty()
      : averageRating = 0,
        reviewCount = 0,
        ratingCounts = const {};
}

class ProductReview {
  final int rating;
  final String? title;
  final String body;
  final DateTime createdAt;

  const ProductReview({
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}

class ProductDetailsData {
  final Product product;
  final ProductRatingSummary rating;
  final List<ProductReview> reviews;
  final int? stockQuantity;
  final String? userReviewStatus;
  final bool isLive;

  const ProductDetailsData({
    required this.product,
    required this.rating,
    required this.reviews,
    required this.stockQuantity,
    required this.userReviewStatus,
    required this.isLive,
  });
}

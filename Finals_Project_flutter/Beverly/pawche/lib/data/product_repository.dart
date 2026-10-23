import '../config/supabase_service.dart';
import '../models/product.dart';
import '../models/product_review.dart';

class ProductRepository {
  static Future<List<Product>> loadCatalog() async {
    await SupabaseService.waitForInitialization();
    final client = SupabaseService.initializedClient;
    if (client == null) {
      throw StateError(
        'Live products are unavailable because Supabase is not configured or failed to initialize.',
      );
    }

    final rows = await client
        .from('products')
        .select(
          'slug, name, category, description, price, currency, stock_quantity, image_url',
        )
        .eq('is_active', true)
        .order('name')
        .timeout(const Duration(seconds: 20));

    return List<Map<String, dynamic>>.from(rows).map((row) {
      final slug = row['slug'] as String;
      return Product(
        id: slug,
        name: row['name'] as String,
        category: row['category'] as String,
        price: _formatPrice(row['price'] as num, row['currency'] as String),
        emoji: '',
        description: row['description'] as String,
        stockQuantity: row['stock_quantity'] as int?,
        imageUrl: row['image_url'] as String?,
      );
    }).toList();
  }

  static Future<List<Product>> loadProductsBySlugs(
    List<String> productSlugs,
  ) async {
    if (productSlugs.isEmpty) return [];

    final client = SupabaseService.initializedClient;
    if (client == null) {
      throw StateError(
        'Live product information is unavailable because Supabase is not configured.',
      );
    }

    final rows = await client
        .from('products')
        .select(
          'slug, name, category, description, price, currency, stock_quantity, image_url',
        )
        .inFilter('slug', productSlugs)
        .eq('is_active', true);

    return List<Map<String, dynamic>>.from(rows).map(_productFromRow).toList();
  }

  static Future<List<Product>> loadWishlist() async {
    final client = SupabaseService.initializedClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Sign in to view your saved products.');
    }
    final favorites = await client
        .from('product_wishlist')
        .select('product_slug')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final slugs = List<Map<String, dynamic>>.from(favorites)
        .map((row) => row['product_slug'] as String)
        .toList();
    if (slugs.isEmpty) return [];
    final products = await loadProductsBySlugs(slugs);
    final bySlug = {for (final product in products) product.id: product};
    return slugs.map((slug) => bySlug[slug]).whereType<Product>().toList();
  }

  static Future<bool> toggleWishlist(String productSlug) async {
    final client = SupabaseService.initializedClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Sign in to save products to your wishlist.');
    }
    final existing = await client
        .from('product_wishlist')
        .select('product_slug')
        .eq('user_id', user.id)
        .eq('product_slug', productSlug)
        .maybeSingle();
    if (existing != null) {
      await client
          .from('product_wishlist')
          .delete()
          .eq('user_id', user.id)
          .eq('product_slug', productSlug);
      return false;
    }
    await client.from('product_wishlist').insert({
      'user_id': user.id,
      'product_slug': productSlug,
    });
    return true;
  }

  static Future<void> removeWishlist(String productSlug) async {
    final client = SupabaseService.initializedClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Sign in to manage your wishlist.');
    }
    await client
        .from('product_wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('product_slug', productSlug);
  }

  static Future<bool> isWishlisted(String productSlug) async {
    final client = SupabaseService.initializedClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return false;
    final result = await client
        .from('product_wishlist')
        .select('product_slug')
        .eq('user_id', user.id)
        .eq('product_slug', productSlug)
        .maybeSingle();
    return result != null;
  }

  static Future<Map<String, ProductRatingSummary>> loadRatingSummaries(
    List<String> productSlugs,
  ) async {
    final client = SupabaseService.initializedClient;
    if (client == null || productSlugs.isEmpty) return {};

    final products = await client
        .from('products')
        .select('id, slug')
        .inFilter('slug', productSlugs);
    final productRows = List<Map<String, dynamic>>.from(products);
    if (productRows.isEmpty) return {};

    final productIds =
        productRows.map((product) => product['id'] as Object).toList();
    final summaries = await client
        .from('product_rating_summary')
        .select()
        .inFilter('product_id', productIds);
    final byProductId = <Object, ProductRatingSummary>{
      for (final row in List<Map<String, dynamic>>.from(summaries))
        row['product_id'] as Object: _summaryFromRow(row),
    };

    return {
      for (final product in productRows)
        product['slug'] as String: byProductId[product['id'] as Object] ??
            const ProductRatingSummary.empty(),
    };
  }

  static Future<ProductDetailsData> loadDetails(Product product) async {
    final client = SupabaseService.initializedClient;
    if (client == null) {
      throw StateError(
        'Live product details are unavailable because Supabase is not configured.',
      );
    }

    final productRow = await client
        .from('products')
        .select(
          'id, slug, name, category, description, price, currency, stock_quantity, image_url',
        )
        .eq('slug', product.id)
        .maybeSingle();
    if (productRow == null) {
      throw StateError('This product is not available in the online catalog.');
    }

    final productId = productRow['id'] as Object;
    final liveProduct = _productFromRow(
      Map<String, dynamic>.from(productRow),
    );
    final summaryRows = await client
        .from('product_rating_summary')
        .select()
        .eq('product_id', productId);
    final reviewRows = await client
        .from('product_reviews')
        .select('rating, title, body, created_at')
        .eq('product_id', productId)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(50);
    final currentUserId = client.auth.currentUser?.id;
    final userReview = currentUserId == null
        ? null
        : await client
            .from('product_reviews')
            .select('status')
            .eq('product_id', productId)
            .eq('user_id', currentUserId)
            .inFilter(
                'status', ['pending', 'approved', 'rejected']).maybeSingle();
    final summaryList = List<Map<String, dynamic>>.from(summaryRows);
    final reviewList = List<Map<String, dynamic>>.from(reviewRows);

    return ProductDetailsData(
      product: liveProduct,
      rating: summaryList.isEmpty
          ? const ProductRatingSummary.empty()
          : _summaryFromRow(summaryList.first),
      reviews: reviewList
          .map(
            (row) => ProductReview(
              rating: row['rating'] as int,
              title: row['title'] as String?,
              body: row['body'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .toList(),
      stockQuantity: productRow['stock_quantity'] as int?,
      userReviewStatus: userReview?['status'] as String?,
      isLive: true,
    );
  }

  static Future<void> submitReview({
    required String productSlug,
    required int rating,
    required String? title,
    required String body,
  }) async {
    final client = SupabaseService.initializedClient;
    if (client == null) {
      throw StateError('Sign in to submit a product review.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to submit a product review.');
    }

    final product = await client
        .from('products')
        .select('id')
        .eq('slug', productSlug)
        .eq('is_active', true)
        .maybeSingle();
    if (product == null) {
      throw StateError('This product is not available for review.');
    }

    await client.from('product_reviews').insert({
      'product_id': product['id'],
      'user_id': user.id,
      'rating': rating,
      'title': title?.trim().isEmpty ?? true ? null : title!.trim(),
      'body': body.trim(),
    });
  }

  static ProductRatingSummary _summaryFromRow(Map<String, dynamic> row) =>
      ProductRatingSummary(
        averageRating: (row['average_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
        ratingCounts: {
          for (var stars = 1; stars <= 5; stars++)
            stars: (row['rating_${stars}_count'] as num?)?.toInt() ?? 0,
        },
      );

  static Product _productFromRow(Map<String, dynamic> row) => Product(
        id: row['slug'] as String,
        name: row['name'] as String,
        category: row['category'] as String,
        price: _formatPrice(row['price'] as num, row['currency'] as String),
        emoji: '',
        description: row['description'] as String,
        stockQuantity: row['stock_quantity'] as int?,
        imageUrl: row['image_url'] as String?,
      );

  static String _formatPrice(num amount, String currency) {
    final parts = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final symbol = switch (currency) {
      'PHP' => '₱',
      'USD' => r'$',
      'EUR' => '€',
      _ => '$currency ',
    };
    return '$symbol$whole${parts.length == 1 ? '' : '.${parts.last}'}';
  }
}

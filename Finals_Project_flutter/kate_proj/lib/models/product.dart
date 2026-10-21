class Product {
  static const double fixedPrice = 1.0;

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String? categoryId;
  final String? categoryName;
  final int stockQuantity;
  final bool isFeatured;
  final bool isRoseGift;

  const Product(
      {required this.id,
      required this.name,
      required this.description,
      required this.price,
      required this.imageUrl,
      this.categoryId,
      this.categoryName,
      this.stockQuantity = 0,
      this.isFeatured = false,
      this.isRoseGift = false});

  static double normalizePrice(dynamic rawValue) {
    final parsed = double.tryParse(rawValue?.toString() ?? '') ?? 0;
    return parsed > 0 ? fixedPrice : 0;
  }

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'].toString(),
        name: map['name']?.toString() ?? 'Gift',
        description: map['description']?.toString() ?? '',
        price: normalizePrice(map['price']),
        imageUrl: map['image_url']?.toString() ?? '',
        categoryId: map['category_id']?.toString(),
        categoryName: map['categories'] is Map
            ? map['categories']['name']?.toString()
            : null,
        stockQuantity:
            int.tryParse((map['stock_quantity'] ?? 0).toString()) ?? 0,
        isFeatured: map['is_featured'] == true,
        isRoseGift: map['is_rose_gift'] == true,
      );
}

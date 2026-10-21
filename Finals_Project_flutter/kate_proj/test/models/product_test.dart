import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/models/product.dart';

void main() {
  group('Product.fromMap', () {
    test('parses rose gift properties and nested category', () {
      final product = Product.fromMap({
        'id': 'rose-1',
        'name': 'Lovelle Rose Gift',
        'description': 'Choose a rose style at checkout.',
        'price': 499,
        'image_url': 'https://example.com/rose.jpg',
        'category_id': 'flowers',
        'categories': {'name': 'Flowers'},
        'stock_quantity': 20,
        'is_featured': true,
        'is_rose_gift': true,
      });

      expect(product.id, 'rose-1');
      expect(product.price, 499);
      expect(product.categoryName, 'Flowers');
      expect(product.stockQuantity, 20);
      expect(product.isFeatured, isTrue);
      expect(product.isRoseGift, isTrue);
    });

    test('uses safe defaults for optional product fields', () {
      final product = Product.fromMap({
        'id': 'gift-1',
        'name': 'A thoughtful gift',
        'price': 'not-a-price',
      });

      expect(product.description, isEmpty);
      expect(product.price, 0);
      expect(product.imageUrl, isEmpty);
      expect(product.stockQuantity, 0);
      expect(product.isFeatured, isFalse);
      expect(product.isRoseGift, isFalse);
    });
  });
}

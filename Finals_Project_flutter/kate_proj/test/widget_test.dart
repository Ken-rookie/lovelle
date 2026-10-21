// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/main.dart';
import 'package:giftly_customer/models/product.dart';

void main() {
  testWidgets('Lovelle app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const LovelleApp());

    expect(find.text('Lovelle'), findsOneWidget);
  });

  test('all product prices are normalized to 1 PHP', () {
    final product = Product.fromMap({
      'id': 'p1',
      'name': 'Test Gift',
      'price': '250.00',
      'image_url': 'https://example.com/gift.png',
    });

    expect(product.price, 1.0);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/models/product.dart';
import 'package:giftly_customer/widgets/product_card.dart';

void main() {
  testWidgets('shows saved state for a wishlist product', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 330,
            child: ProductCard(
              product: const Product(
                id: 'gift-1',
                name: 'Thoughtful gift',
                description: '',
                price: 100,
                imageUrl: '',
                stockQuantity: 5,
              ),
              isWishlisted: true,
              onTap: () {},
              onWishlist: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);
  });

  testWidgets('disables repeated add-to-cart taps while the request is pending',
      (tester) async {
    final request = Completer<void>();
    var addCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 330,
            child: ProductCard(
              product: const Product(
                id: 'gift-1',
                name: 'Thoughtful gift',
                description: '',
                price: 100,
                imageUrl: '',
                stockQuantity: 5,
              ),
              onTap: () {},
              onWishlist: () async {},
              onAddToCart: () {
                addCount++;
                return request.future;
              },
            ),
          ),
        ),
      ),
    );

    final addButton = find.byKey(const ValueKey('add-to-cart-gift-1'));
    await tester.tap(addButton);
    await tester.pump();

    expect(addCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(addButton).onPressed,
      isNull,
    );

    request.complete();
    await tester.pumpAndSettle();

    expect(addCount, 1);
    expect(
      tester.widget<IconButton>(addButton).onPressed,
      isNotNull,
    );
  });
}

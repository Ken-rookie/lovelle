import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/screens/checkout_screen.dart';
import 'package:giftly_customer/theme/app_theme.dart';
import 'package:giftly_customer/widgets/common.dart';

void main() {
  testWidgets('renders checkout details above the sticky order action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LovelleTheme.light,
        home: const CheckoutScreen(
          cart: [
            {
              'quantity': 1,
              'products': {
                'id': 'rose-1',
                'name': 'Lovelle Rose Gift',
                'price': 499,
                'is_rose_gift': true,
              },
            },
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('You’re almost there'), findsOneWidget);
    expect(find.text('How would you like to receive it?'), findsOneWidget);
    expect(find.text('Choose your rose style'), findsOneWidget);
    expect(find.text('Place order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('friendlyErrorMessage explains missing Supabase edge function fetch failures', () {
    final message = friendlyErrorMessage(
      'FunctionsFetchException: Failed to fetch, uri=https://example.supabase.co/functions/v1/paymongo, reasonPhrase: null',
    );

    expect(message, contains('Supabase Edge Function'));
    expect(message, contains('deployed'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/widgets/order_status_summary.dart';

void main() {
  testWidgets('shows clear order and PayMongo payment status details',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderStatusSummary(
            orderStatus: 'pending',
            paymentStatus: 'paid',
            paymentMethod: 'paymongo',
          ),
        ),
      ),
    );

    expect(find.text('ORDER STATUS'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      find.text('Your order has been received and is awaiting confirmation.'),
      findsOneWidget,
    );
    expect(find.text('PAYMENT'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(
      find.text('Payment received and confirmed. · PayMongo QRPH'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('explains cash-on-delivery payment timing', () {
    expect(
      paymentStatusDescription('pending', 'cash_on_delivery'),
      'Payment is due when your order arrives or is picked up.',
    );
  });

  test('shows shipped orders as in transit', () {
    expect(orderStatusLabel('shipped'), 'Shipped');
    expect(
      orderStatusDescription('shipped'),
      'Your order is on its way to the delivery address.',
    );
  });
}

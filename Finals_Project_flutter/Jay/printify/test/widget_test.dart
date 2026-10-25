// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:printify/main.dart';
import 'package:printify/models/print_file.dart';
import 'package:printify/screens/payment_screen.dart';
import 'package:printify/screens/order_summary_screen.dart';
import 'package:printify/screens/orders_screen.dart';
import 'package:printify/screens/upload_screen.dart';
import 'package:printify/models/print_order.dart';

void main() {
  testWidgets('Printify requires login before showing the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PrintifyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Log in to continue.'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Tapping a selected file opens its preview', (
    WidgetTester tester,
  ) async {
    var previewOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectedPrintFileTile(
            file: const PrintFileItem(
              name: 'assignment.pdf',
              bytes: 2048,
              extension: 'pdf',
            ),
            onPreview: () => previewOpened = true,
            onRemove: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));
    expect(previewOpened, isTrue);
  });

  testWidgets('Payment offers walk-in and PayMongo QRPh options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentScreen(
          orderId: 'order-id',
          orderNumber: 'PRT-123',
          amount: 125,
        ),
      ),
    );

    expect(find.text('Choose how you want to pay'), findsOneWidget);
    expect(find.text('Walk-in payment'), findsOneWidget);
    expect(find.text('PayMongo QRPh'), findsOneWidget);
    expect(find.text('₱125.00'), findsOneWidget);
  });

  testWidgets('Order summary explains both payment choices are next', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderSummaryScreen(
          draft: PrintOrderDraft(
            service: 'Documents',
            files: const [],
            paperSize: 'A4',
            orientation: 'Portrait',
            colorMode: 'Color',
            sides: 'Single-sided',
            paperType: 'Standard (80 gsm)',
            copies: 1,
            notes: '',
            subtotal: 3,
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Create order & choose payment'), findsOneWidget);
    expect(
      find.text(
        'After creating your order, choose walk-in payment or PayMongo QRPh.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Order card explains order and payment status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              OrderHistoryCard(
                order: {
                  'order_number': 'PRT-123',
                  'service_type': 'Documents',
                  'status': 'awaiting_payment',
                  'payment_status': 'unpaid',
                  'total': 1,
                  'copies': 1,
                  'paper_size': 'A4',
                  'orientation': 'Portrait',
                  'color_mode': 'Color',
                  'print_sides': 'Double-sided',
                  'paper_type': 'Premium (100 gsm)',
                  'notes': 'Staple the pages',
                  'print_order_files': [
                    {
                      'file_name': 'school-project.pdf',
                      'file_extension': 'pdf',
                      'file_size_bytes': 2048,
                      'page_count': 3,
                    },
                  ],
                  'created_at': DateTime(2026, 10, 25, 13).toIso8601String(),
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('PRT-123'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('Not paid'), findsOneWidget);
    expect(
      find.text('Payment is needed before the shop can start printing.'),
      findsOneWidget,
    );
    expect(find.text('₱1.00'), findsOneWidget);
    expect(find.text('1 copy'), findsOneWidget);
    expect(find.text('Oct 25, 2026 • 1:00 PM'), findsOneWidget);
    expect(find.text('Print job details'), findsOneWidget);
    await tester.tap(find.text('Print job details'));
    await tester.pumpAndSettle();

    expect(find.text('school-project.pdf'), findsOneWidget);
    expect(find.text('PDF • 2.0 KB • 3 pages'), findsOneWidget);
    expect(find.text('Paper size'), findsOneWidget);
    expect(find.text('A4'), findsOneWidget);
    expect(find.text('Double-sided'), findsOneWidget);
    expect(find.text('Staple the pages'), findsOneWidget);
  });

  testWidgets('QR payment status polls every five seconds without a spinner', (
    WidgetTester tester,
  ) async {
    var pollCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrPhPaymentDialog(
            orderId: 'order-id',
            orderNumber: 'PRT-123',
            amount: 125,
            qrImage:
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/nKsAAAAASUVORK5CYII=',
            statusLoader: () async {
              pollCount += 1;
              return 'paid';
            },
          ),
        ),
      ),
    );

    expect(find.text('Waiting for payment'), findsOneWidget);
    expect(pollCount, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(pollCount, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(pollCount, 1);
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

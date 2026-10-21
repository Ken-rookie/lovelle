import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftly_customer/widgets/common.dart';

void main() {
  testWidgets(
      'technical details expansion does not trigger tile paint assertion',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadErrorState(error: 'Example error'),
        ),
      ),
    );

    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();

    expect(find.text('Example error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

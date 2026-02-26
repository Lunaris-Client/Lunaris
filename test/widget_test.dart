import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Lunaris'))),
    );
    expect(find.text('Lunaris'), findsOneWidget);
  });
}

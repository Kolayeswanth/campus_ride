// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_ride/shared/widgets/auth_wrapper.dart';

void main() {
  testWidgets('AuthWrapper displays loading indicator initially', (WidgetTester tester) async {
    // Build our app with AuthWrapper and verify loading state
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthWrapper(),
      ),
    );

    // Verify that a loading indicator is shown
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

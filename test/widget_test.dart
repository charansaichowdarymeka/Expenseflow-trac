import 'package:flutter_test/flutter_test.dart';

import 'package:expensetracker/main.dart';

void main() {
  testWidgets('App boots and shows the dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}

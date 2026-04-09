import 'package:flutter_test/flutter_test.dart';

import 'package:rally_admin/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const RallyAdminApp());
    await tester.pumpAndSettle();

    // Verify login screen is shown
    expect(find.text('Rally Point Admin'), findsOneWidget);
  });
}

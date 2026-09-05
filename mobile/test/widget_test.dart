import 'package:flutter_test/flutter_test.dart';

import 'package:runit_maps/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RunItMapsApp());
    expect(find.text('RunIt Maps'), findsOneWidget);
  });
}

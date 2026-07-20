import 'package:flutter_test/flutter_test.dart';
import 'package:labbridge/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const LabBridgeApp());
    expect(find.byType(LabBridgeApp), findsOneWidget);
  });
}

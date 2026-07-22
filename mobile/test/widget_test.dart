import 'package:flutter_test/flutter_test.dart';
import 'package:cueflex/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CueFlexApp());
    expect(find.byType(CueFlexApp), findsOneWidget);
  });
}

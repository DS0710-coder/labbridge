// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/main.dart';
import 'package:mobile/services/db_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DbService().init();
  });

  testWidgets('App shell renders smoke test', (WidgetTester tester) async {
    // Build our app and wait for background FFI SQLite queries in real time.
    await tester.runAsync(() async {
      await tester.pumpWidget(const LabBridgeApp());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Verify that the LabBridge title or navigation bar is present.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

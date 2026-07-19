import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/organizer_provider.dart';
import 'package:mobile/providers/transfer_provider.dart';

void main() {
  testWidgets('LabBridgeApp renders structure', (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => OrganizerProvider()),
          ChangeNotifierProvider(create: (_) => TransferProvider()),
        ],
        child: const LabBridgeApp(),
      ),
    );

    expect(find.text('LabBridge Mobile'), findsOneWidget);
  });
}


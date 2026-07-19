import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/organizer_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => OrganizerProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
      ],
      child: const LabBridgeApp(),
    ),
  );
}

class LabBridgeApp extends StatelessWidget {
  const LabBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'LabBridge Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFF6C63FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF111118),
        ),
        fontFamily: 'sans-serif',
      ),
      home: auth.isAuthenticated ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/db_service.dart';
import 'services/transfer_service.dart';
import 'screens/home_screen.dart';
import 'screens/files_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService().init();
  runApp(const LabBridgeApp());
}

class LabBridgeApp extends StatelessWidget {
  const LabBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransferService()),
      ],
      child: MaterialApp(
        title: 'LabBridge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            surface: Color(0xFF111118),
          ),
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FilesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111118),
        indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Color(0xFF6B6B80)),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF6C63FF)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined, color: Color(0xFF6B6B80)),
            selectedIcon: Icon(Icons.folder_rounded, color: Color(0xFF6C63FF)),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Color(0xFF6B6B80)),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF6C63FF)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

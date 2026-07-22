import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/db_service.dart';
import 'services/transfer_service.dart';
import 'screens/home_screen.dart';
import 'screens/files_screen.dart';
import 'screens/settings_screen.dart';

class AppTheme {
  // Backgrounds
  static const bg         = Color(0xFF080810);   // near black, slightly blue
  static const surface    = Color(0xFF0F0F1A);   // card background
  static const surface2   = Color(0xFF151525);   // elevated card

  // Gradients (use as LinearGradient)
  static const gradPrimary = [Color(0xFF6C63FF), Color(0xFF9B8FFF)];  // indigo → lavender
  static const gradGreen   = [Color(0xFF22C55E), Color(0xFF16A34A)];  // success
  static const gradRed     = [Color(0xFFEF4444), Color(0xFFDC2626)];  // error
  static const gradOrange  = [Color(0xFFF97316), Color(0xFFEA580C)];  // warning
  static const gradBlue    = [Color(0xFF3B82F6), Color(0xFF2563EB)];  // info

  // Gradient borders
  static const borderGrad = [Color(0xFF2A2A4A), Color(0xFF1A1A30)]; // subtle dark gradient border

  // Text
  static const textPrimary   = Color(0xFFF0F0FF);  // near white, slightly blue
  static const textSecondary = Color(0xFF8080A0);  // muted
  static const textMuted     = Color(0xFF4A4A6A);  // very muted

  // Accent
  static const accent       = Color(0xFF6C63FF);
  static const accentGlow   = Color(0x336C63FF);  // for glow effects
}

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final List<Color> borderColors;
  final Color? backgroundColor;

  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.borderColors = AppTheme.borderGrad,
    this.backgroundColor = AppTheme.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderColors,
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius - 1),
        ),
        child: child,
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const IconBox({
    super.key,
    required this.icon,
    this.color = AppTheme.accent,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService().init();
  runApp(const CueFlexApp());
}

class CueFlexApp extends StatelessWidget {
  const CueFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransferService()),
      ],
      child: MaterialApp(
        title: 'CueFlex',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            surface: Color(0xFF0F0F1A),
            onSurface: Color(0xFFF0F0FF),
          ),
          scaffoldBackgroundColor: const Color(0xFF080810),
          useMaterial3: true,
          fontFamily: 'SF Pro Display',
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 88),
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                      _buildNavItem(1, Icons.folder_outlined, Icons.folder_rounded, 'Files'),
                      _buildNavItem(2, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.accent : AppTheme.textSecondary,
              size: 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

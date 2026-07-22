import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background & Surfaces (ContextL pure monochrome)
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF09090B);
  static const Color card = Color(0xFF121214);
  static const Color border = Color(0xFF27272A);
  static const Color borderHighlight = Color(0xFF3F3F46);

  // Brand & Accents
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFFE4E4E7);
  static const Color accent = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF97316);

  // Typography & Icons
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF52525B);

  // Folder Color Palette
  static const List<String> folderColorPalette = [
    '#6C63FF',
    '#22C55E',
    '#EF4444',
    '#F97316',
    '#3B82F6',
    '#A855F7',
    '#EC4899',
    '#F59E0B',
  ];

  static Color fromHex(String hexColor) {
    try {
      var hex = hexColor.replaceAll('#', '').trim();
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join('');
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      } else if (hex.length == 8) {
        // Already ARGB or RGBA. Assume ARGB format if 8 digits.
      } else {
        return const Color(0xFF6C63FF); // Fallback color
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }
}

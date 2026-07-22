import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/transfer_service.dart';
import '../main.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasNavigated = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasNavigated || _isProcessing) return;
    _isProcessing = true;

    try {
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value == null) continue;

        String? sessionId;
        int? expiry;

        try {
          // Try parsing as JSON first: {"s":"abc...","e":...}
          final data = json.decode(value) as Map<String, dynamic>;
          sessionId = data['s'] as String?;
          expiry = data['e'] as int?;
        } catch (_) {
          // Try parsing as URL: https://.../phone.html?s=abc...&e=...
          final uri = Uri.tryParse(value);
          if (uri != null && uri.queryParameters.containsKey('s')) {
            sessionId = uri.queryParameters['s'];
            final expiryStr = uri.queryParameters['e'];
            if (expiryStr != null) {
              expiry = int.tryParse(expiryStr);
            }
          }
        }

        if (sessionId == null) continue;

        if (expiry != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now > expiry) {
            _showError('QR has expired, refresh the PC page');
            return;
          }
        }

        // Valid QR - connect and navigate back to dashboard
        _hasNavigated = true;
        await _connectAndReturn(sessionId);
        return;
      }
    } finally {
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(seconds: 2));
        _isProcessing = false;
      }
    }
  }

  Future<void> _connectAndReturn(String sessionId) async {
    final transferService = Provider.of<TransferService>(context, listen: false);
    await transferService.connect(sessionId);
    
    if (!mounted) return;
    
    if (transferService.currentStatus == ConnectionStatus.connected) {
      Navigator.of(context).pop();
    } else {
      _hasNavigated = false;
      _showError('Failed to connect to session');
    }
  }

  int _lastErrorTime = 0;

  void _showError(String message) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastErrorTime < 2000) return;
    _lastErrorTime = now;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GradientCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  IconBox(icon: Icons.keyboard_rounded, size: 40, iconSize: 20),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Session ID',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter session ID for connection',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. lb_session_abc123',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: AppTheme.gradPrimary),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final id = controller.text.trim();
                          if (id.isNotEmpty) {
                            Navigator.pop(context);
                            await _connectAndReturn(id);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          child: Text(
                            'Connect',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout using ColorFiltered or custom Stack overlays
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.65),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.black),
                  ),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Glowing scan frame & sweeping laser
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // Gradient border
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        width: 2.5,
                        color: AppTheme.accent,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Sweeping laser line
                  Animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                    effects: [
                      SlideEffect(
                        begin: const Offset(0, 0),
                        end: const Offset(0, 240 / 2),
                        duration: 1800.ms,
                        curve: Curves.easeInOut,
                      ),
                    ],
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.accent,
                            Color(0xFF9B8FFF),
                            AppTheme.accent,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Corner indicators
                  ..._buildCornerIndicators(),
                ],
              ),
            ),
          ),

          // Top glassmorphic bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: AppTheme.bg.withValues(alpha: 0.5),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    bottom: 14,
                    left: 16,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      // Back pill button
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20),
                          tooltip: 'Back',
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan QR Code',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Flash / torch toggle pill button
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        child: IconButton(
                          onPressed: () => _scannerController.toggleTorch(),
                          icon: const Icon(Icons.flash_on_rounded, color: AppTheme.accent, size: 20),
                          tooltip: 'Toggle Flash',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom glassmorphic overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: AppTheme.bg.withValues(alpha: 0.65),
                  padding: EdgeInsets.only(
                    top: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Point your camera at the QR code displayed on the desktop browser at contextl-web.vercel.app',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Manual entry pill button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFF1E1E2E)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: _showManualEntry,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.keyboard_rounded, color: AppTheme.accent, size: 18),
                                      SizedBox(width: 10),
                                      Text(
                                        'Enter Session ID Manually',
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).scale(),
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

  List<Widget> _buildCornerIndicators() {
    const double size = 26;
    const double stroke = 4;
    const color = AppTheme.accent;

    return [
      // Top-left corner
      Positioned(
        top: -1,
        left: -1,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: stroke),
              left: BorderSide(color: color, width: stroke),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        top: -1,
        right: -1,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: stroke),
              right: BorderSide(color: color, width: stroke),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: -1,
        left: -1,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: stroke),
              left: BorderSide(color: color, width: stroke),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        bottom: -1,
        right: -1,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: stroke),
              right: BorderSide(color: color, width: stroke),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
          ),
        ),
      ),
    ];
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasNavigated = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasNavigated) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;

      try {
        final data = json.decode(value) as Map<String, dynamic>;
        final sessionId = data['s'] as String?;
        final expiry = data['e'] as int?;

        if (sessionId == null || expiry == null) continue;

        // Check expiry (expiry is stored as milliseconds epoch)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > expiry) {
          _showError('QR has expired, refresh the PC page');
          return;
        }

        // Valid QR - connect and navigate back to dashboard
        _hasNavigated = true;
        final transferService = Provider.of<TransferService>(context, listen: false);
        await transferService.connect(sessionId, AppConfig.workerWsUrl);
        if (transferService.currentStatus == ConnectionStatus.connected) {
          final allFolders = await DbService().getAllFolders();
          transferService.sendFolderTree(allFolders);
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      } catch (_) {
        // Not a valid LabBridge QR, ignore
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Manual Session ID',
          style: TextStyle(color: Color(0xFFE8E8F0)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter session ID for emulator testing',
              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFE8E8F0)),
              decoration: InputDecoration(
                hintText: 'Session ID',
                hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(context);
                _hasNavigated = true;
                final transferService = Provider.of<TransferService>(this.context, listen: false);
                await transferService.connect(id, AppConfig.workerWsUrl);
                if (transferService.currentStatus == ConnectionStatus.connected) {
                  final allFolders = await DbService().getAllFolders();
                  transferService.sendFolderTree(allFolders);
                }
                if (!mounted) return;
                Navigator.of(this.context).pop();
              }
            },
            child: const Text('Connect', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0F).withValues(alpha: 0.3),
            ),
          ),

          // Scan frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0A0A0F).withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),
          ),

          // Bottom hint and manual entry
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Point your camera at the QR code\non the PC browser',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _showManualEntry,
                      child: const Text(
                        'Enter Session ID Manually',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

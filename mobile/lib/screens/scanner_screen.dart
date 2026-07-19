import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/organizer_provider.dart';
import '../models/transfer_task.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final rawValue = barcodes.first.rawValue!;
    if (!rawValue.contains('session_id') || !rawValue.contains('pairing_token')) return;

    setState(() => _isProcessing = true);
    final transfer = Provider.of<TransferProvider>(context, listen: false);
    final organizer = Provider.of<OrganizerProvider>(context, listen: false);

    final success = await transfer.pairWithQR(rawValue, organizer: organizer);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paired successfully with Lab PC!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  void _showManualDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Manual QR Payload Entry', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            hintText: '{"session_id": "...", "pairing_token": "..."}',
            hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
            filled: true,
            fillColor: const Color(0xFF0A0A0F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final transfer = Provider.of<TransferProvider>(context, listen: false);
              final organizer = Provider.of<OrganizerProvider>(context, listen: false);
              await transfer.pairWithQR(controller.text.trim(), organizer: organizer);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Pair Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transfer = Provider.of<TransferProvider>(context);
    final task = transfer.currentTask;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'PC QR Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _showManualDialog,
            icon: const Icon(Icons.keyboard_alt_outlined, color: Color(0xFF6C63FF)),
            tooltip: 'Manual JSON / Token Entry',
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Paired Badge or Error Banner
          if (transfer.errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transfer.errorMessage!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          if (transfer.isPaired) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF22C55E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paired with Lab PC Session',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Session: ${transfer.activeSessionId?.substring(0, 8)}...',
                          style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: transfer.disconnectSession,
                    icon: const Icon(Icons.link_off, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Unpair', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Active Transfer Task Card
          if (task != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6C63FF).withOpacity(0.15), const Color(0xFF111118)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.file_present_rounded, color: Color(0xFF6C63FF), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            task.filename,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: task.status == TransferTaskStatus.completed
                              ? const Color(0xFF22C55E).withOpacity(0.2)
                              : const Color(0xFF6C63FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          task.status == TransferTaskStatus.completed
                              ? 'Saved to Organizer!'
                              : 'Receiving (${task.percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: task.status == TransferTaskStatus.completed
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF6C63FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: task.totalChunks > 0 ? task.receivedChunks / task.totalChunks : 0,
                      backgroundColor: const Color(0xFF1E1E2E),
                      color: task.status == TransferTaskStatus.completed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF6C63FF),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chunk: ${task.receivedChunks} / ${task.totalChunks}',
                        style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 11, fontFamily: 'monospace'),
                      ),
                      if (task.savedPath != null)
                        Text(
                          'Encrypted RAM -> Local SQLite',
                          style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Camera Viewport
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E1E2E), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleDetect,
                  ),
                  // Scanner Overlay Box
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF6C63FF), width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Point camera at labbridge.app on lab computer to transfer instantly.',
              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

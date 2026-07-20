import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../core/formatters.dart';
import '../models/file_item.dart';
import '../models/folder.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';
import 'scanner_screen.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DbService _dbService = DbService();
  StreamSubscription<String>? _completionSub;
  List<FileItem> _recentFiles = [];
  List<Folder> _folders = [];
  int _storageUsed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final transferService = Provider.of<TransferService>(context, listen: false);
      _completionSub = transferService.completions.listen((_) {
        if (mounted) _loadData();
      });
    });
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final files = await _dbService.getRecentFiles(5);
    final storage = await _dbService.getStorageUsed();
    final folders = await _dbService.getAllFolders();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _storageUsed = storage;
        _folders = folders;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              )
            : RefreshIndicator(
                color: const Color(0xFF6C63FF),
                backgroundColor: const Color(0xFF111118),
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 12),
                    // Header
                    const Text(
                      'LabBridge',
                      style: TextStyle(
                        color: Color(0xFFE8E8F0),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Transfer files between phone & PC',
                      style: TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dynamic CTA Section (Connected vs Disconnected)
                    Consumer<TransferService>(
                      builder: (context, transferService, child) {
                        final isConnected = transferService.currentStatus == ConnectionStatus.connected ||
                            transferService.currentStatus == ConnectionStatus.connecting;

                        if (isConnected) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Connected on top
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, color: Color(0xFF22C55E), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transferService.currentStatus == ConnectionStatus.connecting
                                                ? 'Connecting to PC...'
                                                : 'Connected to PC Browser',
                                            style: const TextStyle(
                                              color: Color(0xFF22C55E),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Text(
                                            'Active session ready for file transfer',
                                            style: TextStyle(
                                              color: Color(0xFF6B6B80),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => transferService.disconnect(),
                                      icon: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444)),
                                      tooltip: 'Disconnect',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Send button under it
                              _buildPrimaryButton(
                                icon: Icons.upload_file_rounded,
                                label: 'Transfer Files to PC',
                                onTap: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final result = await FilePicker.pickFiles(allowMultiple: true);
                                  if (result != null && result.files.isNotEmpty) {
                                    for (final f in result.files) {
                                      if (f.path != null) {
                                        try {
                                          await transferService.sendFile(File(f.path!));
                                        } catch (e) {
                                          messenger.showSnackBar(SnackBar(
                                            content: Text('Failed to send ${f.name}: $e'),
                                            backgroundColor: const Color(0xFFEF4444),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ));
                                        }
                                      }
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Active transfer/progress display right under the button
                              StreamBuilder<TransferProgress?>(
                                stream: transferService.progress,
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                                  final prog = snapshot.data!;
                                  if (prog.progress >= 1.0 || (prog.totalChunks > 0 && prog.completedChunks >= prog.totalChunks)) {
                                    return const SizedBox.shrink();
                                  }
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF111118),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFF1E1E2E)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                prog.fileName,
                                                style: const TextStyle(color: Color(0xFFE8E8F0), fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              prog.percentage,
                                              style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: prog.progress,
                                          backgroundColor: const Color(0xFF1E1E2E),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // File structure under it
                              const Text(
                                'Target Folder Structure',
                                style: TextStyle(
                                  color: Color(0xFFE8E8F0),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111118),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF1E1E2E)),
                                ),
                                child: Column(
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.folder_shared_rounded, color: Color(0xFF6C63FF), size: 20),
                                        SizedBox(width: 8),
                                        Text('Root (Default)', style: TextStyle(color: Color(0xFFE8E8F0), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    if (_folders.isNotEmpty) ...[
                                      const Divider(color: Color(0xFF1E1E2E), height: 20),
                                      ..._folders.map((f) => Padding(
                                            padding: const EdgeInsets.only(left: 16, bottom: 6),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.folder_outlined, color: Color(0xFF6B6B80), size: 18),
                                                const SizedBox(width: 8),
                                                Text(f.name, style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13)),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Disconnected State
                        return Column(
                          children: [
                            _buildPrimaryButton(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Scan QR to Receive',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ScannerScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildSecondaryButton(
                                icon: Icons.upload_file_rounded,
                                label: 'Send File to PC',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const TransferScreen(
                                        sessionId: null,
                                        sendMode: true,
                                      ),
                                    ),
                                  );
                                },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 36),

                    // Recent Files Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Files',
                          style: TextStyle(
                            color: Color(0xFFE8E8F0),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_recentFiles.length} files',
                          style: const TextStyle(
                            color: Color(0xFF6B6B80),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_recentFiles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111118),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              color: Color(0xFF6B6B80),
                              size: 40,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No files yet',
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Scan a QR code to receive files',
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_recentFiles.length, (index) {
                        return _buildRecentFileTile(_recentFiles[index]);
                      }),

                    const SizedBox(height: 32),

                    // Storage stat
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111118),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E1E2E)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storage_rounded,
                              color: Color(0xFF6C63FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Storage Used',
                                style: TextStyle(
                                  color: Color(0xFF6B6B80),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatStorage(_storageUsed),
                                style: const TextStyle(
                                  color: Color(0xFFE8E8F0),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF6C63FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E1E2E), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileTile(FileItem file) {
    final dateStr = DateFormat('MMM d').format(
      DateTime.fromMillisecondsSinceEpoch(file.receivedAt),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            OpenFile.open(file.localPath);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E1E2E)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_rounded,
                  color: Color(0xFF6C63FF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(
                      color: Color(0xFFE8E8F0),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${file.formattedSize} · $dateStr',
                  style: const TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

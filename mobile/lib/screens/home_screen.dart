import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

import '../models/file_item.dart';
import '../services/db_service.dart';
import 'scanner_screen.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DbService _dbService = DbService();
  List<FileItem> _recentFiles = [];
  int _storageUsed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final files = await _dbService.getRecentFiles(5);
    final storage = await _dbService.getStorageUsed();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _storageUsed = storage;
        _loading = false;
      });
    }
  }

  String _formatStorage(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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

                    // Primary CTA - Scan QR
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

                    // Secondary CTA - Send File
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
                                _formatStorage(_storageUsed),
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

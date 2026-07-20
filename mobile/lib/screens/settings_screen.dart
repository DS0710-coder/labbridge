import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../core/config.dart';
import '../core/formatters.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DbService _dbService = DbService();
  final TextEditingController _urlController = TextEditingController();

  int _filesCount = 0;
  int _foldersCount = 0;
  int _storageUsed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWorkerUrl();
  }

  Future<void> _loadWorkerUrl() async {
    final url = await AppConfig.getWorkerUrl();
    if (mounted) {
      setState(() => _urlController.text = url);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final files = await _dbService.getFilesCount();
    final folders = await _dbService.getFoldersCount();
    final storage = await _dbService.getStorageUsed();

    if (mounted) {
      setState(() {
        _filesCount = files;
        _foldersCount = folders;
        _storageUsed = storage;
        _loading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All Data?',
          style: TextStyle(color: Color(0xFFE8E8F0)),
        ),
        content: const Text(
          'This will delete all files, folders, and transfer history. Default folders will be recreated. This cannot be undone.',
          style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.clearAllData();
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All data cleared'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Color(0xFFE8E8F0),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Worker URL
                  _buildSectionTitle('Worker URL'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Color(0xFFE8E8F0), fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'wss://labbridge-worker.YOUR_SUBDOMAIN.workers.dev',
                      hintStyle: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF111118),
                      prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF6C63FF), size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        final url = _urlController.text.trim();
                        if (url.isEmpty) return;
                        await AppConfig.setWorkerUrl(url);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Worker URL saved'),
                            backgroundColor: const Color(0xFF22C55E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Save URL',
                        style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Storage Statistics
                  _buildSectionTitle('Storage'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Files', '$_filesCount', Icons.insert_drive_file_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard('Folders', '$_foldersCount', Icons.folder_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard('Size', Formatters.formatStorage(_storageUsed), Icons.storage_rounded)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Danger Zone
                  _buildSectionTitle('Danger Zone'),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _clearAllData,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                color: Color(0xFFEF4444), size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Clear All Data',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // About
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'LabBridge v2',
                          style: TextStyle(
                            color: Color(0xFF6B6B80),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Secure file transfer for students',
                          style: TextStyle(
                            color: const Color(0xFF6B6B80).withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version 2.0.0',
                          style: TextStyle(
                            color: const Color(0xFF6B6B80).withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF6B6B80),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8E8F0),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

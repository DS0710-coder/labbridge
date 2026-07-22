import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/db_service.dart';
import '../core/config.dart';
import '../core/formatters.dart';
import '../main.dart';

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
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text(
          'CLEAR ALL DATA?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
        ),
        content: const Text(
          'This will delete all files, folders, and transfer history. Default folders will be recreated. This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR ALL', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.clearAllData();
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared', style: TextStyle(fontFamily: 'monospace')),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchGithub() async {
    final uri = Uri.parse('https://github.com/DS0710-coder');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.textPrimary),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    '> SYSTEM_CONFIG',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFamily: 'monospace',
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('CLOUD RELAY CONFIGURATION'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      border: Border.all(color: const Color(0xFF27272A), width: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            IconBox(icon: Icons.cloud_sync_outlined, size: 36, iconSize: 18),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cloudflare Worker URL',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Signaling relay for WebSockets',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _urlController,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            hintText: 'wss://cueflux.YOUR_SUBDOMAIN.workers.dev',
                            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace'),
                            filled: true,
                            fillColor: Color(0xFF121214),
                            prefixIcon: Icon(Icons.link, color: AppTheme.textPrimary, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF27272A)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final url = _urlController.text.trim();
                                if (url.isEmpty) return;
                                await AppConfig.setWorkerUrl(url);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Worker URL saved successfully', style: TextStyle(fontFamily: 'monospace')),
                                    backgroundColor: Color(0xFF22C55E),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'SAVE CONFIGURATION',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                  const SizedBox(height: 28),

                  _buildSectionTitle('STORAGE & CACHE'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'FILES',
                          '$_filesCount',
                          Icons.article_outlined,
                        ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'FOLDERS',
                          '$_foldersCount',
                          Icons.folder_outlined,
                        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'STORAGE',
                          Formatters.formatStorage(_storageUsed),
                          Icons.storage_outlined,
                        ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.05),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  _buildSectionTitle('DANGER ZONE'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF121214),
                                border: Border.all(color: const Color(0xFFEF4444)),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CLEAR ALL APP DATA',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Wipes local database and history',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This action permanently deletes all stored files, folders, and transfer history from this device.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _clearAllData,
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('CLEAR ALL DATA', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF121214),
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                  const SizedBox(height: 36),

                  // About & Credits Section (ContextL monochrome + Made By link)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      border: Border.all(color: const Color(0xFF27272A), width: 1),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF121214),
                              border: Border.all(color: const Color(0xFF27272A)),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Text('CF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const SizedBox(height: 14),
                          const Text(
                            'CUEFLEX',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Deterministic Local Relay · Zero Cloud Storage',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121214),
                              border: Border.all(color: const Color(0xFF27272A)),
                            ),
                            child: const Text(
                              'ContextL Architecture · v2.0.0',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: _launchGithub,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                border: Border.all(color: const Color(0xFFFFFFFF)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.code, color: Colors.black, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'MADE BY DS0710-CODER',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms).scale(begin: const Offset(0.98, 0.98)),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      '> $title',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          IconBox(icon: icon, size: 36, iconSize: 18),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

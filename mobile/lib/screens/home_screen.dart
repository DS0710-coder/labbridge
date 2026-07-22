import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/formatters.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';
import 'scanner_screen.dart';
import 'transfer_screen.dart';
import '../widgets/file_tile.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final DbService _dbService = DbService();
  StreamSubscription<String>? _completionSub;
  List<FileItem> _recentFiles = [];
  int _storageUsed = 0;
  bool _loading = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

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
    _pulseController.dispose();
    _completionSub?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : RefreshIndicator(
                color: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                onRefresh: _loadData,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Header section edge-to-edge
                    ClipRect(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF080810), Color(0xFF0F0F1A)],
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 26),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Row(
                                          children: [
                                            Text(
                                              '✦ LabBridge',
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Transfer files between phone & PC',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: -40,
                            right: -40,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [Color(0x336C63FF), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dynamic CTA Section (Connected vs Disconnected)
                          Consumer<TransferService>(
                            builder: (context, transferService, child) {
                              final isConnected = transferService.currentStatus == ConnectionStatus.connected ||
                                  transferService.currentStatus == ConnectionStatus.connecting;

                              if (isConnected) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Connected State Card
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x4022C55E),
                                            blurRadius: 20,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(1.5),
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(18.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF22C55E),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    transferService.currentStatus == ConnectionStatus.connecting
                                                        ? 'Connecting to PC Browser...'
                                                        : 'Connected to PC Browser',
                                                    style: const TextStyle(
                                                      color: Color(0xFF22C55E),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Active session · Ready to transfer',
                                                    style: TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () => transferService.disconnect(),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  '✕ End',
                                                  style: TextStyle(
                                                    color: Color(0xFFEF4444),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
                                    const SizedBox(height: 16),

                                    // Send button when connected
                                    _buildPrimaryButton(
                                      title: 'Transfer Files to PC',
                                      subtitle: 'Select documents, images or code to send',
                                      icon: Icons.upload_file_rounded,
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
                                                ));
                                              }
                                            }
                                          }
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Active transfer/progress display
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
                                            color: AppTheme.surface,
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(colors: AppTheme.borderGrad),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surface,
                                              borderRadius: BorderRadius.circular(19),
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
                                                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      prog.percentage,
                                                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                LinearProgressIndicator(
                                                  value: prog.progress,
                                                  backgroundColor: AppTheme.surface2,
                                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }

                              // Disconnected State
                              return Column(
                                children: [
                                  // Primary CTA Button (Scan QR) with pulse ring
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.accent.withValues(alpha: 0.35 + (0.15 * _pulseController.value)),
                                              blurRadius: 24,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: _buildPrimaryButton(
                                      title: 'Scan QR to Receive',
                                      subtitle: 'Open camera · Connect to PC',
                                      icon: Icons.qr_code_scanner_rounded,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const ScannerScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                                  const SizedBox(height: 16),
                                  // Secondary CTA Button (Send File)
                                  _buildSecondaryButton(
                                    title: 'Send File to PC',
                                    icon: Icons.upload_file_rounded,
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
                                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 36),

                          // Recent Files Section header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Files',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${_recentFiles.length} files',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 16),
                                ],
                              ),
                            ],
                          ).animate().fadeIn(delay: 250.ms),
                        ],
                      ),
                    ),

                    // Recent file tiles
                    if (_recentFiles.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(colors: AppTheme.borderGrad),
                        ),
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                color: AppTheme.textMuted,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No recent files',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Received files will appear here',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms)
                    else
                      ..._recentFiles.asMap().entries.map((entry) {
                        final i = entry.key;
                        final file = entry.value;
                        return FileTile(
                          file: file,
                          onTap: () => OpenFile.open(file.localPath),
                        ).animate(delay: (50 * i).ms).fadeIn().slideY(begin: 0.05);
                      }),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppTheme.borderGrad,
                          ),
                        ),
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.accent.withValues(alpha: 0.3),
                                          AppTheme.accent.withValues(alpha: 0.1)
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.storage_rounded,
                                      color: AppTheme.accent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '💾 Storage Used',
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          Formatters.formatStorage(_storageUsed),
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: AppTheme.gradPrimary,
                                    ).createShader(bounds),
                                    child: LinearProgressIndicator(
                                      value: (_storageUsed / (1024 * 1024 * 500)).clamp(0.05, 1.0),
                                      backgroundColor: Colors.transparent,
                                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 350.ms),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: AppTheme.gradPrimary,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: AppTheme.borderGrad,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(18.5),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

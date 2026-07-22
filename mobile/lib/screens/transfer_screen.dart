import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/folder.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';
import '../widgets/transfer_progress.dart';
import '../main.dart';
import 'scanner_screen.dart';

class TransferScreen extends StatefulWidget {
  final String? sessionId;
  final bool sendMode;

  const TransferScreen({
    super.key,
    required this.sessionId,
    this.sendMode = false,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final DbService _dbService = DbService();
  late final TransferService _transferService;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  TransferProgress? _currentProgress;
  List<Folder> _currentFolderChildren = [];
  List<Folder> _folderBreadcrumbs = [];
  final List<String> _completedFiles = [];
  String? _error;
  double _speed = 0;

  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<TransferProgress?>? _progressSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _completionSub;

  @override
  void initState() {
    super.initState();
    _transferService = context.read<TransferService>();
    _init();
  }

  Future<void> _init() async {
    // Set up listeners
    _statusSub = _transferService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() => _connectionStatus = status);
      }
    });

    _progressSub = _transferService.progress.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
          _speed = _transferService.getTransferSpeed();
        });
      }
    });

    _errorSub = _transferService.errors.listen((error) {
      if (mounted) {
        setState(() => _error = error);
      }
    });

    _completionSub = _transferService.completions.listen((fileName) {
      if (mounted) {
        setState(() {
          _completedFiles.add(fileName);
          _currentProgress = null;
        });
      }
    });

    // Auto-connect if session ID provided
    if (widget.sessionId != null) {
      await _connect();
    }
    await _loadFolderChildren(null);
  }

  Future<void> _loadFolderChildren(String? parentId) async {
    final children = await _dbService.getChildFolders(parentId);
    if (mounted) {
      setState(() {
        _currentFolderChildren = children;
        _transferService.setTargetFolder(parentId);
      });
    }
  }

  Future<void> _connect() async {
    if (widget.sessionId == null) return;

    setState(() {
      _error = null;
      _connectionStatus = ConnectionStatus.connecting;
    });

    await _transferService.connect(widget.sessionId!);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);
    await _transferService.sendFile(file);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _progressSub?.cancel();
    _errorSub?.cancel();
    _completionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionStatus == ConnectionStatus.connected;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text(
          'Transfer',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          if (isConnected)
            IconButton(
              onPressed: () async {
                await _transferService.disconnect();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Connection status pill banner
            _buildConnectionStatus().animate().fadeIn().slideY(begin: -0.1),
            const SizedBox(height: 20),

            // Error message banner
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 16),
            ],

            // Folder selector inside GradientCard
            if (isConnected) ...[
              GradientCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder_shared_rounded, color: AppTheme.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Save Location',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFolderSelector(),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
              const SizedBox(height: 20),
            ],

            // Active transfer progress inside GradientCard
            if (_currentProgress != null) ...[
              GradientCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync_rounded, color: AppTheme.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Active Transfer',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TransferProgressWidget(
                      transferProgress: _currentProgress!,
                      speed: _speed,
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 20),
            ],

            // Send file button (Gradient Button)
            if (widget.sendMode && isConnected && _currentProgress == null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: AppTheme.gradPrimary),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickAndSendFile,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Pick File to Send',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms).scale(),
              const SizedBox(height: 24),
            ],

            // Empty state when connected and no active/completed transfers
            if (isConnected && _currentProgress == null && _completedFiles.isEmpty && !widget.sendMode) ...[
              GradientCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.accent, size: 36),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ready for Transfer',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Drop files on your PC browser to instantly transfer them here, or pick a file to send.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(colors: AppTheme.gradPrimary),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickAndSendFile,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Send a File',
                                  style: TextStyle(
                                    color: Colors.white,
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
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).scale(),
            ],

            // Completed transfers list inside GradientCards
            if (_completedFiles.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Completed Transfers (${_completedFiles.length})',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 12),
              ..._completedFiles.asMap().entries.map((entry) {
                final idx = entry.key;
                final name = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GradientCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Received successfully',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: (40 * idx).ms).fadeIn().slideX(begin: 0.05),
                );
              }),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Stay connected for more files',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            // Disconnected clean empty state (when not connected and no session)
            if (widget.sessionId == null && !widget.sendMode && !isConnected) ...[
              GradientCard(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.accent, size: 38),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Active Session',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Scan the QR code displayed on your desktop or browser at contextl-web.vercel.app to link devices.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: AppTheme.gradPrimary),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScannerScreen()),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Scan QR Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).scale(),
            ],

            const SizedBox(height: 32),

            // Disconnect button
            if (isConnected)
              OutlinedButton.icon(
                onPressed: () async {
                  await _transferService.disconnect();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect from PC'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    IconData icon;
    String label;
    Color color;

    switch (_connectionStatus) {
      case ConnectionStatus.connected:
        icon = Icons.link_rounded;
        label = 'Connected to PC browser';
        color = const Color(0xFF22C55E);
        break;
      case ConnectionStatus.connecting:
        icon = Icons.sync_rounded;
        label = 'Connecting...';
        color = const Color(0xFFF59E0B);
        break;
      case ConnectionStatus.error:
        icon = Icons.error_rounded;
        label = 'Connection error';
        color = const Color(0xFFEF4444);
        break;
      case ConnectionStatus.disconnected:
        icon = Icons.link_off_rounded;
        label = 'Disconnected';
        color = AppTheme.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 800.ms),
          const SizedBox(width: 14),
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_connectionStatus == ConnectionStatus.connecting)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _folderBreadcrumbs = []);
                    _loadFolderChildren(null);
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.home_rounded,
                        size: 15,
                        color: _folderBreadcrumbs.isEmpty ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Root',
                        style: TextStyle(
                          color: _folderBreadcrumbs.isEmpty
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: _folderBreadcrumbs.isEmpty ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._folderBreadcrumbs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final crumb = entry.value;
                  final isLast = i == _folderBreadcrumbs.length - 1;
                  return Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textMuted, size: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _folderBreadcrumbs = _folderBreadcrumbs.sublist(0, i + 1);
                          });
                          _loadFolderChildren(crumb.id);
                        },
                        child: Text(
                          crumb.name,
                          style: TextStyle(
                            color: isLast
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Current save location indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.save_rounded, color: AppTheme.accent, size: 16),
              const SizedBox(width: 10),
              Text(
                _folderBreadcrumbs.isEmpty
                    ? 'Saving to: Root'
                    : 'Saving to: ${_folderBreadcrumbs.last.name}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Folder list
        if (_currentFolderChildren.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'No subfolders inside this directory — incoming files will save right here.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentFolderChildren.map((folder) {
              final folderColor = Color(
                int.parse('FF${folder.color.replaceAll('#', '')}', radix: 16),
              );
              return GestureDetector(
                onTap: () {
                  setState(() => _folderBreadcrumbs.add(folder));
                  _loadFolderChildren(folder.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E1E28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_rounded, color: folderColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        folder.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary, size: 16),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

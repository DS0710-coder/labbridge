import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/folder.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';
import '../widgets/transfer_progress.dart';

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
  List<Folder> _folders = [];
  String? _selectedFolderId;
  final List<String> _completedFiles = [];
  String? _error;
  double _speed = 0;

  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _completionSub;

  @override
  void initState() {
    super.initState();
    _transferService = context.read<TransferService>();
    _init();
  }

  Future<void> _init() async {
    // Load folders
    _folders = await _dbService.getAllFolders();
    if (mounted) setState(() {});

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
  }

  Future<void> _connect() async {
    if (widget.sessionId == null) return;

    setState(() {
      _error = null;
      _connectionStatus = ConnectionStatus.connecting;
    });

    // Get worker URL from settings (for now, use default)
    const workerUrl = 'ws://10.0.2.2:8787';
    await _transferService.connect(widget.sessionId!, workerUrl);

    // Send folder tree to PC
    if (_transferService.currentStatus == ConnectionStatus.connected) {
      _transferService.sendFolderTree(_folders);
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);
    await _transferService.sendFile(file, widget.sessionId ?? '');
  }

  void _selectFolder(Folder? folder) {
    setState(() {
      _selectedFolderId = folder?.id;
    });
    _transferService.setTargetFolder(folder?.id);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: const Color(0xFFE8E8F0),
        elevation: 0,
        title: const Text(
          'Transfer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_connectionStatus == ConnectionStatus.connected)
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
            // Connection status
            _buildConnectionStatus(),
            const SizedBox(height: 20),

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Folder selector
            if (_connectionStatus == ConnectionStatus.connected) ...[
              const Text(
                'Save to Folder',
                style: TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _buildFolderSelector(),
              const SizedBox(height: 24),
            ],

            // Transfer progress
            if (_currentProgress != null) ...[
              TransferProgressWidget(
                transferProgress: _currentProgress!,
                speed: _speed,
              ),
              const SizedBox(height: 16),
            ],

            // Send file button
            if (widget.sendMode &&
                _connectionStatus == ConnectionStatus.connected &&
                _currentProgress == null) ...[
              Material(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickAndSendFile,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Pick File to Send',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Completed files
            if (_completedFiles.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_completedFiles.length} file${_completedFiles.length == 1 ? '' : 's'} completed',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._completedFiles.map((name) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111118),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E1E2E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_rounded,
                            color: Color(0xFF22C55E), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFFE8E8F0),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Stay connected for more files',
                style: TextStyle(
                  color: Color(0xFF6B6B80),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Manual connect (for send mode without session)
            if (widget.sessionId == null && !widget.sendMode) ...[
              const Center(
                child: Text(
                  'Scan a QR code first to connect',
                  style: TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Disconnect button
            if (_connectionStatus == ConnectionStatus.connected)
              OutlinedButton.icon(
                onPressed: () async {
                  await _transferService.disconnect();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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
        color = const Color(0xFF6B6B80);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedFolderId,
          isExpanded: true,
          dropdownColor: const Color(0xFF111118),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B6B80)),
          hint: const Text(
            'Root (no folder)',
            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 14),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Root (no folder)',
                style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 14),
              ),
            ),
            ..._folders.map((f) => DropdownMenuItem<String?>(
                  value: f.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        color: Color(
                          int.parse('FF${f.color.replaceAll('#', '')}', radix: 16),
                        ),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            color: Color(0xFFE8E8F0),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          onChanged: (folderId) {
            final folder = folderId == null
                ? null
                : _folders.firstWhere((f) => f.id == folderId);
            _selectFolder(folder);
          },
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer_task.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/crypto_service.dart';
import '../services/ws_service.dart';
import 'organizer_provider.dart';

class TransferProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final CryptoService _crypto = CryptoService();
  final _uuid = const Uuid();

  String? _activeSessionId;
  String? _activePairingToken;
  SecretKey? _secretKey;
  bool _isPaired = false;
  String? _errorMessage;
  String? _defaultTargetFolderId;

  WsService? _wsService;
  TransferTask? _currentTask;
  final List<TransferTask> _history = [];

  bool get isPaired => _isPaired;
  String? get activeSessionId => _activeSessionId;
  String? get activePairingToken => _activePairingToken;
  String? get errorMessage => _errorMessage;
  TransferTask? get currentTask => _currentTask;
  List<TransferTask> get history => _history;

  void setDefaultFolder(String? folderId) {
    _defaultTargetFolderId = folderId;
    notifyListeners();
  }

  Future<bool> pairWithQR(String qrJsonString, {OrganizerProvider? organizer}) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> payload = jsonDecode(qrJsonString);
      final sessionId = payload['session_id'] as String?;
      final pairingToken = payload['pairing_token'] as String?;

      if (sessionId == null || pairingToken == null) {
        throw Exception('Invalid LabBridge QR code format');
      }

      await _api.pairWithSession(sessionId, pairingToken);

      _activeSessionId = sessionId;
      _activePairingToken = pairingToken;
      _secretKey = await _crypto.deriveKeyFromPairingToken(pairingToken);
      _isPaired = true;

      _initWs(sessionId, organizer);
      notifyListeners();
      return true;
    } catch (err) {
      _errorMessage = err.toString().replaceAll('Exception: ', '');
      _isPaired = false;
      notifyListeners();
      return false;
    }
  }

  void _initWs(String sessionId, OrganizerProvider? organizer) {
    _wsService?.disconnect();
    _wsService = WsService(
      onChunkReceived: (chunkIndex, encryptedData) async {
        await _handleChunkReceived(chunkIndex, encryptedData, organizer);
      },
      onStatusEvent: (event) {
        if (event == 'disconnected') {
          _isPaired = false;
          notifyListeners();
        } else if (event == 'completed' && _currentTask != null) {
          _currentTask!.status = TransferTaskStatus.completed;
          notifyListeners();
        }
      },
      onError: (err) {
        _errorMessage = err;
        notifyListeners();
      },
    );

    _wsService!.connect(sessionId);
  }

  Future<void> _handleChunkReceived(
    int chunkIndex,
    String encryptedBase64,
    OrganizerProvider? organizer,
  ) async {
    if (_secretKey == null || _activeSessionId == null) return;

    try {
      // Decrypt AES-256-GCM chunk
      final decryptedBytes = await _crypto.decryptChunk(_secretKey!, encryptedBase64);

      if (_currentTask == null || chunkIndex == 0) {
        // Initialize or create local transfer destination
        final docDir = await getApplicationDocumentsDirectory();
        final saveDir = Directory(p.join(docDir.path, 'LabBridge_Files'));
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final filename = _currentTask?.filename ?? 'transfer_${DateTime.now().millisecondsSinceEpoch}.bin';
        final targetPath = p.join(saveDir.path, filename);

        if (_currentTask == null) {
          _currentTask = TransferTask(
            transferId: _activeSessionId!,
            filename: filename,
            totalSize: decryptedBytes.length,
            totalChunks: 1,
            mimeType: 'application/octet-stream',
            savedPath: targetPath,
            targetFolderId: _defaultTargetFolderId,
          );
        } else {
          _currentTask!.savedPath = targetPath;
        }

        // Overwrite if chunk 0
        final file = File(targetPath);
        await file.writeAsBytes(decryptedBytes, mode: FileMode.write);
      } else if (_currentTask?.savedPath != null) {
        // Append sequential chunk
        final file = File(_currentTask!.savedPath!);
        await file.writeAsBytes(decryptedBytes, mode: FileMode.append);
      }

      // Update state & send ACK
      if (_currentTask != null) {
        _currentTask!.receivedChunks = Math.max(_currentTask!.receivedChunks, chunkIndex + 1);
        _currentTask!.status = TransferTaskStatus.receiving;
        notifyListeners();
      }

      await _api.sendAck(_activeSessionId!, chunkIndex);

      // Check if finished
      if (_currentTask != null && _currentTask!.receivedChunks >= _currentTask!.totalChunks) {
        _currentTask!.status = TransferTaskStatus.completed;
        _history.insert(0, _currentTask!);

        if (_currentTask!.savedPath != null && organizer != null) {
          final fileItem = FileItem(
            id: _uuid.v4(),
            name: _currentTask!.filename,
            folderId: _currentTask!.targetFolderId ?? organizer.currentFolder?.id,
            localPath: _currentTask!.savedPath!,
            size: _currentTask!.totalSize,
            mimeType: _currentTask!.mimeType,
            transferredAt: DateTime.now().toUtc(),
            deviceName: 'PC Relay',
            tags: 'lab,transferred',
          );
          await organizer.addTransferredFile(fileItem);
        }

        notifyListeners();
      }
    } catch (err) {
      if (_currentTask != null) {
        _currentTask!.status = TransferTaskStatus.failed;
        _currentTask!.errorMessage = err.toString();
      }
      _errorMessage = 'Decryption failed: $err';
      notifyListeners();
    }
  }

  void disconnectSession() {
    _wsService?.disconnect();
    _isPaired = false;
    _activeSessionId = null;
    _activePairingToken = null;
    _currentTask = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService?.disconnect();
    super.dispose();
  }
}

class Math {
  static int max(int a, int b) => a > b ? a : b;
}

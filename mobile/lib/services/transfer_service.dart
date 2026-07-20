import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as p;


import '../models/file_item.dart';
import '../models/transfer.dart';
import 'crypto_service.dart';
import 'db_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class TransferProgress {
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final int totalChunks;
  final int completedChunks;
  final TransferDirection direction;

  TransferProgress({
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.totalChunks,
    required this.completedChunks,
    required this.direction,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;
  String get percentage => '${(progress * 100).toStringAsFixed(1)}%';
}

class TransferService extends ChangeNotifier {
  final CryptoService _cryptoService = CryptoService();
  final DbService _dbService = DbService();
  static const _uuid = Uuid();
  static const int _chunkSize = 512 * 1024; // 512KB
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Uint8List? _derivedKey;
  String? _currentSessionId;
  String? get currentSessionId => _currentSessionId;

  // Stream controllers for UI updates
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  final _progressController = StreamController<TransferProgress?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _completionController = StreamController<String>.broadcast();

  Stream<ConnectionStatus> get connectionStatus => _connectionStatusController.stream;
  Stream<TransferProgress?> get progress => _progressController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<String> get completions => _completionController.stream;

  // State for receiving
  File? _tempFile;
  IOSink? _tempSink;
  int _receivedChunks = 0;
  int _totalChunks = 0;
  String _currentFileName = '';
  int _currentFileSize = 0;
  String? _targetFolderId;
  int _transferredBytes = 0;
  DateTime? _transferStartTime;

  // State for sending
  bool _isSending = false;
  Completer<void>? _readyCompleter;
  Completer<int>? _ackCompleter;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _status;

  /// Connect to the Worker WebSocket
  Future<void> connect(String sessionId, String workerUrl) async {
    _status = ConnectionStatus.connecting;
    _connectionStatusController.add(ConnectionStatus.connecting);
    notifyListeners();
    _currentSessionId = sessionId;

    try {
      // Derive encryption key
      _derivedKey = _cryptoService.deriveKey(sessionId);

      // Build WebSocket URL
      final wsUrl = '$workerUrl/session/$sessionId/phone';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready.timeout(const Duration(seconds: 10));

      _status = ConnectionStatus.connected;
      _connectionStatusController.add(ConnectionStatus.connected);
      notifyListeners();

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _status = ConnectionStatus.error;
          _connectionStatusController.add(ConnectionStatus.error);
          notifyListeners();
          _errorController.add('WebSocket error: $error');
          disconnect(sendSignal: false);
        },
        onDone: () {
          _status = ConnectionStatus.disconnected;
          _connectionStatusController.add(ConnectionStatus.disconnected);
          notifyListeners();
          disconnect(sendSignal: false);
        },
      );

      // Send initial folder tree when connected
      await sendFolderTree();
    } catch (e) {
      _status = ConnectionStatus.error;
      _connectionStatusController.add(ConnectionStatus.error);
      notifyListeners();
      _errorController.add('Connection failed: $e');
    }
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      _handleJsonMessage(message);
    } else if (message is List<int>) {
      _handleBinaryMessage(Uint8List.fromList(message));
    }
  }

  void _handleJsonMessage(String message) {
    try {
      final data = json.decode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'transfer_init':
          _handleTransferInit(data);
          break;
        case 'folder_request':
          sendFolderTree();
          break;
        case 'ready':
          if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
            _readyCompleter!.complete();
          }
          break;
        case 'ack':
          if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
            final idx = data['chunk_index'] as int? ?? 0;
            _ackCompleter!.complete(idx);
          }
          break;
        case 'disconnected':
          disconnect(sendSignal: false);
          break;
        case 'error':
          _errorController.add(data['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (e) {
      _errorController.add('Failed to parse message: $e');
    }
  }

  Future<void> sendFolderTree() async {
    if (_channel == null) return;
    try {
      final folders = await _dbService.getAllFolders();
      final foldersList = folders.map((f) => {
        'id': f.id,
        'name': f.name,
        'parentId': f.parentId,
        'color': f.color,
      }).toList();
      _channel!.sink.add(json.encode({
        'type': 'folders',
        'folders': foldersList,
      }));
    } catch (e) {
      _errorController.add('Failed to send folder tree: $e');
    }
  }

  Future<void> _handleTransferInit(Map<String, dynamic> data) async {
    if (_tempSink != null || _tempFile != null) {
      try {
        await _tempSink?.close();
      } catch (_) {}
      if (_tempFile != null && await _tempFile!.exists()) {
        try {
          await _tempFile!.delete();
        } catch (_) {}
      }
      _tempSink = null;
      _tempFile = null;
    }

    _currentFileName = data['filename'] as String? ?? 'unknown';
    _currentFileSize = data['size'] as int? ?? 0;
    _totalChunks = data['total_chunks'] as int? ?? 0;
    _targetFolderId = data['folder_id'] as String?;
    _receivedChunks = 0;
    _transferredBytes = 0;
    _transferStartTime = DateTime.now();

    // Prepare temp file
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'lb_${_uuid.v4()}');
    _tempFile = File(tempPath);
    _tempSink = _tempFile!.openWrite();

    // Send ready signal
    _channel?.sink.add(json.encode({'type': 'ready'}));

    _progressController.add(TransferProgress(
      fileName: _currentFileName,
      totalBytes: _currentFileSize,
      transferredBytes: 0,
      totalChunks: _totalChunks,
      completedChunks: 0,
      direction: TransferDirection.received,
    ));
    notifyListeners();
  }

  Future<void> _handleBinaryMessage(Uint8List data) async {
    if (_tempSink == null || _derivedKey == null) return;

    try {
      // Decrypt chunk
      final decrypted = _cryptoService.decryptChunk(data, _derivedKey!, _receivedChunks);

      // Write to temp file
      _tempSink!.add(decrypted);
      _receivedChunks++;
      _transferredBytes += decrypted.length;

      if (_receivedChunks >= _totalChunks) {
        final sinkToClose = _tempSink;
        final fileToSave = _tempFile;
        final fileNameToSave = _currentFileName;
        final fileSizeToSave = _currentFileSize;
        final folderIdToSave = _targetFolderId;

        _tempSink = null;
        _tempFile = null;

        // Send ack right after detaching
        _channel?.sink.add(json.encode({
          'type': 'ack',
          'chunk_index': _receivedChunks - 1,
        }));

        _progressController.add(TransferProgress(
          fileName: fileNameToSave,
          totalBytes: fileSizeToSave,
          transferredBytes: _transferredBytes,
          totalChunks: _totalChunks,
          completedChunks: _receivedChunks,
          direction: TransferDirection.received,
        ));
        notifyListeners();

        await _finalizeReceive(
          sink: sinkToClose,
          file: fileToSave,
          fileName: fileNameToSave,
          fileSize: fileSizeToSave,
          folderId: folderIdToSave,
        );
      } else {
        // Send ack for non-final chunks
        _channel?.sink.add(json.encode({
          'type': 'ack',
          'chunk_index': _receivedChunks - 1,
        }));

        _progressController.add(TransferProgress(
          fileName: _currentFileName,
          totalBytes: _currentFileSize,
          transferredBytes: _transferredBytes,
          totalChunks: _totalChunks,
          completedChunks: _receivedChunks,
          direction: TransferDirection.received,
        ));
        notifyListeners();
      }
    } catch (e) {
      _errorController.add('Decryption failed: $e');
    }
  }

  Future<void> _finalizeReceive({
    IOSink? sink,
    File? file,
    required String fileName,
    required int fileSize,
    String? folderId,
  }) async {
    await sink?.flush();
    await sink?.close();

    if (file == null) return;

    try {
      // Move to app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final labBridgeDir = Directory(p.join(docsDir.path, 'LabBridge'));
      if (!await labBridgeDir.exists()) {
        await labBridgeDir.create(recursive: true);
      }

      final safeFileName = p.basename(fileName.replaceAll(RegExp(r'[\\/]+'), '_'));
      final targetPath = p.join(labBridgeDir.path, safeFileName);
      if (!p.isWithin(labBridgeDir.path, targetPath)) {
        throw Exception('Invalid file target path');
      }
      final targetFile = await file.copy(targetPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Save to database
      final fileId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _dbService.insertFile(FileItem(
        id: fileId,
        name: safeFileName,
        localPath: targetFile.path,
        size: fileSize,
        folderId: folderId,
        receivedAt: now,
      ));

      await _dbService.insertTransfer(Transfer(
        id: _uuid.v4(),
        fileName: fileName,
        size: fileSize,
        direction: TransferDirection.received,
        status: TransferStatus.completed,
        folderId: folderId,
        completedAt: now,
      ));

      _completionController.add(fileName);
      _progressController.add(null);
      notifyListeners();
    } catch (e) {
      _errorController.add('Failed to save file: $e');
      _progressController.add(null);
    }
  }

  /// Send a file to the PC browser
  Future<void> sendFile(File file, String sessionId) async {
    if (_channel == null || _derivedKey == null) {
      _errorController.add('Not connected');
      return;
    }
    if (_isSending) {
      _errorController.add('A file transfer is already in progress');
      return;
    }
    _isSending = true;

    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final totalChunks = (fileSize / _chunkSize).ceil();

    _readyCompleter = Completer<void>();

    try {
      // Send transfer_init
      _channel!.sink.add(json.encode({
        'type': 'transfer_init',
        'filename': fileName,
        'size': fileSize,
        'total_chunks': totalChunks,
      }));

      _transferStartTime = DateTime.now();

      // Wait for 'ready' signal from server/peer before sending chunks
      await _readyCompleter!.future.timeout(const Duration(seconds: 15));
      _readyCompleter = null;

      // Read and send chunks using RandomAccessFile
      final raf = await file.open(mode: FileMode.read);
      int chunkIndex = 0;
      int transferred = 0;

      try {
        while (true) {
          final chunk = await raf.read(_chunkSize);
          if (chunk.isEmpty) break;

          final encrypted = _cryptoService.encryptChunk(
            chunk,
            _derivedKey!,
            chunkIndex,
          );

          _ackCompleter = Completer<int>();
          _channel!.sink.add(encrypted);

          // Wait for peer to ACK this chunk
          await _ackCompleter!.future.timeout(const Duration(seconds: 15));
          _ackCompleter = null;

          transferred += chunk.length;
          chunkIndex++;

          _progressController.add(TransferProgress(
            fileName: fileName,
            totalBytes: fileSize,
            transferredBytes: transferred,
            totalChunks: totalChunks,
            completedChunks: chunkIndex,
            direction: TransferDirection.sent,
          ));
          notifyListeners();
        }
      } finally {
        await raf.close();
      }

      // Record transfer as completed
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dbService.insertTransfer(Transfer(
        id: _uuid.v4(),
        fileName: fileName,
        size: fileSize,
        direction: TransferDirection.sent,
        status: TransferStatus.completed,
        completedAt: now,
      ));

      _completionController.add(fileName);
      _progressController.add(null);
      notifyListeners();
    } catch (e) {
      // Record transfer as failed
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dbService.insertTransfer(Transfer(
        id: _uuid.v4(),
        fileName: fileName,
        size: fileSize,
        direction: TransferDirection.sent,
        status: TransferStatus.failed,
        completedAt: now,
      ));
      _errorController.add('Transfer failed: $e');
      _progressController.add(null);
      notifyListeners();
      rethrow;
    } finally {
      _isSending = false;
      _readyCompleter = null;
      _ackCompleter = null;
    }
  }

  /// Set the target folder for incoming files
  void setTargetFolder(String? folderId) {
    _targetFolderId = folderId;
  }

  /// Calculate transfer speed in bytes per second
  double getTransferSpeed() {
    if (_transferStartTime == null || _transferredBytes == 0) return 0;
    final elapsed = DateTime.now().difference(_transferStartTime!).inMilliseconds;
    if (elapsed == 0) return 0;
    return _transferredBytes / (elapsed / 1000);
  }

  /// Disconnect from WebSocket
  Future<void> disconnect({bool sendSignal = true}) async {
    if (sendSignal && _channel != null) {
      try {
        _channel!.sink.add(json.encode({'type': 'disconnected'}));
      } catch (_) {}
    }
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _derivedKey = null;
    _currentSessionId = null;

    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      _readyCompleter!.completeError(StateError('Disconnected'));
    }
    if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
      _ackCompleter!.completeError(StateError('Disconnected'));
    }
    _readyCompleter = null;
    _ackCompleter = null;
    _isSending = false;

    if (_tempSink != null || _tempFile != null) {
      try {
        await _tempSink?.close();
      } catch (_) {}
      if (_tempFile != null && await _tempFile!.exists()) {
        try {
          await _tempFile!.delete();
        } catch (_) {}
      }
      _tempSink = null;
      _tempFile = null;
    }

    _status = ConnectionStatus.disconnected;
    _connectionStatusController.add(ConnectionStatus.disconnected);
    _progressController.add(null);
    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _derivedKey = null;
    _currentSessionId = null;
    _tempSink?.close();
    _tempSink = null;
    _tempFile = null;
    _status = ConnectionStatus.disconnected;
    _connectionStatusController.close();
    _progressController.close();
    _errorController.close();
    _completionController.close();
    super.dispose();
  }
}

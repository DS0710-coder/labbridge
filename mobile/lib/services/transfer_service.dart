import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as p;

import '../models/folder.dart';
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
  final _progressController = StreamController<TransferProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _completionController = StreamController<String>.broadcast();

  Stream<ConnectionStatus> get connectionStatus => _connectionStatusController.stream;
  Stream<TransferProgress> get progress => _progressController.stream;
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

      await _channel!.ready;

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
        },
        onDone: () {
          _status = ConnectionStatus.disconnected;
          _connectionStatusController.add(ConnectionStatus.disconnected);
          notifyListeners();
        },
      );
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
        case 'ready':
          // Server is ready to receive our file - handled by sendFile
          break;
        case 'ack':
          // Acknowledgment of chunk received by server
          break;
        case 'error':
          _errorController.add(data['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (e) {
      _errorController.add('Failed to parse message: $e');
    }
  }

  Future<void> _handleTransferInit(Map<String, dynamic> data) async {
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

      // Send ack
      _channel?.sink.add(json.encode({
        'type': 'ack',
        'chunk_index': _receivedChunks - 1,
      }));

      // Update progress
      _progressController.add(TransferProgress(
        fileName: _currentFileName,
        totalBytes: _currentFileSize,
        transferredBytes: _transferredBytes,
        totalChunks: _totalChunks,
        completedChunks: _receivedChunks,
        direction: TransferDirection.received,
      ));
      notifyListeners();

      // Check if all chunks received
      if (_receivedChunks >= _totalChunks) {
        await _finalizeReceive();
      }
    } catch (e) {
      _errorController.add('Decryption failed: $e');
    }
  }

  Future<void> _finalizeReceive() async {
    await _tempSink?.flush();
    await _tempSink?.close();
    _tempSink = null;

    if (_tempFile == null) return;

    try {
      // Move to app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final labBridgeDir = Directory(p.join(docsDir.path, 'LabBridge'));
      if (!await labBridgeDir.exists()) {
        await labBridgeDir.create(recursive: true);
      }

      final targetPath = p.join(labBridgeDir.path, _currentFileName);
      final targetFile = await _tempFile!.copy(targetPath);
      await _tempFile!.delete();

      // Save to database
      final fileId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _dbService.insertFile(FileItem(
        id: fileId,
        name: _currentFileName,
        localPath: targetFile.path,
        size: _currentFileSize,
        folderId: _targetFolderId,
        receivedAt: now,
      ));

      await _dbService.insertTransfer(Transfer(
        id: _uuid.v4(),
        fileName: _currentFileName,
        size: _currentFileSize,
        direction: TransferDirection.received,
        status: TransferStatus.completed,
        folderId: _targetFolderId,
        completedAt: now,
      ));

      _completionController.add(_currentFileName);
      notifyListeners();
    } catch (e) {
      _errorController.add('Failed to save file: $e');
    }
  }

  /// Send folder tree to the PC browser
  void sendFolderTree(List<Folder> folders) {
    final tree = _buildFolderTree(folders, null);
    _channel?.sink.add(json.encode({
      'type': 'folders',
      'tree': tree,
    }));
  }

  List<Map<String, dynamic>> _buildFolderTree(List<Folder> folders, String? parentId) {
    return folders
        .where((f) => f.parentId == parentId)
        .map((f) {
          final json = f.toJson();
          json['children'] = _buildFolderTree(folders, f.id);
          return json;
        })
        .toList();
  }

  /// Send a file to the PC browser
  Future<void> sendFile(File file, String sessionId) async {
    if (_channel == null || _derivedKey == null) {
      _errorController.add('Not connected');
      return;
    }

    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final totalChunks = (fileSize / _chunkSize).ceil();

    // Send transfer_init
    _channel!.sink.add(json.encode({
      'type': 'transfer_init',
      'filename': fileName,
      'size': fileSize,
      'total_chunks': totalChunks,
    }));

    _transferStartTime = DateTime.now();

    // Read and send chunks
    final bytes = await file.readAsBytes();
    int offset = 0;
    int chunkIndex = 0;
    int transferred = 0;

    while (offset < bytes.length) {
      final end = (offset + _chunkSize > bytes.length) ? bytes.length : offset + _chunkSize;
      final chunk = bytes.sublist(offset, end);

      final encrypted = _cryptoService.encryptChunk(
        Uint8List.fromList(chunk),
        _derivedKey!,
        chunkIndex,
      );

      _channel!.sink.add(encrypted);

      transferred += chunk.length;
      chunkIndex++;
      offset = end;

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

    // Record transfer
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
    notifyListeners();
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
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _derivedKey = null;
    _currentSessionId = null;
    _tempSink = null;
    _tempFile = null;
    _status = ConnectionStatus.disconnected;
    _connectionStatusController.add(ConnectionStatus.disconnected);
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

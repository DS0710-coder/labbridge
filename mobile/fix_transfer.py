import re

with open('/home/dev7shah/Desktop/projects/labbridge/mobile/lib/services/transfer_service.dart', 'r') as f:
    content = f.read()

# BUG-19: connect() called concurrently
content = content.replace(
    "  bool _isSending = false;",
    "  bool _isSending = false;\n  bool _isConnecting = false;"
)
content = content.replace(
    "  Future<void> connect(String sessionId, [String? workerUrlOverride]) async {",
    "  Future<void> connect(String sessionId, [String? workerUrlOverride]) async {\n    if (_isConnecting || _status == ConnectionStatus.connected) return;\n    _isConnecting = true;"
)
content = content.replace(
    "      _errorController.add('Connection failed: $e');\n    }",
    "      _errorController.add('Connection failed: $e');\n    } finally {\n      _isConnecting = false;\n    }"
)

# BUG-26: error message doesn't unblock completers
content = content.replace(
    "        case 'error':\n          _errorController.add(data['message'] as String? ?? 'Unknown error');\n          break;",
    "        case 'error':\n          _errorController.add(data['message'] as String? ?? 'Unknown error');\n          if (_readyCompleter != null && !_readyCompleter!.isCompleted) _readyCompleter!.completeError(StateError(data['message'] as String? ?? 'Unknown error'));\n          if (_ackCompleter != null && !_ackCompleter!.isCompleted) _ackCompleter!.completeError(StateError(data['message'] as String? ?? 'Unknown error'));\n          break;"
)

# BUG-29: _tempFile path collision
content = content.replace(
    "final tempPath = p.join(tempDir.path, 'lb_${_uuid.v4()}');",
    "final tempPath = p.join(tempDir.path, 'lb_${_uuid.v4()}_${DateTime.now().millisecondsSinceEpoch}');"
)

# BUG-12: _receivedChunks not validated against chunk index
content = content.replace(
    "      final chunkIndex = result.chunkIndex;\n\n      // Write to temp file\n      _tempSink!.add(decrypted);\n      _receivedChunks++;",
    "      final chunkIndex = result.chunkIndex;\n      if (chunkIndex != _receivedChunks) {\n        throw Exception('Out of order chunk received: expected $_receivedChunks but got $chunkIndex');\n      }\n\n      // Write to temp file\n      _tempSink!.add(decrypted);\n      _receivedChunks++;"
)

# BUG-05 & BUG-25: Disconnect during send completer race and null-dereference
# We'll fix this by adding try-catch inside the loop, and using _channel?.sink.add
content = content.replace(
    "            _ackCompleter = Completer<int>();\n            _channel!.sink.add(encrypted);\n\n            // Wait for peer to ACK this chunk\n            await _ackCompleter!.future.timeout(const Duration(seconds: 15));\n            _ackCompleter = null;",
    "            _ackCompleter = Completer<int>();\n            _channel?.sink.add(encrypted);\n\n            // Wait for peer to ACK this chunk\n            try {\n              await _ackCompleter!.future.timeout(const Duration(seconds: 15));\n            } on StateError {\n              // Disconnected intentionally\n              return;\n            }\n            _ackCompleter = null;"
)

# Fix the zero-byte file case too (lines ~419-423)
content = content.replace(
    "          _ackCompleter = Completer<int>();\n          _channel!.sink.add(encrypted);\n          await _ackCompleter!.future.timeout(const Duration(seconds: 15));\n          _ackCompleter = null;",
    "          _ackCompleter = Completer<int>();\n          _channel?.sink.add(encrypted);\n          try {\n            await _ackCompleter!.future.timeout(const Duration(seconds: 15));\n          } on StateError {\n            return;\n          }\n          _ackCompleter = null;"
)

with open('/home/dev7shah/Desktop/projects/labbridge/mobile/lib/services/transfer_service.dart', 'w') as f:
    f.write(content)


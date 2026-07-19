import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Function(int chunkIndex, String encryptedData) onChunkReceived;
  final Function(String event) onStatusEvent;
  final Function(String error) onError;

  WsService({
    required this.onChunkReceived,
    required this.onStatusEvent,
    required this.onError,
  });

  void connect(String sessionId) {
    disconnect();

    try {
      final base = ApiService().baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final wsUrl = Uri.parse('$base/ws/transfer/$sessionId');
      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            if (data['chunk_index'] != null && data['encrypted_data'] != null) {
              onChunkReceived(data['chunk_index'] as int, data['encrypted_data'] as String);
            } else if (data['event'] != null) {
              onStatusEvent(data['event'] as String);
            }
          } catch (err) {
            onError('Error decoding WS payload: $err');
          }
        },
        onError: (err) {
          onError('WebSocket error: $err');
        },
        onDone: () {
          onStatusEvent('disconnected');
        },
      );
    } catch (err) {
      onError('Failed to connect WebSocket: $err');
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

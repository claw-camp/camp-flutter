import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const _wsUrl = 'ws://119.91.123.2:8889';

  WebSocketChannel? _channel;
  String? _activeConversationId;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  final String campKey;
  Timer? _heartbeat;
  bool _isConnecting = false;
  bool _manuallyDisconnected = false;
  StreamSubscription? _channelSubscription;

  WebSocketService(this.campKey);

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect() {
    if (_isConnecting || _channel != null) return;
    _manuallyDisconnected = false;
    _isConnecting = true;
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

    _channel!.sink.add(jsonEncode({'type': 'subscribe', 'campKey': campKey}));
    if (_activeConversationId != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'watch-conversation',
        'conversationId': _activeConversationId,
      }));
    }

    _channelSubscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data.toString());
          if (msg is Map<String, dynamic>) {
            _controller.add(msg);
          }
        } catch (_) {}
      },
      onError: (_) => _reconnect(),
      onDone: () => _reconnect(),
    );
    _isConnecting = false;

    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _reconnect() {
    _disposeChannel();
    if (_manuallyDisconnected) return;
    Future.delayed(const Duration(seconds: 3), connect);
  }

  void watchConversation(String? conversationId) {
    _activeConversationId = conversationId;
    final channel = _channel;
    if (channel != null) {
      channel.sink.add(jsonEncode({
        'type': 'watch-conversation',
        'conversationId': conversationId,
      }));
    }
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _disposeChannel();
  }

  void _disposeChannel() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
  }
}

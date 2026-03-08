import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';

class WebSocketService {
  static const _wsUrl = 'wss://camp.aigc.sx.cn/ws';

  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  Timer? _heartbeatTimer;
  String? _token;

  Stream<Message> get messageStream => _messageController.stream;

  void connect(String token) {
    _token = token;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl?token=$_token'),
      );

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            if (json['type'] == 'message' || json['type'] == 'chat') {
              final msgData = json['data'] ?? json['message'] ?? json;
              _messageController.add(Message.fromJson(msgData));
            }
          } catch (_) {}
        },
        onError: (_) => _reconnect(),
        onDone: () => _reconnect(),
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          try {
            _channel?.sink.add(jsonEncode({'type': 'ping'}));
          } catch (_) {}
        },
      );
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    _heartbeatTimer?.cancel();
    Future.delayed(const Duration(seconds: 3), _doConnect);
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _token = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const _wsUrl = 'ws://119.91.123.2:8889/ws';

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  final String campKey;
  Timer? _heartbeat;

  WebSocketService(this.campKey);

  Stream<Map<String, dynamic>> get stream => _controller!.stream;

  void connect() {
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

    // 发送 subscribe
    _channel!.sink.add(jsonEncode({
      'type': 'subscribe',
      'campKey': campKey,
    }));

    _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data.toString());
          _controller!.add(msg);
        } catch (_) {}
      },
      onError: (_) => _reconnect(),
      onDone: () => _reconnect(),
    );

    // 心跳
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), connect);
  }

  void disconnect() {
    _heartbeat?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}

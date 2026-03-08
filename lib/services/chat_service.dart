import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'websocket_service.dart';

class ChatService extends ChangeNotifier {
  final AuthService _auth;
  ApiService? _api;
  WebSocketService? _ws;

  List<Conversation> conversations = [];
  Map<String, List<Message>> messagesMap = {};
  bool loading = false;
  StreamSubscription? _wsSub;

  ChatService(this._auth) {
    if (_auth.campKey != null) _init();
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.campKey != null) _init();
  }

  void _init() {
    _api = ApiService(_auth.campKey!);
    _ws = WebSocketService(_auth.campKey!);
    _ws!.connect();
    _wsSub = _ws!.stream.listen(_handleWsMessage);
    loadConversations();
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    if (type == 'chat-message' || type == 'new-message') {
      final payload = msg['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      final convId = payload['conversationId'] as String?;
      if (convId == null) return;
      final newMsg = Message(
        messageId: payload['messageId'] ?? payload['id']?.toString() ?? '',
        conversationId: convId,
        senderId: payload['senderId'] ?? '',
        senderType: payload['senderType'] ?? 'bot',
        content: payload['content'] ?? '',
        createdAt: DateTime.now(),
      );
      messagesMap[convId] = [...(messagesMap[convId] ?? []), newMsg];
      // 更新会话最后消息
      final idx = conversations.indexWhere((c) => c.conversationId == convId);
      if (idx >= 0) {
        final old = conversations[idx];
        conversations[idx] = Conversation(
          id: old.id,
          conversationId: old.conversationId,
          type: old.type,
          name: old.name,
          avatar: old.avatar,
          unreadCount: old.unreadCount + 1,
          lastMessage: newMsg.content,
          lastMessageAt: DateTime.now(),
          botId: old.botId,
        );
      }
      notifyListeners();
    }
  }

  Future<void> loadConversations() async {
    if (_api == null) return;
    loading = true;
    notifyListeners();
    try {
      conversations = await _api!.getConversations();
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<List<Message>> loadMessages(String conversationId) async {
    if (_api == null) return [];
    final msgs = await _api!.getMessages(conversationId);
    messagesMap[conversationId] = msgs;
    notifyListeners();
    return msgs;
  }

  Future<void> sendMessage(String conversationId, String content, {String? botId}) async {
    if (_api == null) return;
    // 先乐观插入
    final tmp = Message(
      messageId: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'me',
      senderType: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    messagesMap[conversationId] = [...(messagesMap[conversationId] ?? []), tmp];
    notifyListeners();
    await _api!.sendMessage(conversationId: conversationId, content: content, botId: botId);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.disconnect();
    super.dispose();
  }
}

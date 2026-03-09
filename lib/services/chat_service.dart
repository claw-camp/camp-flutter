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
      // 兼容 snake_case 和 camelCase
      final convId = payload['conversationId'] ?? payload['conversation_id'] as String?;
      if (convId == null) return;
      final senderType = payload['senderType'] ?? payload['sender_type'] ?? 'bot';
      // 忽略用户自己的消息（已在发送时乐观插入）
      if (senderType == 'user') return;
      // 忽略 typing 指示器（payload 里 type='typing' 且无 content）
      final payloadType = payload['type'] as String?;
      if (payloadType == 'typing') return;
      final content = payload['content'] as String? ?? '';
      // 忽略内容为空的消息（防止 typing/其他非消息事件被误显示）
      if (content.isEmpty) return;
      final newMsg = Message(
        messageId: payload['messageId'] ?? payload['message_id'] ?? payload['id']?.toString() ?? '',
        conversationId: convId,
        senderId: payload['senderId'] ?? payload['sender_id'] ?? '',
        senderType: senderType,
        content: content,
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

  void clearMessages(String conversationId) {
    messagesMap[conversationId] = [];
    notifyListeners();
  }

  Future<Map<String, dynamic>> getAgentStatus(String? botId) async {
    if (_api == null || botId == null) return {'status': '未知'};
    try {
      final agents = await _api!.getAgents();
      final agent = agents.firstWhere(
        (a) => a['botId'] == botId || a['id'] == botId,
        orElse: () => <String, dynamic>{},
      );
      final lastSeen = agent['lastSeen'] as int?;
      return {
        'status': agent['status'] ?? '离线',
        'lastSeen': lastSeen != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSeen).toString().substring(0, 19)
            : '-',
      };
    } catch (_) {
      return {'status': '查询失败'};
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.disconnect();
    super.dispose();
  }
}

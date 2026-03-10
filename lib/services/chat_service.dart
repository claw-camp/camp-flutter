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
  String? _activeCampKey;

  List<Conversation> conversations = [];
  Map<String, List<Message>> messagesMap = {};
  bool loading = false;
  StreamSubscription? _wsSub;

  // 新增：Agent 状态
  Map<String, Map<String, dynamic>> agentStatus = {};
  // 新增：思考状态
  Set<String> thinkingMessages = {};
  // 新增：流式消息缓存（临时）
  Map<String, String> streamingMessages = {}; // messageId -> accumulated content

  // 新增：分页状态
  Map<String, bool> hasMoreMap = {}; // 每个会话是否还有更多消息
  Map<String, bool> loadingMoreMap = {}; // 每个会话是否正在加载更多
  static const int initialLimit = 10; // 初始加载 10 条
  static const int loadMoreLimit = 20; // 加载更多 20 条

  ChatService(this._auth) {
    if (_auth.campKey != null) _init();
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.campKey == null) {
      disconnectRealtime();
      _api = null;
      _activeCampKey = null;
      conversations = [];
      messagesMap = {};
      agentStatus = {};
      thinkingMessages.clear();
      hasMoreMap = {};
      loadingMoreMap = {};
      notifyListeners();
      return;
    }
    if (_auth.campKey != _activeCampKey) {
      disconnectRealtime();
      _init();
    }
  }

  void _init() {
    final campKey = _auth.campKey;
    if (campKey == null) return;
    _activeCampKey = campKey;
    _api = ApiService(campKey);
    loadConversations();
  }

  void connectRealtime() {
    final campKey = _auth.campKey;
    if (campKey == null || _wsSub != null) return;
    _ws = WebSocketService(campKey);
    _ws!.connect();
    _wsSub = _ws!.stream.listen(_handleWsMessage);
  }

  void disconnectRealtime() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.disconnect();
    _ws = null;
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    final payload = msg['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'chat-message':
      case 'new-message':
        _handleNewMessage(payload);
        break;
      case 'msg_stream': // 流式消息 chunk
        _handleMsgStream(payload);
        break;
      case 'msg_ack':
        _handleMsgAck(payload);
        break;
      case 'msg_read':
        _handleMsgRead(payload);
        break;
      case 'msg_thinking':
        _handleMsgThinking(payload);
        break;
      case 'msg_reply':
        _handleMsgReply(payload);
        break;
      case 'agent_status':
        _handleAgentStatus(payload);
        break;
    }
  }

  void _handleMsgStream(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final convId = payload['conversationId'] as String?;
    final tempMsgId = payload['messageId'] as String?;
    final chunk = payload['chunk'] as String?;
    final isDone = payload['isDone'] as bool? ?? false;

    if (convId == null || tempMsgId == null) return;

    final existingMessages = messagesMap[convId] ?? [];
    
    // 如果 isDone，替换临时消息为真实消息
    if (isDone) {
      final realMsgData = payload['message'] as Map<String, dynamic>?;
      if (realMsgData != null) {
        final realMsg = Message.fromJson(realMsgData);
        // 移除临时消息，添加真实消息
        messagesMap[convId] = existingMessages
            .where((m) => m.messageId != tempMsgId)
            .toList()
          ..add(realMsg);
        streamingMessages.remove(tempMsgId);
        _updateConversation(convId, realMsg.content, realMsg.createdAt);
        notifyListeners();
      }
      return;
    }

    // 累积流式内容
    final currentContent = streamingMessages[tempMsgId] ?? '';
    final newContent = currentContent + (chunk ?? '');
    streamingMessages[tempMsgId] = newContent;

    // 更新或创建临时消息
    final existingIdx = existingMessages.indexWhere((m) => m.messageId == tempMsgId);
    if (existingIdx >= 0) {
      // 更新现有消息
      messagesMap[convId]![existingIdx] = existingMessages[existingIdx].copyWith(
        content: newContent,
      );
    } else {
      // 创建临时消息
      final tempMsg = Message(
        messageId: tempMsgId,
        conversationId: convId,
        senderId: 'bot',
        senderType: 'bot',
        content: newContent,
        createdAt: DateTime.now(),
        status: 'pending',
      );
      messagesMap[convId] = [...existingMessages, tempMsg];
    }

    notifyListeners();
  }

  void _handleNewMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final convId =
        (payload['conversationId'] ?? payload['conversation_id']) as String?;
    if (convId == null || convId.isEmpty) return;

    final senderType = payload['senderType'] ?? payload['sender_type'] ?? 'bot';
    if (senderType == 'user') return;

    final payloadType = payload['type'] as String?;
    if (payloadType == 'typing') return;

    final content = payload['content'] as String? ?? '';
    if (content.isEmpty) return;

    final newMsg = Message.fromJson(payload);

    final existingMessages = messagesMap[convId] ?? [];
    if (newMsg.messageId.isNotEmpty &&
        existingMessages.any((msg) => msg.messageId == newMsg.messageId)) {
      return;
    }

    messagesMap[convId] = [...existingMessages, newMsg];
    _updateConversation(convId, newMsg.content, newMsg.createdAt);
    notifyListeners();
  }

  void _handleMsgAck(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = payload['conversationId'] as String?;
    final msgId = payload['messageId'] as String?;
    if (convId == null || msgId == null) return;

    final msgs = messagesMap[convId];
    if (msgs == null) return;

    final idx = msgs.indexWhere((m) => m.messageId == msgId);
    if (idx >= 0) {
      messagesMap[convId]![idx] = msgs[idx].copyWith(status: 'delivered');
      notifyListeners();
    }
  }

  void _handleMsgRead(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = payload['conversationId'] as String?;
    final msgId = payload['messageId'] as String?;
    if (convId == null || msgId == null) return;

    final msgs = messagesMap[convId];
    if (msgs == null) return;

    final idx = msgs.indexWhere((m) => m.messageId == msgId);
    if (idx >= 0) {
      messagesMap[convId]![idx] = msgs[idx].copyWith(
        status: 'read',
        readAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void _handleMsgThinking(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final msgId = payload['messageId'] as String?;
    if (msgId == null) return;

    thinkingMessages.add(msgId);
    notifyListeners();

    // 30秒后自动清除思考状态
    Future.delayed(const Duration(seconds: 30), () {
      thinkingMessages.remove(msgId);
      notifyListeners();
    });
  }

  void _handleMsgReply(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = payload['conversationId'] as String?;
    final msgId = payload['messageId'] as String?;
    if (convId == null || msgId == null) return;

    // 清除思考状态
    thinkingMessages.remove(msgId);

    final msgs = messagesMap[convId];
    if (msgs == null) return;

    final idx = msgs.indexWhere((m) => m.messageId == msgId);
    if (idx >= 0) {
      messagesMap[convId]![idx] = msgs[idx].copyWith(
        model: payload['model'] as String?,
        inputTokens: payload['inputTokens'] as int? ?? 0,
        outputTokens: payload['outputTokens'] as int? ?? 0,
        thinkingMs: payload['thinkingMs'] as int? ?? 0,
        status: 'delivered',
      );
      notifyListeners();
    }
  }

  void _handleAgentStatus(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final agentId = payload['agentId'] as String?;
    final agentName = payload['name'] as String?;
    if (agentId == null) return;

    agentStatus[agentId] = {
      'status': payload['status'] ?? 'unknown',
      'model': payload['model'],
      'sessions': payload['sessions'] ?? 0,
      'uptime': payload['uptime'] ?? 0,
      'lastUpdate': DateTime.now(),
      'name': agentName,
    };
    notifyListeners();
  }

  void _updateConversation(String convId, String lastMsg, DateTime lastTime) {
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
        lastMessage: lastMsg,
        lastMessageAt: lastTime,
        botId: old.botId,
      );
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
    loading = true;
    notifyListeners();
    try {
      final msgs = await _api!.getMessages(conversationId, limit: initialLimit);
      messagesMap[conversationId] = msgs;
      // 如果返回的消息数小于请求的数量，说明没有更多了
      hasMoreMap[conversationId] = msgs.length >= initialLimit;
    } catch (_) {
      messagesMap[conversationId] = [];
      hasMoreMap[conversationId] = false;
    }
    loading = false;
    notifyListeners();
    return messagesMap[conversationId] ?? [];
  }

  /// 加载更多历史消息（往上翻）
  Future<void> loadMoreMessages(String conversationId) async {
    if (_api == null) return;

    // 如果已经在加载或没有更多消息，直接返回
    if (loadingMoreMap[conversationId] == true) return;
    if (hasMoreMap[conversationId] == false) return;

    final existingMsgs = messagesMap[conversationId];
    if (existingMsgs == null || existingMsgs.isEmpty) return;

    // 获取最早的消息 ID
    final oldestMsgId = existingMsgs.first.messageId;
    if (oldestMsgId.isEmpty) return;

    loadingMoreMap[conversationId] = true;
    notifyListeners();

    try {
      final olderMsgs = await _api!.getMessages(
        conversationId,
        limit: loadMoreLimit,
        before: oldestMsgId,
      );

      if (olderMsgs.isNotEmpty) {
        // 将旧消息插入到前面
        messagesMap[conversationId] = [...olderMsgs, ...existingMsgs];
        // 如果返回的消息数小于请求的数量，说明没有更多了
        hasMoreMap[conversationId] = olderMsgs.length >= loadMoreLimit;
      } else {
        // 没有消息了
        hasMoreMap[conversationId] = false;
      }
    } catch (_) {
      // 加载失败，保持现有状态
    }

    loadingMoreMap[conversationId] = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    String conversationId,
    String content, {
    String? botId,
  }) async {
    if (_api == null) return;
    // 先乐观插入
    final tmpId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final tmp = Message(
      messageId: tmpId,
      conversationId: conversationId,
      senderId: 'me',
      senderType: 'user',
      content: content,
      createdAt: DateTime.now(),
      status: 'pending',
    );
    messagesMap[conversationId] = [...(messagesMap[conversationId] ?? []), tmp];
    notifyListeners();

    try {
      final result = await _api!.sendMessage(
        conversationId: conversationId,
        content: content,
        botId: botId,
      );

      // 用返回的真实 messageId 更新临时消息
      final messageData = result['message'] as Map<String, dynamic>?;
      final realId = messageData?['message_id'] as String?;
      if (realId != null && realId != tmpId) {
        final msgs = messagesMap[conversationId];
        if (msgs != null) {
          final idx = msgs.indexWhere((m) => m.messageId == tmpId);
          if (idx >= 0) {
            messagesMap[conversationId]![idx] = msgs[idx].copyWith(
              messageId: realId,
              status: 'sent',
            );
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // 发送失败，更新状态
      final msgs = messagesMap[conversationId];
      if (msgs != null) {
        final idx = msgs.indexWhere((m) => m.messageId == tmpId);
        if (idx >= 0) {
          messagesMap[conversationId]![idx] = msgs[idx].copyWith(status: 'failed');
          notifyListeners();
        }
      }
    }
  }

  void clearMessages(String conversationId) {
    messagesMap[conversationId] = [];
    notifyListeners();
  }

  /// 标记会话为已读（清除本地未读数量）
  void markConversationAsRead(String conversationId) {
    final idx = conversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx >= 0 && conversations[idx].unreadCount > 0) {
      conversations[idx] = Conversation(
        id: conversations[idx].id,
        conversationId: conversations[idx].conversationId,
        type: conversations[idx].type,
        name: conversations[idx].name,
        avatar: conversations[idx].avatar,
        unreadCount: 0, // 清除未读数量
        lastMessage: conversations[idx].lastMessage,
        lastMessageAt: conversations[idx].lastMessageAt,
        botId: conversations[idx].botId,
      );
      notifyListeners();
    }
    // 后端会在 loadMessages 时自动更新 last_read_at
  }

  Future<Map<String, dynamic>> getAgentStatus(String? botId) async {
    if (botId == null) return {'status': '未知'};
    
    // 🔥 移除缓存，每次都实时查询
    if (_api == null) return {'status': '未知'};
    try {
      final agents = await _api!.getAgents();
      final agent = agents.firstWhere(
        (a) => a['botId'] == botId || a['id'] == botId,
        orElse: () => <String, dynamic>{},
      );
      final lastSeen = agent['lastSeen'] as int?;
      return {
        'status': agent['status'] ?? '离线',
        'model': agent['gateway']?['model'],
        'sessions': (agent['sessions'] as List?)?.length ?? 0,
        'lastSeen': lastSeen != null
            ? DateTime.fromMillisecondsSinceEpoch(
                lastSeen,
              ).toString().substring(0, 19)
            : '-',
      };
    } catch (e) {
      print('❌ 获取 Agent 状态失败: $e');
      return {'status': '查询失败'};
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    disconnectRealtime();
    super.dispose();
  }
}

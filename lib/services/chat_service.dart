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
  StreamSubscription? _wsSub;

  // 当前正在查看的会话 ID（用于判断是否增加未读数）
  String? _currentViewingConversationId;

  List<Conversation> conversations = [];
  Map<String, List<Message>> messagesMap = {};
  bool loading = false;

  // Agent 状态
  Map<String, Map<String, dynamic>> agentStatus = {};
  // 思考状态
  Set<String> thinkingMessages = {};
  // 工作状态 / 思考文本（按会话保存）
  Map<String, Map<String, dynamic>> statusMessages = {};
  Map<String, Map<String, dynamic>> reasoningMessages = {};
  // 流式消息缓存（临时）
  Map<String, String> streamingMessages = {};

  // 分页状态
  Map<String, bool> hasMoreMap = {};
  Map<String, bool> loadingMoreMap = {};
  static const int initialLimit = 10;
  static const int loadMoreLimit = 20;

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
      statusMessages.clear();
      reasoningMessages.clear();
      streamingMessages.clear();
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
    
    // 🔥 关键修改：初始化时就连接 WebSocket
    loadConversations();
    connectRealtime();
  }

  /// 设置当前正在查看的会话
  void setCurrentViewingConversation(String? conversationId) {
    _currentViewingConversationId = conversationId;
    _ws?.watchConversation(conversationId);
  }

  void connectRealtime() {
    final campKey = _auth.campKey;
    if (campKey == null || _wsSub != null) return;
    _ws = WebSocketService(campKey);
    _ws!.connect();
    _wsSub = _ws!.stream.listen(_handleWsMessage);
    debugPrint('✅ WebSocket 已连接');
  }

  void watchConversation(String? conversationId) {
    _ws?.watchConversation(conversationId);
  }

  void disconnectRealtime() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.disconnect();
    _ws = null;
    debugPrint('🔌 WebSocket 已断开');
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    final payload = msg['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'chat-message':
      case 'new-message':
        if (payload != null && payload['statusState'] != null) {
          _handleStatusMessage(payload);
        } else if (payload != null && payload['reasoningState'] != null) {
          _handleReasoningMessage(payload);
        } else {
          _handleNewMessage(payload);
        }
        break;
      case 'chat-stream':
      case 'msg_stream':
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

    if (isDone) {
      final finalContent = chunk ?? streamingMessages[tempMsgId] ?? '';
      if (finalContent.isNotEmpty) {
        final existingIdx = existingMessages.indexWhere((m) => m.messageId == tempMsgId);
        if (existingIdx >= 0) {
          messagesMap[convId]![existingIdx] = existingMessages[existingIdx].copyWith(
            content: finalContent,
            status: 'sent',
          );
        }
      }
      streamingMessages.remove(tempMsgId);
      notifyListeners();
      return;
    }

    final newContent = chunk ?? '';
    streamingMessages[tempMsgId] = newContent;

    final existingIdx = existingMessages.indexWhere((m) => m.messageId == tempMsgId);
    if (existingIdx >= 0) {
      messagesMap[convId]![existingIdx] = existingMessages[existingIdx].copyWith(
        content: newContent,
        status: 'pending',
      );
    } else {
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

    if (newContent.isNotEmpty) {
      _updateConversation(convId, newContent, DateTime.now(), incrementUnread: false);
    }
    notifyListeners();
  }

  void _handleStatusMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = (payload['conversationId'] ?? payload['conversation_id']) as String?;
    if (convId == null || convId.isEmpty) return;

    statusMessages[convId] = {
      'messageId': payload['message_id'] ?? payload['messageId'] ?? '',
      'state': payload['statusState'] ?? 'working',
      'text': payload['statusTask'] ?? payload['content'] ?? '',
      'updatedAt': DateTime.now(),
    };

    final state = payload['statusState']?.toString() ?? '';
    if (state == 'complete' || state == 'error') {
      Future.delayed(const Duration(seconds: 2), () {
        if (statusMessages[convId]?['state'] == state) {
          statusMessages.remove(convId);
          notifyListeners();
        }
      });
    }

    notifyListeners();
  }

  void _handleReasoningMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = (payload['conversationId'] ?? payload['conversation_id']) as String?;
    if (convId == null || convId.isEmpty) return;

    reasoningMessages[convId] = {
      'messageId': payload['message_id'] ?? payload['messageId'] ?? '',
      'state': payload['reasoningState'] ?? 'thinking',
      'text': payload['reasoningText'] ?? payload['content'] ?? '',
      'updatedAt': DateTime.now(),
    };

    notifyListeners();
  }

  void _handleNewMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final convId = (payload['conversationId'] ?? payload['conversation_id']) as String?;
    if (convId == null || convId.isEmpty) return;

    final senderType = payload['senderType'] ?? payload['sender_type'] ?? 'bot';
    if (senderType == 'user') return;

    statusMessages.remove(convId);
    reasoningMessages.remove(convId);

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
    
    // 🔥 关键修改：只有不在当前会话页时才增加未读数
    final shouldIncrementUnread = _currentViewingConversationId != convId;
    _updateConversation(convId, newMsg.content, newMsg.createdAt, incrementUnread: shouldIncrementUnread);
    
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

    Future.delayed(const Duration(seconds: 30), () {
      thinkingMessages.remove(msgId);
      notifyListeners();
    });
  }

  void _handleMsgReply(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final convId = payload['conversationId'] as String?;
    final msgId = payload['messageId'] as String?;
    final requestMsgId = payload['requestMessageId'] as String?;
    if (convId == null || msgId == null) return;

    thinkingMessages.remove(msgId);
    if (requestMsgId != null) {
      thinkingMessages.remove(requestMsgId);
    }
    statusMessages.remove(convId);

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

  /// 更新会话列表中的会话信息
  void _updateConversation(String convId, String lastMsg, DateTime lastTime, {bool incrementUnread = true}) {
    final idx = conversations.indexWhere((c) => c.conversationId == convId);
    if (idx >= 0) {
      final old = conversations[idx];
      conversations[idx] = Conversation(
        id: old.id,
        conversationId: old.conversationId,
        type: old.type,
        name: old.name,
        avatar: old.avatar,
        unreadCount: incrementUnread ? old.unreadCount + 1 : old.unreadCount,
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
      hasMoreMap[conversationId] = msgs.length >= initialLimit;
    } catch (_) {
      messagesMap[conversationId] = [];
      hasMoreMap[conversationId] = false;
    }
    loading = false;
    notifyListeners();
    return messagesMap[conversationId] ?? [];
  }

  Future<void> loadMoreMessages(String conversationId) async {
    if (_api == null) return;
    if (loadingMoreMap[conversationId] == true) return;
    if (hasMoreMap[conversationId] == false) return;

    final existingMsgs = messagesMap[conversationId];
    if (existingMsgs == null || existingMsgs.isEmpty) return;

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
        messagesMap[conversationId] = [...olderMsgs, ...existingMsgs];
        hasMoreMap[conversationId] = olderMsgs.length >= loadMoreLimit;
      } else {
        hasMoreMap[conversationId] = false;
      }
    } catch (_) {}

    loadingMoreMap[conversationId] = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    String conversationId,
    String content, {
    String? botId,
  }) async {
    if (_api == null) return;
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

  /// 标记会话为已读
  Future<void> markConversationAsRead(String conversationId) async {
    // 先立即更新本地状态
    final idx = conversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx >= 0 && conversations[idx].unreadCount > 0) {
      conversations[idx] = Conversation(
        id: conversations[idx].id,
        conversationId: conversations[idx].conversationId,
        type: conversations[idx].type,
        name: conversations[idx].name,
        avatar: conversations[idx].avatar,
        unreadCount: 0,
        lastMessage: conversations[idx].lastMessage,
        lastMessageAt: conversations[idx].lastMessageAt,
        botId: conversations[idx].botId,
      );
      notifyListeners();
    }

    // 🔥 调用后端 API 标记已读
    if (_api != null) {
      try {
        await _api!.markConversationAsRead(conversationId);
        debugPrint('✅ 会话已标记为已读: $conversationId');
      } catch (e) {
        debugPrint('❌ 标记已读失败: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getAgentStatus(String? botId) async {
    if (botId == null) return {'status': '未知'};
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
            ? DateTime.fromMillisecondsSinceEpoch(lastSeen).toString().substring(0, 19)
            : '-',
      };
    } catch (e) {
      debugPrint('❌ 获取 Agent 状态失败: $e');
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

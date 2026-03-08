import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'websocket_service.dart';

class ChatService extends ChangeNotifier {
  final AuthService _authService;
  late final ApiService _apiService;
  final WebSocketService _wsService = WebSocketService();

  List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};
  bool _isLoadingConversations = false;
  final Map<String, bool> _isLoadingMessages = {};
  StreamSubscription? _wsSub;

  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;

  ChatService(this._authService) {
    _apiService = ApiService(_authService);
    _listenAuth();
  }

  void _listenAuth() {
    _authService.addListener(_onAuthChanged);
    if (_authService.isLoggedIn) {
      _connectWs();
    }
  }

  void _onAuthChanged() {
    if (_authService.isLoggedIn) {
      _connectWs();
      loadConversations();
    } else {
      _wsService.disconnect();
      _conversations = [];
      _messages.clear();
      _wsSub?.cancel();
      notifyListeners();
    }
  }

  void _connectWs() {
    _wsSub?.cancel();
    final token = _authService.token;
    if (token == null) return;

    _wsService.connect(token);
    _wsSub = _wsService.messageStream.listen((msg) {
      final msgs = _messages[msg.conversationId];
      if (msgs != null) {
        msgs.add(msg);
      }
      // Update conversation's last message
      final idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
      if (idx >= 0) {
        final old = _conversations[idx];
        _conversations[idx] = Conversation(
          id: old.id,
          botId: old.botId,
          botName: old.botName,
          botAvatar: old.botAvatar,
          lastMessage: msg.content,
          lastMessageAt: msg.createdAt,
          unreadCount: old.unreadCount + 1,
        );
        // Move to top
        final updated = _conversations.removeAt(idx);
        _conversations.insert(0, updated);
      }
      notifyListeners();
    });
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      _conversations = await _apiService.getConversations();
    } catch (e) {
      debugPrint('加载会话失败: $e');
    }

    _isLoadingConversations = false;
    notifyListeners();
  }

  List<Message> getMessages(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  bool isLoadingMessages(String conversationId) {
    return _isLoadingMessages[conversationId] ?? false;
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages[conversationId] = true;
    notifyListeners();

    try {
      _messages[conversationId] =
          await _apiService.getMessages(conversationId);
    } catch (e) {
      debugPrint('加载消息失败: $e');
    }

    _isLoadingMessages[conversationId] = false;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String botId,
    required String conversationId,
    required String content,
  }) async {
    // Optimistic add
    final tempMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: MessageRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []);
    _messages[conversationId]!.add(tempMsg);
    notifyListeners();

    try {
      await _apiService.sendMessage(
        botId: botId,
        conversationId: conversationId,
        content: content,
      );
    } catch (e) {
      debugPrint('发送失败: $e');
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _wsSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}

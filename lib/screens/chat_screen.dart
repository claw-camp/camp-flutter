import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/streaming_message.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatService _chatService;
  Map<String, dynamic>? _agentStatus;
  bool _loadingStatus = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔥 使用新方法设置当前查看的会话
      _chatService.setCurrentViewingConversation(widget.conversation.conversationId);
      _chatService.loadMessages(widget.conversation.conversationId);
      _chatService.markConversationAsRead(widget.conversation.conversationId);
      _loadAgentStatus();
    });
  }

  @override
  void dispose() {
    // 🔥 离开聊天页时清除当前查看的会话
    _chatService.setCurrentViewingConversation(null);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // reverse: true 时，检测是否滚动到底部（实际是数据开头）
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    final convId = widget.conversation.conversationId;
    final hasMore = _chatService.hasMoreMap[convId] ?? false;
    final loadingMore = _chatService.loadingMoreMap[convId] ?? false;

    if (!hasMore || loadingMore) return;

    setState(() => _isLoadingMore = true);
    await _chatService.loadMoreMessages(convId);
    
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadAgentStatus() async {
    if (_loadingStatus) return;
    _loadingStatus = true;
    final status = await _chatService.getAgentStatus(widget.conversation.botId);
    if (mounted) {
      setState(() {
        _agentStatus = status;
        _loadingStatus = false;
      });
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    if (text.startsWith('/')) {
      _handleSlashCommand(text);
      return;
    }

    _chatService.sendMessage(
      widget.conversation.conversationId,
      text,
      botId: widget.conversation.botId,
    );
  }

  void _handleSlashCommand(String cmd) {
    final parts = cmd.split(' ');
    final command = parts[0].toLowerCase();

    switch (command) {
      case '/clear':
        _chatService.clearMessages(widget.conversation.conversationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('聊天记录已清空'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case '/logout':
        context.read<AuthService>().logout();
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      default:
        _chatService.sendMessage(
          widget.conversation.conversationId,
          cmd,
          botId: widget.conversation.botId,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final convId = widget.conversation.conversationId;
    final messages = chatService.messagesMap[convId] ?? [];
    final statusMessage = chatService.statusMessages[convId];
    final reasoningMessage = chatService.reasoningMessages[convId];
    final isLoading = chatService.loading;

    final botId = widget.conversation.botId;
    var cachedStatus = chatService.agentStatus[botId];

    if (cachedStatus == null) {
      final convName = widget.conversation.name;
      for (final status in chatService.agentStatus.values) {
        if (status['name'] == convName) {
          cachedStatus = status;
          break;
        }
      }
    }

    if (cachedStatus == null && chatService.agentStatus.isNotEmpty) {
      for (final status in chatService.agentStatus.values) {
        if (status['status'] == 'online') {
          cachedStatus = status;
          break;
        }
      }
    }

    final status = cachedStatus ?? _agentStatus;
    final agentOnline = status?['status'] == 'online';
    final agentModel = status?['model'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: const Color(0xFF333333),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE53935),
                  backgroundImage: widget.conversation.avatar != null
                      ? NetworkImage(widget.conversation.avatar!)
                      : null,
                  child: widget.conversation.avatar == null
                      ? Text(
                          widget.conversation.name.isNotEmpty
                              ? widget.conversation.name[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.conversation.name,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: agentOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (agentModel != null || status != null)
              Text(
                agentModel ?? (agentOnline ? '在线' : '离线'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: Colors.grey[600],
            onPressed: _loadAgentStatus,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE53935)),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          '发送消息开始对话',
                          style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        ),
                      )
                    : Column(
                        children: [
                          // 加载更多指示器（在顶部）
                          if (_isLoadingMore)
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          // 没有更多消息提示
                          if (_chatService.hasMoreMap[widget.conversation.conversationId] == false &&
                              messages.length > ChatService.initialLimit)
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '没有更多消息了',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          // 消息列表（reverse: true）
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true, // 关键：反向列表
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              itemCount: messages.length +
                                  (statusMessage != null ? 1 : 0) +
                                  (reasoningMessage != null ? 1 : 0) +
                                  (chatService.thinkingMessages.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, i) {
                                var extraIndex = 0;

                                if (statusMessage != null && i == extraIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: StatusBubble(
                                      text: (statusMessage['text'] ?? '').toString(),
                                      state: (statusMessage['state'] ?? 'working').toString(),
                                      botName: widget.conversation.name,
                                      botAvatar: widget.conversation.avatar,
                                    ),
                                  );
                                }
                                if (statusMessage != null) extraIndex++;

                                if (reasoningMessage != null && i == extraIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ReasoningBubble(
                                      text: (reasoningMessage['text'] ?? '').toString(),
                                      isComplete: (reasoningMessage['state'] ?? '') == 'complete',
                                      botName: widget.conversation.name,
                                      botAvatar: widget.conversation.avatar,
                                    ),
                                  );
                                }
                                if (reasoningMessage != null) extraIndex++;

                                if (chatService.thinkingMessages.isNotEmpty && i == extraIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ThinkingBubble(
                                      botName: widget.conversation.name,
                                      botAvatar: widget.conversation.avatar,
                                    ),
                                  );
                                }
                                if (chatService.thinkingMessages.isNotEmpty) extraIndex++;

                                final msgIndex = i - extraIndex;
                                if (msgIndex < 0 || msgIndex >= messages.length) {
                                  return const SizedBox.shrink();
                                }

                                // reverse: true 时，需要反向索引
                                final reversedIndex = messages.length - 1 - msgIndex;
                                final msg = messages[reversedIndex];
                                
                                // 流式消息（状态为 pending）
                                if (msg.status == 'pending' && msg.senderType == 'bot') {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: StreamingMessage(
                                      content: msg.content,
                                      botName: widget.conversation.name,
                                      botAvatar: widget.conversation.avatar,
                                      isStreaming: true,
                                    ),
                                  );
                                }

                                // 普通消息
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: MessageBubble(
                                    message: msg,
                                    botName: widget.conversation.name,
                                    botAvatar: widget.conversation.avatar,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          // Input bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFFE53935),
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

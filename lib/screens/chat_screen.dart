import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().loadMessages(widget.conversation.conversationId);
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    // 处理斜杠命令
    if (text.startsWith('/')) {
      _handleSlashCommand(text);
      return;
    }

    context.read<ChatService>().sendMessage(widget.conversation.conversationId, text, botId: widget.conversation.botId);

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _handleSlashCommand(String cmd) {
    final parts = cmd.split(' ');
    final command = parts[0].toLowerCase();
    final args = parts.skip(1).join(' ');

    switch (command) {
      case '/help':
        _showHelpDialog();
        break;
      case '/clear':
        context.read<ChatService>().clearMessages(widget.conversation.conversationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('聊天记录已清空'), duration: Duration(seconds: 1)),
        );
        break;
      case '/status':
        _showAgentStatus();
        break;
      case '/logout':
        context.read<AuthService>().logout();
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      default:
        // 未知命令，当作普通消息发送
        context.read<ChatService>().sendMessage(widget.conversation.conversationId, cmd, botId: widget.conversation.botId);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🦞 斜杠命令'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommandHelp(cmd: '/help', desc: '显示帮助'),
            SizedBox(height: 8),
            _CommandHelp(cmd: '/clear', desc: '清空当前聊天记录'),
            SizedBox(height: 8),
            _CommandHelp(cmd: '/status', desc: '查看 Agent 状态'),
            SizedBox(height: 8),
            _CommandHelp(cmd: '/logout', desc: '退出登录'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _showAgentStatus() async {
    final status = await context.read<ChatService>().getAgentStatus(widget.conversation.botId);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🤖 Agent 状态'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bot ID: ${widget.conversation.botId}'),
            const SizedBox(height: 8),
            Text('状态: ${status['status'] ?? '未知'}'),
            const SizedBox(height: 8),
            Text('最后在线: ${status['lastSeen'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final messages = chatService.messagesMap[widget.conversation.conversationId] ?? [];
    final isLoading = chatService.loading;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

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
        title: Row(
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
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE53935),
                    ),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          '发送消息开始对话',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          return MessageBubble(
                            message: messages[i],
                            botName: widget.conversation.name,
                            botAvatar: widget.conversation.avatar,
                          );
                        },
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

class _CommandHelp extends StatelessWidget {
  final String cmd;
  final String desc;
  const _CommandHelp({required this.cmd, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(cmd, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935))),
        const SizedBox(width: 12),
        Text(desc, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final String botName;
  final String? botAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.botName,
    this.botAvatar,
  });

  // 状态图标
  Widget _buildStatusIcon() {
    String icon;
    Color color;
    
    switch (message.status) {
      case 'pending':
        icon = '⏳';
        color = Colors.grey;
        break;
      case 'sent':
        icon = '✓';
        color = Colors.grey;
        break;
      case 'delivered':
        icon = '✓✓';
        color = Colors.grey;
        break;
      case 'read':
        icon = '✓✓';
        color = const Color(0xFFE53935);
        break;
      case 'failed':
        icon = '✗';
        color = Colors.red;
        break;
      default:
        icon = '';
        color = Colors.grey;
    }
    
    return Text(
      icon,
      style: TextStyle(
        fontSize: 12,
        color: color,
      ),
    );
  }

  // 格式化时间
  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 复制文本到剪贴板
  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 判断是否包含 Markdown 语法
  bool _hasMarkdown(String text) {
    // 检测常见的 Markdown 语法
    final mdPatterns = [
      RegExp(r'\*\*.*?\*\*'),      // **bold**
      RegExp(r'\*.*?\*'),          // *italic*
      RegExp(r'`[^`]+`'),          // `code`
      RegExp(r'```[\s\S]*?```'),   // ```code block```
      RegExp(r'^#+\s', multiLine: true),  // # headers
      RegExp(r'^[-*+]\s', multiLine: true), // - list
      RegExp(r'^\d+\.\s', multiLine: true), // 1. list
      RegExp(r'\[.*?\]\(.*?\)'),   // [link](url)
      RegExp(r'^>\s', multiLine: true),    // > quote
    ];
    
    return mdPatterns.any((p) => p.hasMatch(text));
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromMe;
    final hasMd = _hasMarkdown(message.content);
    final textColor = isUser ? Colors.white : const Color(0xFF333333);
    final bgColor = isUser ? const Color(0xFFE53935) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE53935),
              backgroundImage:
                  botAvatar != null ? NetworkImage(botAvatar!) : null,
              child: botAvatar == null
                  ? Text(
                      botName.isNotEmpty ? botName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _copyText(context, message.content),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: hasMd && !isUser
                        ? MarkdownBody(
                            data: message.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                height: 1.4,
                              ),
                              code: TextStyle(
                                backgroundColor: Colors.grey[200],
                                color: const Color(0xFFE53935),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              blockquote: TextStyle(
                                color: textColor.withAlpha(180),
                                fontStyle: FontStyle.italic,
                              ),
                              listBullet: TextStyle(color: textColor),
                              h1: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              h2: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              h3: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                // 可以用 url_launcher 打开链接
                              }
                            },
                          )
                        : SelectableText(
                            message.content,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                // 底部信息行
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 时间
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    // AI 元数据（仅 bot 消息显示）
                    if (!isUser && message.model != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        message.model!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                    if (!isUser && message.totalTokens > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${message.totalTokens} tok',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                    // 状态图标（仅用户消息显示）
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

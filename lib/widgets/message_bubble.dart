import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromMe;

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
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFE53935) : Colors.white,
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
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF333333),
                      fontSize: 15,
                      height: 1.4,
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

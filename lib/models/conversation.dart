class Conversation {
  final int id;
  final String conversationId;
  final String type;
  final String name;
  final String? avatar;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? botId;

  Conversation({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.name,
    this.avatar,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.botId,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'],
    conversationId: j['conversation_id'],
    type: j['type'] ?? 'bot',
    name: j['name'] ?? '未命名',
    avatar: j['avatar'],
    unreadCount: j['unread_count'] ?? 0,
    lastMessage: j['last_message'],
    lastMessageAt: j['last_message_at'] != null
        ? DateTime.tryParse(j['last_message_at'])
        : null,
    botId: j['bot_id'],
  );
}

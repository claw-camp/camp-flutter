class Conversation {
  final String id;
  final String botId;
  final String botName;
  final String? botAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.botId,
    required this.botName,
    this.botAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      botId: json['botId'] ?? '',
      botName: json['botName'] ?? json['bot']?['name'] ?? 'Agent',
      botAvatar: json['botAvatar'] ?? json['bot']?['avatar'],
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'])
              : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

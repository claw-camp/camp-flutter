class Message {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderType; // 'user' | 'bot' | 'agent'
  final String content;
  final String contentType;
  final DateTime createdAt;

  Message({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    required this.content,
    this.contentType = 'text',
    required this.createdAt,
  });

  bool get isFromMe => senderType == 'user';

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    messageId: j['message_id'] ?? j['id']?.toString() ?? '',
    conversationId: j['conversation_id'] ?? '',
    senderId: j['sender_id'] ?? '',
    senderType: j['sender_type'] ?? 'user',
    content: j['content'] ?? '',
    contentType: j['content_type'] ?? 'text',
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
        : DateTime.now(),
  );
}

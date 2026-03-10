class Message {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderType; // 'user' | 'bot' | 'agent'
  final String content;
  final String contentType;
  final DateTime createdAt;
  
  // 新增：消息状态
  final String status; // 'pending' | 'sent' | 'delivered' | 'read' | 'failed'
  final DateTime? readAt;
  
  // 新增：AI 元数据
  final String? model;
  final int inputTokens;
  final int outputTokens;
  final int thinkingMs;

  Message({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    required this.content,
    this.contentType = 'text',
    required this.createdAt,
    this.status = 'sent',
    this.readAt,
    this.model,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.thinkingMs = 0,
  });

  bool get isFromMe => senderType == 'user';
  
  // 是否已读
  bool get isRead => status == 'read' || readAt != null;
  
  // 总 token 数
  int get totalTokens => inputTokens + outputTokens;

  factory Message.fromJson(Map<String, dynamic> j) {
    DateTime parseLocalTime(dynamic value) {
      if (value == null) return DateTime.now();
      final dt = DateTime.tryParse(value.toString());
      if (dt == null) return DateTime.now();
      // 如果是 UTC 时间，转换为本地时间
      return dt.isUtc ? dt.toLocal() : dt;
    }

    return Message(
      messageId: j['message_id'] ?? j['id']?.toString() ?? '',
      conversationId: j['conversation_id'] ?? '',
      senderId: j['sender_id'] ?? '',
      senderType: j['sender_type'] ?? 'user',
      content: j['content'] ?? '',
      contentType: j['content_type'] ?? j['message_type'] ?? 'text',
      createdAt: parseLocalTime(j['created_at']),
      status: j['status'] ?? 'sent',
      readAt: j['read_at'] != null ? parseLocalTime(j['read_at']) : null,
      model: j['model'],
      inputTokens: j['input_tokens'] ?? 0,
      outputTokens: j['output_tokens'] ?? 0,
      thinkingMs: j['thinking_ms'] ?? 0,
    );
  }
  
  // 复制并更新状态
  Message copyWith({
    String? messageId,
    String? content,
    String? status,
    DateTime? readAt,
    String? model,
    int? inputTokens,
    int? outputTokens,
    int? thinkingMs,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderType: senderType,
      content: content ?? this.content,
      contentType: contentType,
      createdAt: createdAt,
      status: status ?? this.status,
      readAt: readAt ?? this.readAt,
      model: model ?? this.model,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      thinkingMs: thinkingMs ?? this.thinkingMs,
    );
  }
}

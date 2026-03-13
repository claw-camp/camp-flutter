import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation.dart';
import '../models/message.dart';

class ApiService {
  static const _baseUrl = 'http://119.91.123.2';
  final String campKey;

  ApiService(this.campKey);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-camp-key': campKey,
  };

  Future<List<Conversation>> getConversations() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/chat/conversations'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['conversations'] as List;
      return list.map((e) => Conversation.fromJson(e)).toList();
    }
    throw Exception('获取会话失败: ${res.body}');
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before, // 加载此消息 ID 之前的消息
  }) async {
    var url = '$_baseUrl/api/chat/messages/$conversationId?limit=$limit';
    if (before != null) {
      url += '&before=$before';
    }
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['messages'] as List;
      return list.map((e) => Message.fromJson(e)).toList();
    }
    throw Exception('获取消息失败');
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String content,
    String? botId,
  }) async {
    final body = {
      'conversationId': conversationId,
      'content': content,
      'contentType': 'text',
      if (botId != null) 'botId': botId,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/api/chat/message'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> getAgents() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/agents'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data['agents'] ?? []);
    }
    return [];
  }

  /// 标记会话为已读
  Future<void> markConversationAsRead(String conversationId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/chat/conversations/$conversationId/read'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('标记已读失败: ${res.body}');
    }
  }
}

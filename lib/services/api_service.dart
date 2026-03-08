import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation.dart';
import '../models/message.dart';
import 'auth_service.dart';

class ApiService {
  static const _baseUrl = 'http://119.91.123.2';
  final AuthService _authService;

  ApiService(this._authService);

  Future<List<Conversation>> getConversations() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/conversations'),
      headers: _authService.authHeaders,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data is List ? data : (data['data'] ?? data['conversations'] ?? []);
      return (list as List).map((j) => Conversation.fromJson(j)).toList();
    }
    throw Exception('获取会话列表失败: ${response.statusCode}');
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/messages'),
      headers: _authService.authHeaders,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data is List ? data : (data['data'] ?? data['messages'] ?? []);
      return (list as List).map((j) => Message.fromJson(j)).toList();
    }
    throw Exception('获取消息失败: ${response.statusCode}');
  }

  Future<Message?> sendMessage({
    required String botId,
    required String conversationId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/chat/messages'),
      headers: _authService.authHeaders,
      body: jsonEncode({
        'botId': botId,
        'conversationId': conversationId,
        'content': content,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final msgData = data['data'] ?? data['message'] ?? data;
      return Message.fromJson(msgData);
    }
    throw Exception('发送消息失败: ${response.statusCode}');
  }
}

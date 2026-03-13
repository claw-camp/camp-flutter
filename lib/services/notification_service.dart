import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 🔥 请求通知权限 (Android 13+)
    await _requestPermission();

    _initialized = true;
    debugPrint('✅ 通知服务已初始化');
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (status != PermissionStatus.granted) {
      debugPrint('📱 请求通知权限...');
      final result = await Permission.notification.request();
      if (result == PermissionStatus.granted) {
        debugPrint('✅ 通知权限已授予');
      } else {
        debugPrint('⚠️ 通知权限被拒绝');
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 通知被点击: ${response.payload}');
    // TODO: 点击通知跳转到对应聊天
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      '聊天消息',
      channelDescription: '收到新消息时通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

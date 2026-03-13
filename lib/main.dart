import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  await NotificationService().init();

  final authService = AuthService();
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProxyProvider<AuthService, ChatService>(
          create: (context) => ChatService(authService),
          update: (context, auth, previous) => previous ?? ChatService(auth),
        ),
      ],
      child: const CampApp(),
    ),
  );
}

class CampApp extends StatefulWidget {
  const CampApp({super.key});

  @override
  State<CampApp> createState() => _CampAppState();
}

class _CampAppState extends State<CampApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final chatService = context.read<ChatService?>();
    if (chatService == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // 前台：恢复完整连接，刷新数据
        chatService.setAppForeground(true);
        chatService.connectRealtime();
        chatService.loadConversations();
        break;
      case AppLifecycleState.paused:
        // 🔥 后台：保持连接，标记为后台状态
        chatService.setAppForeground(false);
        break;
      case AppLifecycleState.detached:
        // 完全退出：断开连接
        chatService.disconnectRealtime();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '龙虾营地',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          primary: const Color(0xFFE53935),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF333333),
          elevation: 0,
        ),
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

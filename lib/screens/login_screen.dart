import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _campKeyCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showPasswordLogin = false;

  @override
  void dispose() {
    _campKeyCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithCampKey() async {
    final key = _campKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = '请输入 Camp Key');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthService>().loginWithCampKey(key);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginWithPassword() async {
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = '请输入用户名和密码');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await context.read<AuthService>().loginWithPassword(u, p);
      if (result['success'] != true) {
        setState(() => _error = result['error'] ?? '登录失败');
      }
    } catch (e) {
      setState(() => _error = '网络错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('龙虾营地', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 8),
                Text('AI Agent 聊天客户端', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 40),

                // 卡片
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_showPasswordLogin) ...[
                        const Text('Camp Key 登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _campKeyCtrl,
                          decoration: InputDecoration(
                            hintText: '输入你的 Camp Key',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.key),
                          ),
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _loginWithCampKey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() { _showPasswordLogin = true; _error = null; }),
                            child: const Text('用用户名密码登录', style: TextStyle(color: Color(0xFFE53935))),
                          ),
                        ),
                      ] else ...[
                        const Text('用户名密码登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            hintText: '用户名',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '密码',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _loginWithPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() { _showPasswordLogin = false; _error = null; }),
                            child: const Text('用 Camp Key 登录', style: TextStyle(color: Color(0xFFE53935))),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

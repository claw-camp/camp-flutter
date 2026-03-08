import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = '1.0.8';
  String? _latestVersion;
  bool _checking = false;

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final response = await http.get(Uri.parse('${AppConstants.apiBaseUrl}/api/app/version'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _latestVersion = data['version']);

        if (!mounted) return;

        if (data['version'] != _currentVersion) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('发现新版本'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前版本: v$_currentVersion'),
                  Text('最新版本: v${data['version']}'),
                  if (data['releaseNotes'] != null) ...[
                    const SizedBox(height: 12),
                    const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['releaseNotes']),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('稍后再说'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    launchUrl(Uri.parse(data['downloadUrl']));
                  },
                  child: const Text('立即更新'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已是最新版本 ✓'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE53935),
                  child: Text(
                    auth.username != null
                        ? (auth.username ?? "U")[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.username ?? "营地用户",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已登录',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Settings items
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.system_update,
                  title: '检查更新',
                  subtitle: _checking ? '检查中...' : 'v$_currentVersion',
                  onTap: _checkUpdate,
                ),
                const Divider(height: 1, indent: 52),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '关于',
                  subtitle: '龙虾营地 v$_currentVersion',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 52),
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: '帮助与反馈',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Logout button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _SettingsTile(
              icon: Icons.logout,
              title: '退出登录',
              titleColor: const Color(0xFFE53935),
              showArrow: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('退出后需要重新输入 Camp Key 登录'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          auth.logout();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                        ),
                        child: const Text('退出'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool showArrow;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.showArrow = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? const Color(0xFF666666)),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? const Color(0xFF333333),
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
              ),
            )
          : null,
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC))
          : null,
      onTap: onTap,
    );
  }
}

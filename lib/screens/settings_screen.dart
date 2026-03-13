import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = '';
  String? _latestVersion;
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _currentVersion = info.version);
      } else {
        // 使用默认版本
        if (mounted) {
          setState(() => _currentVersion = '1.4.6');
        }
      }
    } catch (e) {
      debugPrint('PackageInfo 错误: $e');
      // package_info_plus 失败时使用默认值
      if (mounted) {
        setState(() => _currentVersion = '1.4.6');
      }
    }
  }

  Future<void> _checkUpdate() async {
    if (_checking || _downloading) return;
    setState(() => _checking = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/app/version'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latest = data['version'] as String?;
        setState(() => _latestVersion = latest);

        if (!mounted) return;

        if (latest != null && latest != _currentVersion) {
          _showUpdateDialog(data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已是最新版本 ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> data) {
    final latest = data['version'] as String? ?? '';
    final notes = data['releaseNotes'] as String?;
    final downloadUrl = data['downloadUrl'] as String? ??
        '${AppConstants.apiBaseUrl}/camp-flutter-latest.apk';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: v$_currentVersion'),
            Text('最新版本: v$latest',
                style: const TextStyle(
                    color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
            if (notes != null) ...[
              const SizedBox(height: 12),
              const Text('更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(notes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(downloadUrl, latest);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(String downloadUrl, String version) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      // 获取外部存储下载目录（安装器可访问）
      Directory? dir;
      if (Platform.isAndroid) {
        // Android: 使用外部存储的 Download 目录
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          // 回退到应用外部目录
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationSupportDirectory();
      }
      
      final apkDir = Directory('${dir!.path}/clawcamp');
      if (!await apkDir.exists()) await apkDir.create(recursive: true);
      final apkPath = '${apkDir.path}/camp-flutter-$version.apk';

      // 流式下载，带进度
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;
      int received = 0;

      final file = File(apkPath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      }).asFuture();
      await sink.close();

      if (!mounted) return;
      setState(() => _downloading = false);

      // 检查安装权限（Android 8+）
      final installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('需要安装权限，请在设置中允许安装未知应用'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: '去设置',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // 使用 OpenFile 打开 APK 安装
      final result = await OpenFile.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('安装失败: ${result.message}'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '手动安装',
                textColor: Colors.white,
                onPressed: () {
                  // 打开文件管理器
                  OpenFile.open(apkPath);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          // 用户信息卡片
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
                        ? (auth.username ?? 'U')[0].toUpperCase()
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
                        auth.username ?? '营地用户',
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

          // 下载进度条
          if (_downloading)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.downloading,
                          color: Color(0xFFE53935), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '正在下载更新... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF666666)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: const Color(0xFFEEEEEE),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE53935)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

          // 功能列表
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
                  subtitle: _checking
                      ? '检查中...'
                      : _downloading
                          ? '下载中...'
                          : _currentVersion.isNotEmpty
                              ? 'v$_currentVersion'
                              : '...',
                  onTap: _checkUpdate,
                ),
                const Divider(height: 1, indent: 52),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '关于',
                  subtitle: _currentVersion.isNotEmpty
                      ? '龙虾营地 v$_currentVersion'
                      : '龙虾营地',
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

          // 退出登录
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

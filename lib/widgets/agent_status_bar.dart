import 'package:flutter/material.dart';

/// AI Agent 状态指示器
/// 显示在输入框上方，清晰展示 AI 当前状态
class AgentStatusBar extends StatelessWidget {
  final bool isThinking;
  final bool isWorking;
  final bool isStreaming;
  final String? thinkingText;
  final String? workingText;
  final bool isOnline;

  const AgentStatusBar({
    super.key,
    this.isThinking = false,
    this.isWorking = false,
    this.isStreaming = false,
    this.thinkingText,
    this.workingText,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    // 确定当前状态
    final status = _determineStatus();
    if (status == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(30),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 状态图标 + 动画
          _buildAnimatedIcon(status),
          const SizedBox(width: 8),
          // 状态文本
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: status.textColor,
                  ),
                ),
                if (status.detail != null && status.detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    status.detail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: status.textColor.withAlpha(180),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(_StatusInfo status) {
    if (status.animate) {
      return _PulsingDot(color: status.iconColor);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: status.iconColor,
        shape: BoxShape.circle,
      ),
    );
  }

  _StatusInfo? _determineStatus() {
    // 优先级：streaming > thinking > working > idle
    if (isStreaming) {
      return _StatusInfo(
        label: '回复中',
        detail: null,
        iconColor: const Color(0xFFE53935),
        textColor: const Color(0xFF333333),
        backgroundColor: const Color(0xFFFFEBEE),
        animate: true,
      );
    }

    if (isThinking) {
      return _StatusInfo(
        label: '思考中',
        detail: thinkingText,
        iconColor: const Color(0xFFFF9800),
        textColor: const Color(0xFF333333),
        backgroundColor: const Color(0xFFFFF3E0),
        animate: true,
      );
    }

    if (isWorking) {
      return _StatusInfo(
        label: '处理中',
        detail: workingText,
        iconColor: const Color(0xFF2196F3),
        textColor: const Color(0xFF333333),
        backgroundColor: const Color(0xFFE3F2FD),
        animate: true,
      );
    }

    // idle 状态 - 不显示或显示在线
    if (!isOnline) {
      return _StatusInfo(
        label: '离线',
        detail: null,
        iconColor: Colors.grey,
        textColor: Colors.grey[700]!,
        backgroundColor: Colors.grey[100]!,
        animate: false,
      );
    }

    // 在线且 idle - 不显示状态条
    return null;
  }
}

/// 脉动动画圆点
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withAlpha((_animation.value * 255).round()),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(60),
                blurRadius: 4,
                spreadRadius: _animation.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 状态信息
class _StatusInfo {
  final String label;
  final String? detail;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final bool animate;

  _StatusInfo({
    required this.label,
    this.detail,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.animate,
  });
}

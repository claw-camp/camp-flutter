import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 流式消息气泡 - 支持逐字打印效果 + Markdown 渲染 + 思考动画 + 文字复制
class StreamingMessage extends StatefulWidget {
  final String content;
  final String botName;
  final String? botAvatar;
  final bool isStreaming;
  final bool isThinking; // 🔥 是否在思考中（还没有内容）
  final VoidCallback? onComplete;

  const StreamingMessage({
    super.key,
    required this.content,
    required this.botName,
    this.botAvatar,
    this.isStreaming = true,
    this.isThinking = false,
    this.onComplete,
  });

  @override
  State<StreamingMessage> createState() => _StreamingMessageState();
}

class _StreamingMessageState extends State<StreamingMessage>
    with TickerProviderStateMixin {
  String _displayText = '';
  int _charIndex = 0;
  Timer? _timer;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    
    // 呼吸动画（用于光标）
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
    // 思考动画（三个点）
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _dotsAnimation = IntTween(begin: 1, end: 3).animate(
      CurvedAnimation(parent: _dotsController, curve: Curves.easeInOut),
    );
    
    if (widget.isStreaming && widget.content.isNotEmpty) {
      _startStreaming();
    } else {
      _displayText = widget.content;
    }
  }

  @override
  void didUpdateWidget(StreamingMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      if (widget.isStreaming) {
        _startStreaming();
      } else {
        setState(() {
          _displayText = widget.content;
          _charIndex = widget.content.length;
        });
      }
    }
  }

  void _startStreaming() {
    _timer?.cancel();

    if (_displayText.isNotEmpty && widget.content.startsWith(_displayText)) {
      _charIndex = _displayText.length;
    } else {
      _charIndex = 0;
      _displayText = '';
    }

    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_charIndex < widget.content.length) {
        final step = (widget.content.length - _charIndex) > 12 ? 3 : 1;
        setState(() {
          _charIndex = (_charIndex + step).clamp(0, widget.content.length);
          _displayText = widget.content.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathingController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  // 复制文本到剪贴板
  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 判断是否包含 Markdown 语法
  bool _hasMarkdown(String text) {
    final mdPatterns = [
      RegExp(r'\*\*.*?\*\*'),
      RegExp(r'\*.*?\*'),
      RegExp(r'`[^`]+`'),
      RegExp(r'```[\s\S]*?```'),
      RegExp(r'^#+\s', multiLine: true),
      RegExp(r'^[-*+]\s', multiLine: true),
      RegExp(r'^\d+\.\s', multiLine: true),
      RegExp(r'\[.*?\]\(.*?\)'),
      RegExp(r'^>\s', multiLine: true),
    ];
    return mdPatterns.any((p) => p.hasMatch(text));
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _displayText.isNotEmpty;
    final hasMd = hasContent && _hasMarkdown(_displayText);
    final showThinking = widget.isThinking || (widget.isStreaming && !hasContent);

    return GestureDetector(
      onLongPress: () => _copyText(context, _displayText),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE53935),
            backgroundImage: widget.botAvatar != null
                ? NetworkImage(widget.botAvatar!)
                : null,
            child: widget.botAvatar == null
                ? Text(
                    widget.botName.isNotEmpty
                        ? widget.botName[0].toUpperCase()
                        : 'B',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                minHeight: showThinking ? 60 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 内容区域
                  if (hasContent)
                    hasMd && !widget.isStreaming
                        ? MarkdownBody(
                            data: _displayText,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Color(0xFF333333),
                              ),
                              code: TextStyle(
                                backgroundColor: Colors.grey[200],
                                color: const Color(0xFFE53935),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              blockquote: TextStyle(
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                              listBullet: const TextStyle(color: Color(0xFF333333)),
                              h1: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              h2: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              h3: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Text(
                            _displayText,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Color(0xFF333333),
                            ),
                          ),
                  
                  // 思考动画（在底部）
                  if (showThinking || (widget.isStreaming && _charIndex < widget.content.length))
                    Padding(
                      padding: EdgeInsets.only(top: hasContent ? 8 : 0),
                      child: _buildThinkingIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isThinking ? '思考中' : '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (widget.isThinking) const SizedBox(width: 4),
            ...List.generate(3, (index) {
              final delay = index * 0.33;
              final value = (_dotsController.value + delay) % 1.0;
              final scale = 0.5 + (value < 0.5 ? value * 2 : (1 - value) * 2) * 0.5;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// 状态气泡
class StatusBubble extends StatelessWidget {
  final String text;
  final String state;
  final String botName;
  final String? botAvatar;

  const StatusBubble({
    super.key,
    required this.text,
    required this.state,
    required this.botName,
    this.botAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'error' => Colors.red,
      'complete' => Colors.green,
      'tool' => Colors.orange,
      'replying' => const Color(0xFFE53935),
      _ => Colors.blueGrey,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE53935),
          backgroundImage: botAvatar != null ? NetworkImage(botAvatar!) : null,
          child: botAvatar == null
              ? Text(
                  botName.isNotEmpty ? botName[0].toUpperCase() : 'B',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text.isEmpty ? '正在处理中...' : text,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 思考气泡（已废弃，保留兼容）
class ThinkingBubble extends StatelessWidget {
  final String botName;
  final String? botAvatar;

  const ThinkingBubble({
    super.key,
    required this.botName,
    this.botAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // 不再显示单独的思考气泡
  }
}

/// 推理气泡
class ReasoningBubble extends StatelessWidget {
  final String text;
  final bool isComplete;
  final String botName;
  final String? botAvatar;

  const ReasoningBubble({
    super.key,
    required this.text,
    required this.isComplete,
    required this.botName,
    this.botAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE53935),
          backgroundImage: botAvatar != null ? NetworkImage(botAvatar!) : null,
          child: botAvatar == null
              ? Text(
                  botName.isNotEmpty ? botName[0].toUpperCase() : 'B',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? '💭 思考完成' : '🤔 思考中',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

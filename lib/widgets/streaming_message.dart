import 'dart:async';
import 'package:flutter/material.dart';

/// 流式消息气泡 - 支持逐字打印效果
class StreamingMessage extends StatefulWidget {
  final String content;
  final String botName;
  final String? botAvatar;
  final bool isStreaming;
  final VoidCallback? onComplete;

  const StreamingMessage({
    super.key,
    required this.content,
    required this.botName,
    this.botAvatar,
    this.isStreaming = true,
    this.onComplete,
  });

  @override
  State<StreamingMessage> createState() => _StreamingMessageState();
}

class _StreamingMessageState extends State<StreamingMessage>
    with SingleTickerProviderStateMixin {
  String _displayText = '';
  int _charIndex = 0;
  Timer? _timer;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
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
    _charIndex = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_charIndex < widget.content.length) {
        setState(() {
          _charIndex++;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
              children: [
                Text(
                  _displayText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF333333),
                  ),
                ),
                // Breathing cursor
                if (widget.isStreaming && _charIndex < widget.content.length)
                  FadeTransition(
                    opacity: _breathingAnimation,
                    child: Container(
                      width: 2,
                      height: 16,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(1),
                      ),
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

/// 思考状态气泡 - 三个点呼吸动效
class ThinkingBubble extends StatefulWidget {
  final String botName;
  final String? botAvatar;

  const ThinkingBubble({
    super.key,
    required this.botName,
    this.botAvatar,
  });

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  // 三个点依次闪烁
                  final delay = index * 0.33;
                  final value = (_controller.value + delay) % 1.0;
                  final scale = 0.5 + (value < 0.5 ? value * 2 : (1 - value) * 2) * 0.5;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

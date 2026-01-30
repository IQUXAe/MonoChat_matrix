import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class TypingIndicatorBubble extends StatefulWidget {
  const TypingIndicatorBubble({super.key});

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.inputBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4), // Tail anchor
              bottomRight: Radius.circular(18),
            ),
          ),
          child: SizedBox(
            width: 40,
            height: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDot(0, palette.text),
                _buildDot(1, palette.text),
                _buildDot(2, palette.text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value + index * 0.2) % 1.0;
        final y = (1.0 - (1.0 - (t * 2 - 1).abs()).clamp(0.0, 1.0)) * 5;

        return Transform.translate(
          offset: Offset(0, -y + 2.5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

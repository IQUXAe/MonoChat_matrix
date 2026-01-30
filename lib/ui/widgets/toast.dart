import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Toast {
  static void show(BuildContext context, String message) {
    // Determine if we are in dark mode context
    final isDark =
        CupertinoTheme.of(context).brightness == Brightness.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, // Show at top, iOS style
        left: 16,
        right: 16,
        child: _ToastWidget(message: message, isDark: isDark),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), overlayEntry.remove);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isDark;

  const _ToastWidget({required this.message, required this.isDark});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(_animation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFFF2F2F7) // Light gray for dark text
                : const Color(0xFF333333), // Dark gray for light text
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.checkmark_alt,
                color: widget.isDark
                    ? CupertinoColors.black
                    : CupertinoColors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                // Prevent overflow
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.isDark
                        ? CupertinoColors.black
                        : CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration
                        .none, // Essential when not under Scaffold/Material
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

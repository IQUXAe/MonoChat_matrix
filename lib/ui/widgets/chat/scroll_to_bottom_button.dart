import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class ScrollToBottomButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int unreadCount;
  final bool visible;
  final double bottomOffset;

  const ScrollToBottomButton({
    super.key,
    required this.onPressed,
    required this.unreadCount,
    required this.visible,
    this.bottomOffset = 0,
  });

  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: widget.visible
          ? GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                widget.onPressed();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(_isPressed ? 0.9 : 1.0),
                alignment: Alignment.center,
                transformAlignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Glassmorphic Button
                    Container(
                      width: 48, // Slightly larger for better touch area
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: palette.barBackground.withValues(
                                alpha: 0.6,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.separator.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  palette.scaffoldBackground.withValues(
                                    alpha: 0.4,
                                  ),
                                  palette.scaffoldBackground.withValues(
                                    alpha: 0.1,
                                  ),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.chevron_down,
                                color: palette.primary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: BoxDecoration(
                            color: palette.primary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette.scaffoldBackground,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.unreadCount > 99
                                ? '99+'
                                : widget.unreadCount.toString(),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:monochat/controllers/theme_controller.dart';

import 'package:monochat/ui/screens/profile_screen.dart';
import 'package:monochat/ui/screens/room_list_screen.dart';
import 'package:monochat/ui/screens/settings_screen.dart';
import 'package:monochat/ui/widgets/nav_icons.dart';

// =============================================================================
// HOME SCREEN - Main Tab Navigation
// =============================================================================

/// Main screen with compact bottom tab navigation.
///
/// Features:
/// - Minimal icon-only tab bar (no text labels)
/// - Filled icons in iOS style
/// - Smooth cross-fade animations between tabs
/// - Compact 44pt height like modern iOS apps
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Page controller for smooth transitions
  late PageController _pageController;

  // Screens for each tab
  final List<Widget> _screens = const [
    RoomListScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false, // Allow content behind bar
      child: Stack(
        children: [
          // Page view with smooth transitions
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: _screens,
            ),
          ),

          // Custom compact tab bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CompactTabBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPACT TAB BAR
// =============================================================================

/// Minimal iOS-style tab bar with icon-only navigation.
class _CompactTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CompactTabBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final palette = context.watch<ThemeController>().palette;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          height: 44 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: palette.glassBackground,
            border: Border(
              top: BorderSide(
                color: palette.separator.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TabItem(
                onTap: () => onTap(0),
                child: NavIcons.home(
                  isSelected: currentIndex == 0,
                  color: currentIndex == 0
                      ? palette.primary
                      : palette.secondaryText,
                ),
              ),
              _TabItem(
                onTap: () => onTap(1),
                child: NavIcons.settings(
                  isSelected: currentIndex == 1,
                  color: currentIndex == 1
                      ? palette.primary
                      : palette.secondaryText,
                ),
              ),
              _TabItem(
                onTap: () => onTap(2),
                child: NavIcons.profile(
                  isSelected: currentIndex == 2,
                  color: currentIndex == 2
                      ? palette.primary
                      : palette.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB ITEM
// =============================================================================

/// Individual tab button with scale animation.
class _TabItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TabItem({required this.child, required this.onTap});

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 44,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(opacity: _opacityAnimation.value, child: child),
            );
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

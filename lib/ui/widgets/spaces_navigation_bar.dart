import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/space_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

// =============================================================================
// SPACES NAVIGATION BAR
// =============================================================================

/// Horizontal scrollable bar showing all spaces for quick navigation.
///
/// Features:
/// - "All Chats" item at the start
/// - Space avatars with unread badges
/// - "Create Space" button at the end
/// - Animated selection indicator
class SpacesNavigationBar extends StatelessWidget {
  final VoidCallback onCreateSpace;

  const SpacesNavigationBar({super.key, required this.onCreateSpace});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final client = context.watch<AuthController>().client;
    final spaceController = context.watch<SpaceController>();
    final l10n = AppLocalizations.of(context)!;

    if (client == null) return const SizedBox.shrink();

    final spaces = spaceController.spaces;
    final activeSpaceId = spaceController.activeSpaceId;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        border: Border(
          bottom: BorderSide(
            color: palette.separator.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: spaces.length + 2, // +1 for "All Chats", +1 for "Add"
        itemBuilder: (context, index) {
          if (index == 0) {
            // All Chats item
            return _SpaceItem(
              isSelected: activeSpaceId == null,
              onTap: spaceController.clearActiveSpace,
              label: l10n.allChats,
              icon: CupertinoIcons.chat_bubble_2_fill,
              palette: palette,
            );
          }

          if (index == spaces.length + 1) {
            // Create Space button
            return _SpaceItem(
              isSelected: false,
              onTap: onCreateSpace,
              label: l10n.add,
              icon: CupertinoIcons.add,
              palette: palette,
            );
          }

          final space = spaces[index - 1];
          final unreadCount = spaceController.getSpaceUnreadCount(space.id);

          return _SpaceAvatarItem(
            space: space,
            client: client,
            isSelected: activeSpaceId == space.id,
            unreadCount: unreadCount,
            onTap: () => spaceController.setActiveSpace(space.id),
            palette: palette,
          );
        },
      ),
    );
  }
}

// =============================================================================
// SPACE ITEM
// =============================================================================

class _SpaceItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final dynamic palette;

  const _SpaceItem({
    required this.isSelected,
    required this.onTap,
    required this.label,
    required this.icon,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? palette.primary : palette.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? palette.primary : palette.separator,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? CupertinoColors.white
                      : palette.secondaryText,
                ),
              ),
            ),
            const Gap(4),
            SizedBox(
              width: 50,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? palette.primary : palette.secondaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SPACE AVATAR ITEM
// =============================================================================

class _SpaceAvatarItem extends StatelessWidget {
  final Room space;
  final Client client;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;
  final dynamic palette;

  const _SpaceAvatarItem({
    required this.space,
    required this.client,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = space.getLocalizedDisplayname();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.separator,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 10 : 11),
                    child: MatrixAvatar(
                      avatarUrl: space.avatar,
                      name: displayName,
                      client: client,
                      size: isSelected ? 40 : 42,
                    ),
                  ),
                ),

                // Unread badge
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(4),
            SizedBox(
              width: 50,
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? palette.primary : palette.secondaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SPACES CHIP BAR
// =============================================================================

/// Alternative compact chip-style space filter bar.
class SpacesChipBar extends StatelessWidget {
  final VoidCallback onCreateSpace;

  const SpacesChipBar({super.key, required this.onCreateSpace});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final spaceController = context.watch<SpaceController>();
    final l10n = AppLocalizations.of(context)!;

    final spaces = spaceController.spaces;
    final activeSpaceId = spaceController.activeSpaceId;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: spaces.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SpaceChip(
                label: l10n.allChats,
                isSelected: activeSpaceId == null,
                onTap: spaceController.clearActiveSpace,
                palette: palette,
              ),
            );
          }

          if (index == spaces.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: onCreateSpace, minimumSize: const Size(32, 32),
                child: Icon(
                  CupertinoIcons.add_circled,
                  size: 22,
                  color: palette.primary,
                ),
              ),
            );
          }

          final space = spaces[index - 1];
          final unreadCount = spaceController.getSpaceUnreadCount(space.id);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SpaceChip(
              label: space.getLocalizedDisplayname(),
              isSelected: activeSpaceId == space.id,
              unreadCount: unreadCount,
              onTap: () => spaceController.setActiveSpace(space.id),
              palette: palette,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// SPACE CHIP
// =============================================================================

class _SpaceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;
  final dynamic palette;

  const _SpaceChip({
    required this.label,
    required this.isSelected,
    this.unreadCount = 0,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : palette.inputBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.primary : palette.separator,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? CupertinoColors.white : palette.text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (unreadCount > 0) ...[
              const Gap(6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CupertinoColors.white.withValues(alpha: 0.3)
                      : palette.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? CupertinoColors.white
                        : CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

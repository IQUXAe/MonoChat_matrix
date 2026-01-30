import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class ReactionPickerSheet extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const ReactionPickerSheet({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final palette = themeController.palette;

    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: palette.barBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                onEmojiSelected(emoji.emoji);
              },
              config: Config(
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.searchBar,
                  bottom: EmojiPickerItem.emojiView,
                ),
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: palette.barBackground,
                  columns: 7,
                  emojiSizeMax: 28,
                  noRecents: const Text('No Recents'),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: palette.barBackground,
                  indicatorColor: palette.primary,
                  iconColor: palette.secondaryText,
                  iconColorSelected: palette.primary,
                  backspaceColor: palette.primary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled:
                      false, // We use iOS style category bar at top usually, or let default
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: palette.barBackground,
                  buttonIconColor: palette.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

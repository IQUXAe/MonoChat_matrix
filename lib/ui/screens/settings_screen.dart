import 'package:flutter/cupertino.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/app_icon_service.dart';
import 'package:monochat/ui/screens/cache_settings_screen.dart';
import 'package:monochat/ui/screens/devices_screen.dart';
import 'package:monochat/ui/screens/notifications_screen.dart';
import 'package:monochat/ui/screens/security_settings_screen.dart';
import 'package:provider/provider.dart';

/// Settings screen with iOS-style grouped settings.
///
/// Follows Apple Human Interface Guidelines for settings layout:
/// - Grouped sections with headers
/// - Disclosure indicators for navigation
/// - Toggle switches for on/off settings
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final palette = themeController.palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.barBackground,
      child: CustomScrollView(
        slivers: [
          // Navigation bar
          CupertinoSliverNavigationBar(
            largeTitle: Text(_getLocalizedTitle(context)),
            backgroundColor: palette.barBackground,
            border: null,
          ),

          // Settings content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Appearance Section
                  _buildSectionHeader(context, 'APPEARANCE'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.moon_fill,
                        iconColor: CupertinoColors.systemIndigo,
                        title: 'Theme',
                        trailing: _SettingsValue(
                          value:
                              themeController.themeMode.name[0].toUpperCase() +
                              themeController.themeMode.name.substring(1),
                        ),
                        onTap: () => _showThemeSelector(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.textformat_size,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Text Size',
                        trailing: _SettingsValue(
                          value:
                              '${(themeController.textScale * 100).round()}%',
                        ),
                        onTap: () => _showTextSizeSheet(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.paintbrush_fill,
                        iconColor: CupertinoColors.systemPink,
                        title: 'Accent Color',
                        trailing: _SettingsValue(
                          value: '',
                          showChevron: true,
                          leading: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color:
                                  themeController.customPrimaryColor ??
                                  CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        onTap: () => _showAccentColorSheet(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.app_badge,
                        iconColor: CupertinoColors.systemOrange,
                        title: 'App Icon',
                        trailing: const _SettingsValue(
                          value: '',
                          showChevron: true,
                        ),
                        onTap: () => _showAppIconSheet(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Notifications Section
                  _buildSectionHeader(context, 'NOTIFICATIONS'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.bell_fill,
                        iconColor: CupertinoColors.systemRed,
                        title: 'Notifications',
                        trailing: const _SettingsValue(
                          value: '',
                          showChevron: true,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Privacy Section
                  _buildSectionHeader(context, 'PRIVACY & SECURITY'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.device_phone_portrait,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Devices',
                        onTap: () {
                          final client = context.read<AuthController>().client;
                          if (client != null) {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => DevicesScreen(client: client),
                              ),
                            );
                          }
                        },
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.lock_fill,
                        iconColor: CupertinoColors.systemGreen,
                        title: 'Security',
                        trailing: const _SettingsValue(value: ''),
                        onTap: () {
                          final client = context.read<AuthController>().client;
                          if (client != null) {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) =>
                                    SecuritySettingsScreen(client: client),
                              ),
                            );
                          }
                        },
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.eye_slash_fill,
                        iconColor: CupertinoColors.systemGrey,
                        title: 'Read Receipts',
                        trailing: const _SettingsValue(
                          value: 'On',
                        ), // Simplified for now
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.pencil_ellipsis_rectangle,
                        iconColor: CupertinoColors.systemTeal,
                        title: 'Typing Indicators',
                        trailing: const _SettingsValue(value: 'On'),
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Storage Section
                  _buildSectionHeader(context, 'STORAGE & DATA'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.arrow_down_circle_fill,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Media Auto-Download',
                        trailing: const _SettingsValue(value: 'Wi-Fi Only'),
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.photo_fill,
                        iconColor: CupertinoColors.systemYellow,
                        title: 'Image Quality',
                        trailing: const _SettingsValue(value: 'High'),
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.trash_fill,
                        iconColor: CupertinoColors.systemRed,
                        title: 'Storage Usage',
                        trailing: const _SettingsValue(
                          value: '',
                          showChevron: true,
                        ),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const CacheSettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // About Section
                  _buildSectionHeader(context, 'ABOUT'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      const _SettingsTile(
                        icon: CupertinoIcons.info_circle_fill,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Version',
                        trailing: _SettingsValue(
                          value: '1.0.0',
                          showChevron: false,
                        ),
                        onTap: null,
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: CupertinoColors.systemGrey,
                        title: 'Privacy Policy',
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.doc_plaintext,
                        iconColor: CupertinoColors.systemGrey,
                        title: 'Terms of Service',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedTitle(BuildContext context) {
    return AppLocalizations.of(context)?.settings ?? 'Settings';
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.watch<ThemeController>().palette.secondaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.watch<ThemeController>().palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Container(
                  height: 0.5,
                  color: context.read<ThemeController>().palette.separator,
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Theme'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeController>().setThemeMode(AppThemeMode.system);
              Navigator.pop(context);
            },
            child: const Text('System'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeController>().setThemeMode(AppThemeMode.light);
              Navigator.pop(context);
            },
            child: const Text('Light'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeController>().setThemeMode(AppThemeMode.dark);
              Navigator.pop(context);
            },
            child: const Text('Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTextSizeSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        final palette = context.watch<ThemeController>().palette;
        return Container(
          color: palette.barBackground,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Text Size',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<ThemeController>(
                      builder: (context, controller, _) {
                        return CupertinoSlider(
                          value: controller.textScale,
                          min: 0.8,
                          max: 1.4,
                          divisions: 6,
                          onChanged: (val) => controller.setTextScale(val),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'A',
                    style: TextStyle(fontSize: 24, color: palette.text),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showAccentColorSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        final palette = context.watch<ThemeController>().palette;
        final controller = context.read<ThemeController>();
        final colors = [
          (null, 'Default'),
          (CupertinoColors.activeBlue, 'Blue'),
          (CupertinoColors.activeGreen, 'Green'),
          (CupertinoColors.activeOrange, 'Orange'),
          (CupertinoColors.systemRed, 'Red'),
          (CupertinoColors.systemPurple, 'Purple'),
          (CupertinoColors.systemPink, 'Pink'),
          (CupertinoColors.systemTeal, 'Teal'),
          (CupertinoColors.systemIndigo, 'Indigo'),
        ];

        return Container(
          color: palette.barBackground,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Accent Color',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: colors.map((item) {
                  final color = item.$1;
                  final name = item.$2;
                  final isSelected =
                      controller.customPrimaryColor?.toARGB32() ==
                      color?.toARGB32();

                  // For display, if color is null (default), use activeBlue but maybe with an icon or border
                  final displayColor = color ?? CupertinoColors.activeBlue;

                  return GestureDetector(
                    onTap: () {
                      controller.setPrimaryColor(color);
                      // Navigator.pop(context); // Optional: keep open to see change or close
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: displayColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: palette.text, width: 3)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.black.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected && color == null
                              ? const Icon(
                                  CupertinoIcons.checkmark,
                                  color: CupertinoColors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showAppIconSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('App Icon'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              AppIconService().setLightIcon();
              Navigator.pop(context);
            },
            child: const Text('Light (Default)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              AppIconService().setDarkIcon();
              Navigator.pop(context);
            },
            child: const Text('Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// =============================================================================
// SETTINGS TILE WIDGETS
// =============================================================================

/// Standard settings tile with icon and optional trailing widget.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon with colored background
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: CupertinoColors.white),
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: context.watch<ThemeController>().palette.text,
                ),
              ),
            ),

            // Trailing
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Settings value with optional chevron.
class _SettingsValue extends StatelessWidget {
  final String value;
  final bool showChevron;
  final Widget? leading;

  const _SettingsValue({
    required this.value,
    this.showChevron = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            color: context.watch<ThemeController>().palette.secondaryText,
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: context.watch<ThemeController>().palette.secondaryText,
          ),
        ],
      ],
    );
  }
}

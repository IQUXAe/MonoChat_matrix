import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For some icons if needed? No, sticking to Cupertino
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/app_icon_service.dart';
import 'package:monochat/ui/screens/cache_settings_screen.dart';
import 'package:monochat/ui/screens/devices_screen.dart';
import 'package:monochat/ui/screens/notifications_screen.dart';
import 'package:monochat/ui/screens/profile_screen.dart';
import 'package:monochat/ui/screens/security_settings_screen.dart';
import 'package:monochat/ui/theme/app_palette.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final palette = themeController.palette;
    final l10n = AppLocalizations.of(context)!;
    final client = context.watch<AuthController>().client;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground, // More standard background
      child: CustomScrollView(
        slivers: [
          // 1. Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: Text(l10n.settings),
            backgroundColor: palette.barBackground,
            border: Border(
              bottom: BorderSide(
                color: palette.separator.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),

          // 2. Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search settings',
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(color: palette.text),
                placeholderStyle: TextStyle(
                  color: palette.secondaryText.withValues(alpha: 0.7),
                ),
                backgroundColor: palette.inputBackground,
              ),
            ),
          ),

          // 3. Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Section (Only visible if not searching or matches 'Profile')
                if (_shouldShow('Profile')) ...[
                  _buildProfileSection(context, client, palette),
                  const SizedBox(height: 20),
                ],

                // Appearance
                if (_shouldShow('Appearance Theme Color Icon Text')) ...[
                  _buildSectionHeader(context, 'APPEARANCE'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.moon_fill,
                        iconColor: CupertinoColors.systemIndigo,
                        title: 'Theme',
                        value:
                            themeController.themeMode.name[0].toUpperCase() +
                            themeController.themeMode.name.substring(1),
                        onTap: () => _showThemeSelector(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.paintbrush_fill,
                        iconColor: CupertinoColors.systemPink,
                        title: 'Accent Color',
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                themeController.customPrimaryColor ??
                                CupertinoColors.activeBlue,
                            border: Border.all(
                              color: palette.separator,
                              width: 1,
                            ),
                          ),
                        ),
                        onTap: () => _showAccentColorSheet(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.textformat_size,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Text Size',
                        value: '${(themeController.textScale * 100).round()}%',
                        onTap: () => _showTextSizeSheet(context),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.app_badge_fill,
                        iconColor: CupertinoColors.systemOrange,
                        title: 'App Icon',
                        onTap: () => _showAppIconSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // General & Chats
                if (_shouldShow(
                  'Chats Notifications Notifications Sound Privacy Security',
                )) ...[
                  _buildSectionHeader(context, 'GENERAL'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.bell_fill,
                        iconColor: CupertinoColors.systemRed,
                        title: 'Notifications',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.lock_fill,
                        iconColor: CupertinoColors.systemGreen,
                        title: 'Privacy & Security',
                        onTap: () {
                          if (client != null) {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    SecuritySettingsScreen(client: client),
                              ),
                            );
                          }
                        },
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.device_phone_portrait,
                        iconColor: CupertinoColors.systemTeal,
                        title: 'Devices',
                        onTap: () {
                          if (client != null) {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => DevicesScreen(client: client),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Data & Storage
                if (_shouldShow('Storage Data Cache Media')) ...[
                  _buildSectionHeader(context, 'DATA & STORAGE'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      _SettingsTile(
                        icon: CupertinoIcons.arrow_down_circle_fill,
                        iconColor: CupertinoColors.systemBlue,
                        title: 'Media Auto-Download',
                        value: 'Wi-Fi Only',
                        onTap: () {
                          // TODO: Implement Media Settings
                        },
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.chart_pie_fill,
                        iconColor: CupertinoColors.systemYellow,
                        title: 'Storage Usage',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const CacheSettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // About
                if (_shouldShow(
                  'About Version Help Support Terms Privacy',
                )) ...[
                  _buildSectionHeader(context, 'ABOUT'),
                  _buildSettingsGroup(
                    context,
                    children: [
                      const _SettingsTile(
                        icon: CupertinoIcons.info_circle_fill,
                        iconColor: CupertinoColors.systemGrey,
                        title: 'Version',
                        value: '1.0.0 (Beta)',
                        showChevron: false,
                      ),
                      _SettingsTile(
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: CupertinoColors.systemGrey,
                        title: 'Privacy Policy',
                        onTap: () {
                          // TODO: Open Privacy Policy
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShow(String keywords) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final words = keywords.toLowerCase().split(' ');
    return words.any((w) => w.contains(query));
  }

  Widget _buildProfileSection(
    BuildContext context,
    client,
    AppPalette palette,
  ) {
    if (client == null) return const SizedBox.shrink();

    return FutureBuilder<Profile>(
      future: client.fetchOwnProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.displayName ?? client.userID ?? 'User';
        final avatarUrl = profile?.avatarUrl;

        return GestureDetector(
          onTap: () {
            Navigator.of(
              context,
            ).push(CupertinoPageRoute(builder: (_) => const ProfileScreen()));
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.inputBackground, // Slightly distinct background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.separator.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                MatrixAvatar(
                  avatarUrl: avatarUrl,
                  name: displayName,
                  client: client,
                  size: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client.userID ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: palette.secondaryText.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8),
      child: wFull(
        // Helper to stretch width
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.watch<ThemeController>().palette.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget wFull({required Widget child}) {
    return SizedBox(width: double.infinity, child: child);
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final palette = context.watch<ThemeController>().palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.inputBackground, // Card-like background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 56, // Align with text start
                color: palette.separator.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }

  // ... (Keep existing connector methods like _showThemeSelector, _showTextSizeSheet, etc.)
  // I will copy them into the new file content below.

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

                  final displayColor = color ?? CupertinoColors.activeBlue;

                  return GestureDetector(
                    onTap: () {
                      controller.setPrimaryColor(color);
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
// HELPER WIDGETS
// =============================================================================

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8), // More squared rounded
              ),
              child: Icon(icon, size: 18, color: CupertinoColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: palette.text,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(fontSize: 17, color: palette.secondaryText),
              ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16, // Slightly smaller chevron
                color: palette.secondaryText.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

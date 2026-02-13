library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Colors (if needed fallback)
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/config/app_config.dart';
import 'package:monochat/controllers/notification_settings_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/ui/widgets/settings_tile.dart';
import 'package:monochat/utils/push_rule_extensions.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationSettingsController _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final client = context.read<MatrixService>().client;
      if (client != null) {
        _controller = NotificationSettingsController(client);
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _NotLoggedInView();
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return _NotificationsView(controller: _controller);
      },
    );
  }
}

class _NotLoggedInView extends StatelessWidget {
  const _NotLoggedInView();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.notifications),
        backgroundColor: theme.barBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.separator.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          'Please log in to configure notifications',
          style: TextStyle(color: theme.secondaryText),
        ),
      ),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  final NotificationSettingsController controller;

  const _NotificationsView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.notifications),
        backgroundColor: theme.barBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.separator.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        trailing: state.isLoading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: controller.refresh,
                child: const Icon(CupertinoIcons.refresh),
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: state.isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // UNIFIED PUSH STATUS
                        _buildSectionHeader(context, 'UNIFIED PUSH'),
                        _buildSettingsGroup(
                          context,
                          children: [
                            // Status tile with health indicator
                            _PushStatusTile(state: state),

                            SettingsTile(
                              icon: CupertinoIcons.cloud_upload_fill,
                              iconColor: CupertinoColors.systemBlue,
                              title: l10n.pushDistributor,
                              value: state.upDistributor ?? l10n.noneSelected,
                              onTap: controller.registerUnifiedPush,
                            ),

                            // Show endpoint info if registered
                            if (state.upRegistered && state.upEndpoint != null)
                              _EndpointInfoTile(state: state),

                            // Last push received
                            if (state.upRegistered &&
                                state.lastPushReceived != null)
                              _LastPushTile(lastPush: state.lastPushReceived!),

                            if (state.upRegistered)
                              SettingsTile(
                                icon: CupertinoIcons.delete,
                                iconColor: CupertinoColors.destructiveRed,
                                title: l10n.unregisterPush,
                                titleColor: CupertinoColors.destructiveRed,
                                onTap: () => _confirmUnregister(context),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onTap: _openPushTutorial,
                            child: Text(
                              l10n.learnMoreAboutUnifiedPush,
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (state.pushRules != null) ...[
                          // MASTER SWITCH
                          _buildSettingsGroup(
                            context,
                            children: [
                              _MasterSwitchTile(controller: controller),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // IMPORTANT RULES
                          _buildSectionHeader(
                            context,
                            l10n.importantNotifications.toUpperCase(),
                          ),
                          _buildSettingsGroup(
                            context,
                            children: _buildRuleTiles(
                              context,
                              _getImportantRules(state.pushRules!),
                              controller,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ADVANCED RULES
                          _buildSectionHeader(
                            context,
                            l10n.advancedNotifications.toUpperCase(),
                          ),
                          _buildSettingsGroup(
                            context,
                            children: _buildRuleTiles(
                              context,
                              _getAdvancedRules(state.pushRules!),
                              controller,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // REGISTERED DEVICES
                        _buildSectionHeader(
                          context,
                          l10n.registeredDevices.toUpperCase(),
                        ),
                        if (state.pushers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.noRegisteredDevices,
                              style: TextStyle(color: theme.secondaryText),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          _buildSettingsGroup(
                            context,
                            children: _buildPusherTiles(context, state.pushers),
                          ),
                        const SizedBox(height: 24),

                        // TROUBLESHOOTING
                        _buildSectionHeader(
                          context,
                          l10n.troubleshooting.toUpperCase(),
                        ),
                        _buildSettingsGroup(
                          context,
                          children: [
                            SettingsTile(
                              icon: CupertinoIcons.bell_fill,
                              iconColor: CupertinoColors.systemIndigo,
                              title: l10n.sendTestNotification,
                              onTap: () => _sendTestNotification(context),
                            ),
                            SettingsTile(
                              icon: CupertinoIcons.doc_on_clipboard_fill,
                              iconColor: CupertinoColors.systemGrey,
                              title: l10n.copyPushEndpoint,
                              onTap: () => _copyEndpoint(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8),
      child: SizedBox(
        width: double.infinity,
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

  Widget _buildSettingsGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final palette = context.watch<ThemeController>().palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.inputBackground,
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
                indent: 56,
                color: palette.separator.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }

  void _confirmUnregister(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.unregisterPush),
        content: Text(l10n.unregisterPushConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              controller.unregisterUnifiedPush();
            },
            child: Text(l10n.unregister),
          ),
        ],
      ),
    );
  }

  void _openPushTutorial() {
    launchUrl(
      Uri.parse(AppConfig.enablePushTutorial),
      mode: LaunchMode.externalApplication,
    );
  }

  List<({PushRule rule, PushRuleKind kind})> _getImportantRules(
    PushRuleSet rules,
  ) {
    final important = <String>[
      '.m.rule.is_user_mention',
      '.m.rule.contains_display_name',
      '.m.rule.room_one_to_one',
      '.m.rule.encrypted_room_one_to_one',
      '.m.rule.message',
      '.m.rule.encrypted',
      '.m.rule.invite_for_me',
      '.m.rule.call',
    ];
    return _filterRules(rules, important);
  }

  List<({PushRule rule, PushRuleKind kind})> _getAdvancedRules(
    PushRuleSet rules,
  ) {
    final advanced = <String>[
      '.m.rule.suppress_notices',
      '.m.rule.member_event',
      '.m.rule.is_room_mention',
      '.m.rule.reaction',
      '.m.rule.suppress_edits',
      '.m.rule.tombstone',
    ];
    return _filterRules(rules, advanced);
  }

  List<({PushRule rule, PushRuleKind kind})> _filterRules(
    PushRuleSet rules,
    List<String> ruleIds,
  ) {
    final result = <({PushRule rule, PushRuleKind kind})>[];
    for (final ruleId in ruleIds) {
      // Check override rules
      PushRule? overrideRule;
      try {
        overrideRule = rules.override?.firstWhere((r) => r.ruleId == ruleId);
      } catch (_) {
        overrideRule = null;
      }
      if (overrideRule != null && overrideRule.ruleId == ruleId) {
        result.add((rule: overrideRule, kind: PushRuleKind.override));
        continue;
      }
      // Check underride
      PushRule? underrideRule;
      try {
        underrideRule = rules.underride?.firstWhere((r) => r.ruleId == ruleId);
      } catch (_) {
        underrideRule = null;
      }
      if (underrideRule != null && underrideRule.ruleId == ruleId) {
        result.add((rule: underrideRule, kind: PushRuleKind.underride));
        continue;
      }
      // Check content
      PushRule? contentRule;
      try {
        contentRule = rules.content?.firstWhere((r) => r.ruleId == ruleId);
      } catch (_) {
        contentRule = null;
      }
      if (contentRule != null && contentRule.ruleId == ruleId) {
        result.add((rule: contentRule, kind: PushRuleKind.content));
      }
    }
    return result;
  }

  List<Widget> _buildRuleTiles(
    BuildContext context,
    List<({PushRule rule, PushRuleKind kind})> rules,
    NotificationSettingsController controller,
  ) {
    final tiles = <Widget>[];
    for (var i = 0; i < rules.length; i++) {
      tiles.add(
        _PushRuleTile(
          rule: rules[i].rule,
          kind: rules[i].kind,
          controller: controller,
        ),
      );
    }
    return tiles;
  }

  List<Widget> _buildPusherTiles(BuildContext context, List<Pusher> pushers) {
    final tiles = <Widget>[];
    for (var i = 0; i < pushers.length; i++) {
      tiles.add(_PusherTile(pusher: pushers[i], controller: controller));
    }
    return tiles;
  }

  void _copyEndpoint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;
    if (state.upEndpoint != null) {
      Clipboard.setData(ClipboardData(text: state.upEndpoint!));
    }
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Copied to clipboard'),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _sendTestNotification(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Show local notification
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'test_channel_id',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification',
      'This is a test notification from MonoChat',
      details,
    );

    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.testNotificationSent),
          actions: [
            CupertinoDialogAction(
              child: Text(l10n.ok),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }
}

/// Shows the push connection status with a color-coded health indicator
class _PushStatusTile extends StatelessWidget {
  final NotificationSettingsState state;

  const _PushStatusTile({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;

    final IconData icon;
    final Color iconColor;
    final String statusText;

    if (!state.upRegistered) {
      icon = CupertinoIcons.exclamationmark_circle_fill;
      iconColor = CupertinoColors.systemOrange;
      statusText = l10n.notConnected;
    } else {
      final healthy = state.isPushHealthy;
      if (healthy == null) {
        // Registered but no health data yet
        icon = CupertinoIcons.checkmark_circle_fill;
        iconColor = CupertinoColors.activeGreen;
        statusText = l10n.connected;
      } else if (healthy) {
        icon = CupertinoIcons.checkmark_circle_fill;
        iconColor = CupertinoColors.activeGreen;
        statusText = l10n.connected;
      } else {
        // Registered but stale
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        iconColor = CupertinoColors.systemYellow;
        statusText = l10n.pushStatusStale;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: CupertinoColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pushStatus,
                  style: TextStyle(
                    fontSize: 17,
                    color: theme.text,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          // Pulsating dot for active connection
          if (state.upRegistered)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows a truncated endpoint with copy-on-tap
class _EndpointInfoTile extends StatelessWidget {
  final NotificationSettingsState state;

  const _EndpointInfoTile({required this.state});

  @override
  Widget build(BuildContext context) {
    final endpoint = state.upEndpoint ?? '';
    // Truncate for display: show scheme + host + "..."
    String displayEndpoint;
    try {
      final uri = Uri.parse(endpoint);
      displayEndpoint = '${uri.scheme}://${uri.host}/...';
    } catch (_) {
      displayEndpoint = endpoint.length > 40
          ? '${endpoint.substring(0, 40)}...'
          : endpoint;
    }

    return SettingsTile(
      icon: CupertinoIcons.link,
      iconColor: CupertinoColors.systemTeal,
      title: 'Endpoint',
      value: displayEndpoint,
      onTap: () {
        Clipboard.setData(ClipboardData(text: endpoint));
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Endpoint copied'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows when the last push was received with relative time
class _LastPushTile extends StatelessWidget {
  final DateTime lastPush;

  const _LastPushTile({required this.lastPush});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: CupertinoIcons.clock_fill,
      iconColor: CupertinoColors.systemGrey,
      title: 'Last push received',
      value: _formatRelativeTime(lastPush),
      showChevron: false,
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}.${time.month}.${time.year}';
  }
}

class _MasterSwitchTile extends StatelessWidget {
  final NotificationSettingsController controller;
  const _MasterSwitchTile({required this.controller});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final allMuted = controller.allNotificationsMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: allMuted ? CupertinoColors.systemOrange : theme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              allMuted
                  ? CupertinoIcons.bell_slash_fill
                  : CupertinoIcons.bell_fill,
              size: 18,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.muteAllNotifications,
                  style: TextStyle(
                    fontSize: 17,
                    color: theme.text,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  allMuted
                      ? l10n.allNotificationsMuted
                      : l10n.notificationsEnabled,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: allMuted,
            onChanged: controller.state.isUpdatingRule
                ? null
                : (value) => _toggleMasterRule(context),
          ),
        ],
      ),
    );
  }

  void _toggleMasterRule(BuildContext context) {
    final rules = controller.state.pushRules;
    PushRule? masterRule;
    try {
      masterRule = rules?.override?.firstWhere(
        (r) => r.ruleId == '.m.rule.master',
      );
    } catch (_) {
      masterRule = null;
    }
    if (masterRule != null) {
      controller.togglePushRule(PushRuleKind.override, masterRule);
    }
  }
}

class _PushRuleTile extends StatelessWidget {
  final PushRule rule;
  final PushRuleKind kind;
  final NotificationSettingsController controller;

  const _PushRuleTile({
    required this.rule,
    required this.kind,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final isDisabled =
        controller.allNotificationsMuted && rule.ruleId != '.m.rule.master';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.getPushRuleName(l10n),
                  style: TextStyle(
                    fontSize: 17,
                    color: isDisabled
                        ? theme.secondaryText
                        : theme.text, // Dim if disabled
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  rule.getPushRuleDescription(l10n),
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: rule.enabled,
            onChanged: controller.state.isUpdatingRule || isDisabled
                ? null
                : (_) => controller.togglePushRule(kind, rule),
          ),
        ],
      ),
    );
  }
}

class _PusherTile extends StatelessWidget {
  final Pusher pusher;
  final NotificationSettingsController controller;

  const _PusherTile({required this.pusher, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return SettingsTile(
      icon: CupertinoIcons.device_phone_portrait,
      iconColor: theme.secondaryText,
      title: pusher.deviceDisplayName,
      value: null,
      onTap: () => _showPusherOptions(context),
    );
  }

  void _showPusherOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(pusher.deviceDisplayName),
        message: Text('${pusher.appDisplayName}\n${pusher.appId}'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context);
            },
            child: Text(l10n.removePusher),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.removePusher),
        content: Text(l10n.removePusherConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              controller.deletePusher(pusher);
            },
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
  }
}

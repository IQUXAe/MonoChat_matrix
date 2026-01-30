/// Notifications settings screen
///
/// Provides comprehensive push notification settings including:
/// - UnifiedPush connection status and management
/// - Matrix push rules configuration
/// - Registered devices (pushers) management
/// - Troubleshooting tools
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/config/app_config.dart';
import 'package:monochat/controllers/notification_settings_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
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

/// View when user is not logged in
class _NotLoggedInView extends StatelessWidget {
  const _NotLoggedInView();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: theme.barBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.notifications, style: TextStyle(color: theme.text)),
        backgroundColor: theme.barBackground,
        border: null,
      ),
      child: SafeArea(
        child: Center(
          child: Text(
            'Please log in to configure notifications',
            style: TextStyle(color: theme.secondaryText),
          ),
        ),
      ),
    );
  }
}

/// Main notifications settings view
class _NotificationsView extends StatelessWidget {
  final NotificationSettingsController controller;

  const _NotificationsView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;

    return CupertinoPageScaffold(
      backgroundColor: theme.barBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.notifications, style: TextStyle(color: theme.text)),
        backgroundColor: theme.barBackground,
        border: null,
        trailing: state.isLoading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: controller.refresh,
                child: const Icon(CupertinoIcons.refresh),
              ),
      ),
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // UnifiedPush Status Section
                        _UnifiedPushSection(controller: controller),

                        const SizedBox(height: 24),

                        // Push Rules Section
                        _PushRulesSection(controller: controller),

                        const SizedBox(height: 24),

                        // Registered Devices Section
                        _PushersSection(controller: controller),

                        const SizedBox(height: 24),

                        // Troubleshooting Section
                        _TroubleshootingSection(controller: controller),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// UNIFIED PUSH SECTION
// =============================================================================

class _UnifiedPushSection extends StatelessWidget {
  final NotificationSettingsController controller;

  const _UnifiedPushSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.pushProvider.toUpperCase()),
        _SettingsCard(
          children: [
            // Status row
            _StatusTile(
              title: l10n.pushStatus,
              value: state.upRegistered ? l10n.connected : l10n.notConnected,
              valueColor: state.upRegistered
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemOrange,
              icon: state.upRegistered
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.exclamationmark_circle_fill,
            ),

            _Divider(),

            // Current distributor
            _StatusTile(
              title: l10n.pushDistributor,
              value: state.upDistributor ?? l10n.noneSelected,
              valueColor: state.upDistributor != null
                  ? theme.text
                  : theme.secondaryText,
            ),

            if (state.upEndpoint != null) ...[
              _Divider(),
              _StatusTile(
                title: l10n.pushEndpoint,
                value: _truncateEndpoint(state.upEndpoint!),
                valueColor: theme.secondaryText,
              ),
            ],

            _Divider(),

            // Select distributor button
            _ActionTile(
              title: l10n.selectPushDistributor,
              icon: CupertinoIcons.chevron_right,
              onTap: controller.registerUnifiedPush,
            ),

            if (state.upRegistered) ...[
              _Divider(),
              _ActionTile(
                title: l10n.unregisterPush,
                titleColor: CupertinoColors.destructiveRed,
                onTap: () => _confirmUnregister(context),
              ),
            ],
          ],
        ),

        // Info text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Text(
            l10n.pushInfoText,
            style: TextStyle(color: theme.secondaryText, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),

        // Learn more link
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: GestureDetector(
            onTap: _openPushTutorial,
            child: Text(
              l10n.learnMoreAboutUnifiedPush,
              style: TextStyle(
                color: theme.primary,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  String _truncateEndpoint(String endpoint) {
    if (endpoint.length <= 50) return endpoint;
    return '${endpoint.substring(0, 47)}...';
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
}

// =============================================================================
// PUSH RULES SECTION
// =============================================================================

class _PushRulesSection extends StatelessWidget {
  final NotificationSettingsController controller;

  const _PushRulesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;
    final pushRules = state.pushRules;

    if (pushRules == null) {
      return const SizedBox.shrink();
    }

    // Group rules by importance for better UX
    final importantRules = _getImportantRules(pushRules);
    final advancedRules = _getAdvancedRules(pushRules);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.notificationRules.toUpperCase()),

        // Master switch (mute all)
        _SettingsCard(children: [_MasterSwitchTile(controller: controller)]),

        const SizedBox(height: 16),

        // Important notification rules
        _SectionHeader(title: l10n.importantNotifications.toUpperCase()),
        _SettingsCard(
          children: _buildRuleTiles(context, importantRules, controller),
        ),

        const SizedBox(height: 16),

        // Advanced notification rules
        _SectionHeader(title: l10n.advancedNotifications.toUpperCase()),
        _SettingsCard(
          children: _buildRuleTiles(context, advancedRules, controller),
        ),
      ],
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

      // Check underride rules
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

      // Check content rules
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
      if (i > 0) tiles.add(_Divider());
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
}

class _MasterSwitchTile extends StatelessWidget {
  final NotificationSettingsController controller;

  const _MasterSwitchTile({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final allMuted = controller.allNotificationsMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            allMuted
                ? CupertinoIcons.bell_slash_fill
                : CupertinoIcons.bell_fill,
            color: allMuted ? CupertinoColors.systemOrange : theme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.muteAllNotifications,
                  style: TextStyle(fontSize: 17, color: theme.text),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.getPushRuleName(l10n),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDisabled ? theme.secondaryText : theme.text,
                  ),
                ),
                const SizedBox(height: 2),
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

// =============================================================================
// PUSHERS (REGISTERED DEVICES) SECTION
// =============================================================================

class _PushersSection extends StatelessWidget {
  final NotificationSettingsController controller;

  const _PushersSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.registeredDevices.toUpperCase()),

        if (state.isLoadingPushers)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (state.pushers.isEmpty)
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    l10n.noRegisteredDevices,
                    style: TextStyle(color: theme.secondaryText),
                  ),
                ),
              ),
            ],
          )
        else
          _SettingsCard(children: _buildPusherTiles(context, state.pushers)),
      ],
    );
  }

  List<Widget> _buildPusherTiles(BuildContext context, List<Pusher> pushers) {
    final tiles = <Widget>[];

    for (var i = 0; i < pushers.length; i++) {
      if (i > 0) tiles.add(_Divider());
      tiles.add(_PusherTile(pusher: pushers[i], controller: controller));
    }

    return tiles;
  }
}

class _PusherTile extends StatelessWidget {
  final Pusher pusher;
  final NotificationSettingsController controller;

  const _PusherTile({required this.pusher, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return GestureDetector(
      onTap: () => _showPusherOptions(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.device_phone_portrait,
                color: theme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pusher.deviceDisplayName,
                    style: TextStyle(fontSize: 16, color: theme.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pusher.appId,
                    style: TextStyle(fontSize: 13, color: theme.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
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

// =============================================================================
// TROUBLESHOOTING SECTION
// =============================================================================

class _TroubleshootingSection extends StatelessWidget {
  final NotificationSettingsController controller;

  const _TroubleshootingSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.troubleshooting.toUpperCase()),
        _SettingsCard(
          children: [
            _ActionTile(
              title: l10n.sendTestNotification,
              icon: CupertinoIcons.bell,
              onTap: () => _sendTestNotification(context),
            ),
            _Divider(),
            _ActionTile(
              title: l10n.copyPushEndpoint,
              icon: CupertinoIcons.doc_on_clipboard,
              onTap: () => _copyEndpoint(context),
            ),
            _Divider(),
            _ActionTile(
              title: l10n.refreshPushStatus,
              icon: CupertinoIcons.refresh,
              onTap: controller.refresh,
            ),
          ],
        ),
      ],
    );
  }

  void _sendTestNotification(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Show confirmation dialog
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

  void _copyEndpoint(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final endpoint = controller.state.upEndpoint;

    if (endpoint != null) {
      await Clipboard.setData(ClipboardData(text: endpoint));
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(l10n.endpointCopied),
            content: Text(endpoint),
            actions: [
              CupertinoDialogAction(
                child: Text(l10n.ok),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } else {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.noEndpoint),
          content: Text(l10n.noEndpointMessage),
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

// =============================================================================
// REUSABLE WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.secondaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(height: 0.5, color: theme.separator),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const _StatusTile({
    required this.title,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: valueColor, size: 20),
            const SizedBox(width: 12),
          ],
          Text(title, style: TextStyle(fontSize: 17, color: theme.text)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? theme.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.title,
    this.titleColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 17, color: titleColor ?? theme.text),
              ),
            ),
            if (icon != null)
              Icon(icon, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }
}

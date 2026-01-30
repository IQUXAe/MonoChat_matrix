/// Push rule extensions for localization and display
///

library;

import 'package:matrix/matrix.dart';

import 'package:monochat/l10n/generated/app_localizations.dart';

/// Extension to get localized names and descriptions for push rules
extension PushRuleExtension on PushRule {
  /// Get a human-readable name for this push rule
  String getPushRuleName(AppLocalizations l10n) {
    switch (ruleId) {
      case '.m.rule.master':
        return l10n.pushRuleMaster;
      case '.m.rule.suppress_notices':
        return l10n.pushRuleSuppressNotices;
      case '.m.rule.invite_for_me':
        return l10n.pushRuleInviteForMe;
      case '.m.rule.member_event':
        return l10n.pushRuleMemberEvent;
      case '.m.rule.is_user_mention':
        return l10n.pushRuleUserMention;
      case '.m.rule.contains_display_name':
        return l10n.pushRuleContainsDisplayName;
      case '.m.rule.is_room_mention':
        return l10n.pushRuleRoomMention;
      case '.m.rule.roomnotif':
        return l10n.pushRuleRoomNotif;
      case '.m.rule.tombstone':
        return l10n.pushRuleTombstone;
      case '.m.rule.reaction':
        return l10n.pushRuleReaction;
      case '.m.rule.suppress_edits':
        return l10n.pushRuleSuppressEdits;
      case '.m.rule.call':
        return l10n.pushRuleCall;
      case '.m.rule.encrypted_room_one_to_one':
        return l10n.pushRuleEncryptedDM;
      case '.m.rule.room_one_to_one':
        return l10n.pushRuleDM;
      case '.m.rule.message':
        return l10n.pushRuleGroupMessage;
      case '.m.rule.encrypted':
        return l10n.pushRuleEncryptedGroup;
      case '.m.rule.contains_user_name':
        return l10n.pushRuleContainsUserName;
      default:
        return _formatRuleId(ruleId);
    }
  }

  /// Get a description for this push rule
  String getPushRuleDescription(AppLocalizations l10n) {
    switch (ruleId) {
      case '.m.rule.master':
        return l10n.pushRuleMasterDesc;
      case '.m.rule.suppress_notices':
        return l10n.pushRuleSuppressNoticesDesc;
      case '.m.rule.invite_for_me':
        return l10n.pushRuleInviteForMeDesc;
      case '.m.rule.member_event':
        return l10n.pushRuleMemberEventDesc;
      case '.m.rule.is_user_mention':
        return l10n.pushRuleUserMentionDesc;
      case '.m.rule.contains_display_name':
        return l10n.pushRuleContainsDisplayNameDesc;
      case '.m.rule.is_room_mention':
        return l10n.pushRuleRoomMentionDesc;
      case '.m.rule.roomnotif':
        return l10n.pushRuleRoomNotifDesc;
      case '.m.rule.tombstone':
        return l10n.pushRuleTombstoneDesc;
      case '.m.rule.reaction':
        return l10n.pushRuleReactionDesc;
      case '.m.rule.suppress_edits':
        return l10n.pushRuleSuppressEditsDesc;
      case '.m.rule.call':
        return l10n.pushRuleCallDesc;
      case '.m.rule.encrypted_room_one_to_one':
        return l10n.pushRuleEncryptedDMDesc;
      case '.m.rule.room_one_to_one':
        return l10n.pushRuleDMDesc;
      case '.m.rule.message':
        return l10n.pushRuleGroupMessageDesc;
      case '.m.rule.encrypted':
        return l10n.pushRuleEncryptedGroupDesc;
      case '.m.rule.contains_user_name':
        return l10n.pushRuleContainsUserNameDesc;
      default:
        return l10n.pushRuleCustom;
    }
  }

  /// Format rule ID for display when no localization is available
  String _formatRuleId(String ruleId) {
    final parts = ruleId.split('.');
    final name = parts.isNotEmpty ? parts.last : ruleId;
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }
}

/// Extension to get localized names for push rule kinds
extension PushRuleKindExtension on PushRuleKind {
  String getLocalizedName(AppLocalizations l10n) {
    switch (this) {
      case PushRuleKind.override:
        return l10n.pushRuleCategoryOverride;
      case PushRuleKind.content:
        return l10n.pushRuleCategoryContent;
      case PushRuleKind.room:
        return l10n.pushRuleCategoryRoom;
      case PushRuleKind.sender:
        return l10n.pushRuleCategorySender;
      case PushRuleKind.underride:
        return l10n.pushRuleCategoryUnderride;
    }
  }
}

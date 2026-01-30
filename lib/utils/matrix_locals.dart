import 'package:matrix/matrix.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';

class MatrixLocals extends MatrixLocalizations {
  final AppLocalizations l10n;

  MatrixLocals(this.l10n);

  @override
  String get anyoneCanJoin => 'Anyone can join';

  @override
  String get guestsAreForbidden => 'Guests are forbidden';

  @override
  String get guestsCanJoin => 'Guests can join';

  @override
  String get invitedUsersOnly => 'Invited users only';

  @override
  String get noPermission => 'No permission';

  @override
  String get visibleForAllParticipants => 'Visible for all participants';

  @override
  String get visibleForEveryone => 'Visible for everyone';

  @override
  String get you => l10n.you;

  @override
  String get emptyChat => 'Empty chat';

  @override
  String get encryptionNotEnabled => 'Encryption not enabled';

  @override
  String get needPantalaimonWarning => 'Need Pantalaimon';

  @override
  String get roomHasBeenUpgraded => 'Room has been upgraded';

  @override
  String get unknownEncryptionAlgorithm => 'Unknown encryption algorithm';

  @override
  String get fromJoining => 'from joining';

  @override
  String get fromTheInvitation => 'from the invitation';

  @override
  String get channelCorruptedDecryptError =>
      'The encryption channel is corrupted';

  @override
  String acceptedTheInvitation(String targetName) =>
      '$targetName accepted the invitation';

  @override
  String activatedEndToEndEncryption(String senderName) =>
      '$senderName activated end-to-end encryption';

  @override
  String answeredTheCall(String senderName) => '$senderName answered the call';

  @override
  String bannedUser(String senderName, String targetName) =>
      '$senderName banned $targetName';

  @override
  String changedTheChatAvatar(String senderName) =>
      '$senderName changed the chat avatar';

  @override
  String changedTheChatDescriptionTo(String senderName, String description) =>
      '$senderName changed the chat description';

  @override
  String changedTheChatNameTo(String senderName, String chatName) =>
      '$senderName changed the chat name to $chatName';

  @override
  String changedTheChatPermissions(String senderName) =>
      '$senderName changed the chat permissions';

  @override
  String changedTheDisplaynameTo(String targetName, String newDisplayname) =>
      '$targetName changed their display name to $newDisplayname';

  @override
  String changedTheGuestAccessRules(String senderName) =>
      '$senderName changed the guest access rules';

  @override
  String changedTheGuestAccessRulesTo(String senderName, String rules) =>
      '$senderName changed the guest access rules to $rules';

  @override
  String changedTheHistoryVisibility(String senderName) =>
      '$senderName changed the history visibility';

  @override
  String changedTheHistoryVisibilityTo(String senderName, String visibility) =>
      '$senderName changed the history visibility to $visibility';

  @override
  String changedTheJoinRules(String senderName) =>
      '$senderName changed the join rules';

  @override
  String changedTheJoinRulesTo(String senderName, String rules) =>
      '$senderName changed the join rules to $rules';

  @override
  String changedTheProfileAvatar(String targetName) =>
      '$targetName changed their profile avatar';

  @override
  String changedTheRoomAliases(String senderName) =>
      '$senderName changed the room aliases';

  @override
  String changedTheRoomInvitationLink(String senderName) =>
      '$senderName changed the room invitation link';

  @override
  String couldNotDecryptMessage(String error) =>
      'Could not decrypt message: $error';

  @override
  String createdTheChat(String senderName) => '$senderName created the chat';

  @override
  String endedTheCall(String senderName) => '$senderName ended the call';

  @override
  String groupWith(String displayname) => 'Group with $displayname';

  @override
  String hasWithdrawnTheInvitationFor(String senderName, String targetName) =>
      '$senderName has withdrawn the invitation for $targetName';

  @override
  String invitedUser(String senderName, String targetName) =>
      '$senderName invited $targetName';

  @override
  String joinedTheChat(String targetName) => '$targetName joined the chat';

  @override
  String kicked(String senderName, String targetName) =>
      '$senderName kicked $targetName';

  @override
  String kickedAndBanned(String senderName, String targetName) =>
      '$senderName kicked and banned $targetName';

  @override
  String redactedAnEvent(Event redactedEvent) => 'Redacted event';

  @override
  String rejectedTheInvitation(String targetName) =>
      '$targetName rejected the invitation';

  @override
  String removedBy(Event redactedEvent) => 'Removed';

  @override
  String sentAFile(String senderName) => '$senderName sent a file';

  @override
  String sentAPicture(String senderName) => '$senderName sent a picture';

  @override
  String sentASticker(String senderName) => '$senderName sent a sticker';

  @override
  String sentAVideo(String senderName) => '$senderName sent a video';

  @override
  String sentAnAudio(String senderName) => '$senderName sent an audio';

  @override
  String sentCallInformations(String senderName) =>
      '$senderName sent call information';

  @override
  String sharedTheLocation(String senderName) => '$senderName shared location';

  @override
  String startedACall(String senderName) => '$senderName started a call';

  @override
  String unbannedUser(String senderName, String targetName) =>
      '$senderName unbanned $targetName';

  @override
  String unknownEvent(String type) => 'Unknown event $type';

  @override
  String userLeftTheChat(String targetName) => '$targetName left the chat';

  @override
  String sentReaction(String senderName, String reactionKey) =>
      '$senderName reacted with $reactionKey';

  @override
  String get youAcceptedTheInvitation => 'You accepted the invitation';

  @override
  String youBannedUser(String targetName) => 'You banned $targetName';

  @override
  String youHaveWithdrawnTheInvitationFor(String targetName) =>
      'You have withdrawn the invitation for $targetName';

  @override
  String youInvitedBy(String senderName) => 'You were invited by $senderName';

  @override
  String youInvitedUser(String targetName) => 'You invited $targetName';

  @override
  String get youJoinedTheChat => 'You joined the chat';

  @override
  String youKicked(String targetName) => 'You kicked $targetName';

  @override
  String youKickedAndBanned(String targetName) =>
      'You kicked and banned $targetName';

  @override
  String get youRejectedTheInvitation => 'You rejected the invitation';

  @override
  String youUnbannedUser(String targetName) => 'You unbanned $targetName';

  @override
  String wasDirectChatDisplayName(String oldDisplayName) =>
      'Was direct chat: $oldDisplayName';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String hasKnocked(String targetName) => '$targetName has knocked';

  @override
  String acceptedKeyVerification(String senderName) =>
      '$senderName accepted key verification';

  @override
  String canceledKeyVerification(String senderName) =>
      '$senderName canceled key verification';

  @override
  String completedKeyVerification(String senderName) =>
      '$senderName completed key verification';

  @override
  String isReadyForKeyVerification(String senderName) =>
      '$senderName is ready for key verification';

  @override
  String requestedKeyVerification(String senderName) =>
      '$senderName requested key verification';

  @override
  String startedKeyVerification(String senderName) =>
      '$senderName started key verification';

  @override
  String invitedBy(String senderName) => 'Invited by $senderName';

  @override
  String get cancelledSend => 'Cancelled send';

  @override
  String voiceMessage(String senderName, Duration? duration) =>
      '$senderName sent a voice message';

  @override
  String get refreshingLastEvent => 'Refreshing...';

  @override
  String startedAPoll(String senderName) => '$senderName started a poll';

  @override
  String get pollHasBeenEnded => 'Poll has ended';
}

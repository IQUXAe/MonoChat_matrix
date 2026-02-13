// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chatsTitle => 'Chats';

  @override
  String get syncing => 'Syncing...';

  @override
  String get newChat => 'New Chat';

  @override
  String get messagePlaceholder => 'Message';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get choosePhoto => 'Choose Photo';

  @override
  String get chooseVideo => 'Choose Video';

  @override
  String get chooseFile => 'Choose File';

  @override
  String get cancel => 'Cancel';

  @override
  String get joinRoom => 'Join Room';

  @override
  String youHaveBeenInvited(String roomName) {
    return 'You have been invited to join\n$roomName';
  }

  @override
  String typingIndicator(String names) {
    return '$names is typing...';
  }

  @override
  String replyingTo(String user) {
    return 'Replying to $user';
  }

  @override
  String get waitingForMessage => 'Waiting for message...';

  @override
  String get filePickerError =>
      'The system file picker could not be opened. This often happens on Linux distributions missing \"xdg-desktop-portal\" services.';

  @override
  String get ok => 'OK';

  @override
  String get error => 'Error';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get saveImageTitle => 'Save Image?';

  @override
  String get saveImageContent => 'Do you want to save this image?';

  @override
  String get imageSavedSuccess => 'Image saved successfully.';

  @override
  String systemDialogError(String path) {
    return 'System dialog unavailable. Image saved to:\n$path';
  }

  @override
  String failedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get send => 'Send';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String get file => 'File';

  @override
  String get you => 'You';

  @override
  String get sendPhoto => 'Send Photo';

  @override
  String sendPhotos(int count) {
    return 'Send $count Photos';
  }

  @override
  String get sendVideo => 'Send Video';

  @override
  String get sendFile => 'Send File';

  @override
  String sendFiles(int count) {
    return 'Send $count Files';
  }

  @override
  String totalSize(String size) {
    return 'Total size: $size';
  }

  @override
  String get calculating => 'Calculating...';

  @override
  String get willBeCompressed => 'Will be compressed';

  @override
  String get compress => 'Compress';

  @override
  String get compressDescription => 'Reduce file size for faster sending';

  @override
  String get settings => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String get startConversation => 'Start Conversation';

  @override
  String get sendMessage => 'Send Message';

  @override
  String get ignoreUser => 'Ignore User';

  @override
  String ignoreUserConfirmation(String userName) {
    return 'Are you sure you want to ignore $userName? You will no longer see messages from this user.';
  }

  @override
  String get ignore => 'Ignore';

  @override
  String get close => 'Close';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get justNow => 'Just now';

  @override
  String lastSeenMinutesAgo(int minutes) {
    return 'Last seen $minutes min ago';
  }

  @override
  String lastSeenHoursAgo(int hours) {
    return 'Last seen ${hours}h ago';
  }

  @override
  String lastSeenAt(String date) {
    return 'Last seen $date';
  }

  @override
  String get newMessageInMonoChat => 'New message';

  @override
  String get openAppToReadMessages => 'Open app to read messages';

  @override
  String get incomingMessages => 'Incoming Messages';

  @override
  String unreadChatsInApp(String appName, String count) {
    return '$count unread chats in $appName';
  }

  @override
  String get directChats => 'Direct Chats';

  @override
  String get groups => 'Groups';

  @override
  String get reply => 'Reply';

  @override
  String get writeAMessage => 'Write a message...';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get noGoogleServicesWarning =>
      'Push notifications may not work without Google Play Services. Consider using UnifiedPush.';

  @override
  String get oopsPushError => 'Oops! Push notifications encountered an error.';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushProvider => 'Push Provider';

  @override
  String get pushNotificationsNotAvailable =>
      'Push Notifications Not Available';

  @override
  String get learnMore => 'Learn More';

  @override
  String get doNotShowAgain => 'Don\'t show again';

  @override
  String get noUnifiedPushDistributor =>
      'No push notification distributor found. Install ntfy or another UnifiedPush app.';

  @override
  String get pushStatus => 'Status';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get pushStatusStale => 'Connection may be stale';

  @override
  String get pushDistributor => 'Distributor';

  @override
  String get noneSelected => 'None selected';

  @override
  String get pushEndpoint => 'Endpoint';

  @override
  String get selectPushDistributor => 'Select Push Distributor';

  @override
  String get unregisterPush => 'Unregister Push Notifications';

  @override
  String get unregisterPushConfirm =>
      'Are you sure you want to unregister from push notifications?';

  @override
  String get unregister => 'Unregister';

  @override
  String get pushInfoText =>
      'MonoChat uses UnifiedPush for notifications - a FOSS alternative to proprietary push services. Install a UnifiedPush distributor like ntfy, NextPush, or Gotify.';

  @override
  String get learnMoreAboutUnifiedPush => 'Learn more about UnifiedPush →';

  @override
  String get notificationRules => 'Notification Rules';

  @override
  String get importantNotifications => 'Important';

  @override
  String get advancedNotifications => 'Advanced';

  @override
  String get muteAllNotifications => 'Mute All Notifications';

  @override
  String get allNotificationsMuted => 'All notifications are muted';

  @override
  String get notificationsEnabled => 'Notifications are enabled';

  @override
  String get pushRuleMaster => 'Master Switch';

  @override
  String get pushRuleMasterDesc => 'Mute all notifications globally';

  @override
  String get pushRuleSuppressNotices => 'Suppress Bot Messages';

  @override
  String get pushRuleSuppressNoticesDesc =>
      'Don\'t notify for bot/system messages';

  @override
  String get pushRuleInviteForMe => 'Room Invitations';

  @override
  String get pushRuleInviteForMeDesc => 'Notify when invited to rooms';

  @override
  String get pushRuleMemberEvent => 'Membership Changes';

  @override
  String get pushRuleMemberEventDesc => 'Notify about joins, leaves, kicks';

  @override
  String get pushRuleUserMention => 'User Mentions (@you)';

  @override
  String get pushRuleUserMentionDesc => 'Notify when someone mentions you';

  @override
  String get pushRuleContainsDisplayName => 'Contains Display Name';

  @override
  String get pushRuleContainsDisplayNameDesc =>
      'Notify when your name is mentioned';

  @override
  String get pushRuleRoomMention => 'Room Mentions (@room)';

  @override
  String get pushRuleRoomMentionDesc => 'Notify when @room is used';

  @override
  String get pushRuleRoomNotif => 'Room Notifications';

  @override
  String get pushRuleRoomNotifDesc => 'Room-level notification keywords';

  @override
  String get pushRuleTombstone => 'Room Upgrades';

  @override
  String get pushRuleTombstoneDesc => 'Notify about room version upgrades';

  @override
  String get pushRuleReaction => 'Reactions';

  @override
  String get pushRuleReactionDesc => 'Notify when someone reacts to messages';

  @override
  String get pushRuleSuppressEdits => 'Suppress Edits';

  @override
  String get pushRuleSuppressEditsDesc => 'Don\'t notify for message edits';

  @override
  String get pushRuleCall => 'Calls';

  @override
  String get pushRuleCallDesc => 'Notify about incoming calls';

  @override
  String get pushRuleEncryptedDM => 'Encrypted Direct Messages';

  @override
  String get pushRuleEncryptedDMDesc => 'Notify for encrypted one-to-one chats';

  @override
  String get pushRuleDM => 'Direct Messages';

  @override
  String get pushRuleDMDesc => 'Notify for one-to-one chats';

  @override
  String get pushRuleGroupMessage => 'Group Messages';

  @override
  String get pushRuleGroupMessageDesc => 'Notify for messages in group chats';

  @override
  String get pushRuleEncryptedGroup => 'Encrypted Groups';

  @override
  String get pushRuleEncryptedGroupDesc => 'Notify for encrypted group chats';

  @override
  String get pushRuleContainsUserName => 'Contains Username';

  @override
  String get pushRuleContainsUserNameDesc =>
      'Notify when your username is mentioned';

  @override
  String get pushRuleCustom => 'Custom notification rule';

  @override
  String get pushRuleCategoryOverride => 'Priority Rules';

  @override
  String get pushRuleCategoryContent => 'Content Rules';

  @override
  String get pushRuleCategoryRoom => 'Room Rules';

  @override
  String get pushRuleCategorySender => 'Sender Rules';

  @override
  String get pushRuleCategoryUnderride => 'Default Rules';

  @override
  String get registeredDevices => 'Registered Devices';

  @override
  String get noRegisteredDevices =>
      'No devices registered for push notifications';

  @override
  String get removePusher => 'Remove Device';

  @override
  String get removePusherConfirm =>
      'This device will no longer receive push notifications. Continue?';

  @override
  String get remove => 'Remove';

  @override
  String get troubleshooting => 'Troubleshooting';

  @override
  String get sendTestNotification => 'Send Test Notification';

  @override
  String get testNotificationSent => 'Test notification sent!';

  @override
  String get copyPushEndpoint => 'Copy Push Endpoint';

  @override
  String get endpointCopied => 'Endpoint Copied';

  @override
  String get noEndpoint => 'No Endpoint';

  @override
  String get noEndpointMessage => 'Push notifications are not configured yet.';

  @override
  String get refreshPushStatus => 'Refresh Push Status';

  @override
  String get spaces => 'Spaces';

  @override
  String get allChats => 'All Chats';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get createSpace => 'Create Space';

  @override
  String get createSubspace => 'Create Subspace';

  @override
  String get createGroup => 'Create Group';

  @override
  String get spaceName => 'Space Name';

  @override
  String get groupName => 'Group Name';

  @override
  String get topicOptional => 'Topic (optional)';

  @override
  String get spaceAlias => 'Space Alias (e.g. my-space)';

  @override
  String get publicSpace => 'Public Space';

  @override
  String get privateSpace => 'Private Space';

  @override
  String get anyoneCanJoin => 'Anyone can join';

  @override
  String get inviteOnly => 'Invite only';

  @override
  String get spaceDescription =>
      'Spaces help you organize your rooms and communities. Create subspaces and add rooms to build your community structure.';

  @override
  String get failedToCreateSpace => 'Failed to create space';

  @override
  String get spaceNotFound => 'Space not found';

  @override
  String get emptySpace => 'This space is empty';

  @override
  String get addToSpace => 'Add to Space';

  @override
  String get removeFromSpace => 'Remove from Space';

  @override
  String get moveToSpace => 'Move to Different Space';

  @override
  String get leaveSpaceConfirmation =>
      'Are you sure you want to leave this space?';

  @override
  String get leave => 'Leave';

  @override
  String get invite => 'Invite';

  @override
  String get members => 'members';

  @override
  String get search => 'Search';

  @override
  String get loadMore => 'Load More';

  @override
  String get unread => 'Unread';

  @override
  String get directMessages => 'Direct Messages';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get startAChat => 'Start a chat';

  @override
  String get newGroup => 'New Group';

  @override
  String get newSpace => 'New Space';

  @override
  String get publicGroup => 'Public Group';

  @override
  String get privateGroup => 'Private Group';

  @override
  String get enableEncryption => 'Enable Encryption';

  @override
  String get endToEndEncryption => 'End-to-end encryption';

  @override
  String get inviteMembers => 'Invite Members';

  @override
  String get searchUsers => 'Search users';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get addMembers => 'Add Members';

  @override
  String selectedMembers(int count) {
    return '$count selected';
  }

  @override
  String get groupCreated => 'Group created successfully';

  @override
  String get createGroupDescription => 'Create a new group for discussions';

  @override
  String get spaceCreated => 'Space created successfully';

  @override
  String get filterChats => 'Filter chats';

  @override
  String get pinned => 'Pinned';

  @override
  String get favorites => 'Favorites';

  @override
  String get muted => 'Muted';

  @override
  String get searchable => 'Searchable';

  @override
  String get searchableDescription =>
      'Allow users to find this group in public search';

  @override
  String get joinByTag => 'Join by Tag';

  @override
  String get enterTag => 'Enter room tag (e.g. #room:server.com)';

  @override
  String get invalidTag => 'Invalid room tag or ID';

  @override
  String get join => 'Join';

  @override
  String get loadingMessages => 'Loading messages...';

  @override
  String get loadingPleaseWait => 'Loading, please wait...';

  @override
  String get recoveryKey => 'Recovery Key';

  @override
  String get chatBackupDescription =>
      'Your old messages are secured with a recovery key. Please enter it to restore your history.';

  @override
  String get storeInSecureStorageDescription =>
      'Store the recovery key securely on this device.';

  @override
  String get storeInAndroidKeystore => 'Store in Android Keystore';

  @override
  String get storeInAppleKeyChain => 'Store in Apple KeyChain';

  @override
  String get storeSecurlyOnThisDevice => 'Store securely on this device';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get saveKeyManuallyDescription =>
      'Save this key manually to a safe place.';

  @override
  String get next => 'Next';

  @override
  String get unlockOldMessages => 'Unlock old messages';

  @override
  String get transferFromAnotherDevice => 'Transfer from another device';

  @override
  String get verifyOtherDevice => 'Verify other device';

  @override
  String get verifyOtherDeviceDescription =>
      'Please confirm the verification on your other device.';

  @override
  String get recoveryKeyLost => 'Recovery key lost?';

  @override
  String get wipeChatBackup => 'Wipe chat backup';

  @override
  String get chatBackup => 'Chat Backup';

  @override
  String get chatBackupWarning =>
      'Warning: You are about to wipe your chat backup. You will lose access to old encrypted messages.';

  @override
  String get skipChatBackup => 'Skip chat backup';

  @override
  String get skipChatBackupWarning =>
      'Are you sure you want to skip? You can set it up later.';

  @override
  String get skip => 'Skip';

  @override
  String get everythingReady => 'Everything ready!';

  @override
  String get yourChatBackupHasBeenSetUp =>
      'Your chat backup has been set up successfully.';

  @override
  String get oopsSomethingWentWrong => 'Oops, something went wrong...';

  @override
  String get setupChatBackup => 'Setup Chat Backup';

  @override
  String get pleaseEnterRecoveryKeyDescription =>
      'Please enter your recovery key to access your old messages.';

  @override
  String get wrongRecoveryKey => 'Wrong recovery key.';

  @override
  String get areYouSureYouWantToLogout => 'Are you sure you want to logout?';

  @override
  String get noBackupWarning =>
      'Warning: You do not have a chat backup. You will lose access to encrypted messages.';

  @override
  String get logout => 'Logout';

  @override
  String get notificationsSettings => 'Notification Settings';

  @override
  String get muteNotifications => 'Mute Notifications';

  @override
  String get unmuteNotifications => 'Unmute Notifications';

  @override
  String get notificationsMuted => 'Notifications muted';

  @override
  String get notificationsOn => 'Notifications on';

  @override
  String get mentionsOnly => 'Mentions only';

  @override
  String get allMessages => 'All messages';

  @override
  String get roomNotificationSuccess => 'Notification settings updated';

  @override
  String get roomNotificationError => 'Failed to update notification settings';

  @override
  String get pinChat => 'Pin Chat';

  @override
  String get unpinChat => 'Unpin Chat';

  @override
  String get pinnedMessage => 'Pinned Message';

  @override
  String get messageNotFound => 'Message not found';
}

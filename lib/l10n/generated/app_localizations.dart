import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Title for the room list screen
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// Loading text while syncing
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// Title for new chat screen
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Placeholder text for message input
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messagePlaceholder;

  /// Action sheet option
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Action sheet option
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get choosePhoto;

  /// Action sheet option
  ///
  /// In en, this message translates to:
  /// **'Choose Video'**
  String get chooseVideo;

  /// Action sheet option
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// Cancel action label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button to join a room
  ///
  /// In en, this message translates to:
  /// **'Join Room'**
  String get joinRoom;

  /// Invitation message
  ///
  /// In en, this message translates to:
  /// **'You have been invited to join\n{roomName}'**
  String youHaveBeenInvited(String roomName);

  /// Typing indicator text
  ///
  /// In en, this message translates to:
  /// **'{names} is typing...'**
  String typingIndicator(String names);

  /// Replying to user text
  ///
  /// In en, this message translates to:
  /// **'Replying to {user}'**
  String replyingTo(String user);

  /// Placeholder for encrypted message
  ///
  /// In en, this message translates to:
  /// **'Waiting for message...'**
  String get waitingForMessage;

  /// Error message when file picker fails
  ///
  /// In en, this message translates to:
  /// **'The system file picker could not be opened. This often happens on Linux distributions missing \"xdg-desktop-portal\" services.'**
  String get filePickerError;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Generic error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Saved successfully title
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Dialog title for saving image
  ///
  /// In en, this message translates to:
  /// **'Save Image?'**
  String get saveImageTitle;

  /// Dialog content for saving image
  ///
  /// In en, this message translates to:
  /// **'Do you want to save this image?'**
  String get saveImageContent;

  /// Success message after saving image
  ///
  /// In en, this message translates to:
  /// **'Image saved successfully.'**
  String get imageSavedSuccess;

  /// Error message when system dialog fails but fallback worked
  ///
  /// In en, this message translates to:
  /// **'System dialog unavailable. Image saved to:\n{path}'**
  String systemDialogError(String path);

  /// Error message when save fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(Object error);

  /// Send button text
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Tap to retry text
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// Generic file label
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Refers to the current user
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Title for sending single photo
  ///
  /// In en, this message translates to:
  /// **'Send Photo'**
  String get sendPhoto;

  /// Title for sending multiple photos
  ///
  /// In en, this message translates to:
  /// **'Send {count} Photos'**
  String sendPhotos(int count);

  /// Title for sending video
  ///
  /// In en, this message translates to:
  /// **'Send Video'**
  String get sendVideo;

  /// Title for sending single file
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get sendFile;

  /// Title for sending multiple files
  ///
  /// In en, this message translates to:
  /// **'Send {count} Files'**
  String sendFiles(int count);

  /// File size label
  ///
  /// In en, this message translates to:
  /// **'Total size: {size}'**
  String totalSize(String size);

  /// Loading text for size calculation
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// Label indicating compression
  ///
  /// In en, this message translates to:
  /// **'Will be compressed'**
  String get willBeCompressed;

  /// Compression toggle label
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get compress;

  /// Compression toggle description
  ///
  /// In en, this message translates to:
  /// **'Reduce file size for faster sending'**
  String get compressDescription;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Fallback for unknown user
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// Button to start new chat
  ///
  /// In en, this message translates to:
  /// **'Start Conversation'**
  String get startConversation;

  /// Button to send message to existing chat
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// Action to ignore user
  ///
  /// In en, this message translates to:
  /// **'Ignore User'**
  String get ignoreUser;

  /// Confirmation for ignoring user
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to ignore {userName}? You will no longer see messages from this user.'**
  String ignoreUserConfirmation(String userName);

  /// Confirm ignore action
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// User is online
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// User is offline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// User was active just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Last seen minutes ago
  ///
  /// In en, this message translates to:
  /// **'Last seen {minutes} min ago'**
  String lastSeenMinutesAgo(int minutes);

  /// Last seen hours ago
  ///
  /// In en, this message translates to:
  /// **'Last seen {hours}h ago'**
  String lastSeenHoursAgo(int hours);

  /// Last seen at date
  ///
  /// In en, this message translates to:
  /// **'Last seen {date}'**
  String lastSeenAt(String date);

  /// Notification title for encrypted messages
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessageInMonoChat;

  /// Notification body fallback
  ///
  /// In en, this message translates to:
  /// **'Open app to read messages'**
  String get openAppToReadMessages;

  /// Notification channel name
  ///
  /// In en, this message translates to:
  /// **'Incoming Messages'**
  String get incomingMessages;

  /// Notification ticker text
  ///
  /// In en, this message translates to:
  /// **'{count} unread chats in {appName}'**
  String unreadChatsInApp(String appName, String count);

  /// Label for direct chats notification group
  ///
  /// In en, this message translates to:
  /// **'Direct Chats'**
  String get directChats;

  /// Label for group chats notification group
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// Notification action to reply
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// Placeholder for reply input
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get writeAMessage;

  /// Notification action to mark as read
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// Warning when Google Services are not available
  ///
  /// In en, this message translates to:
  /// **'Push notifications may not work without Google Play Services. Consider using UnifiedPush.'**
  String get noGoogleServicesWarning;

  /// Generic push notification error
  ///
  /// In en, this message translates to:
  /// **'Oops! Push notifications encountered an error.'**
  String get oopsPushError;

  /// Notifications settings title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for push notification provider
  ///
  /// In en, this message translates to:
  /// **'Push Provider'**
  String get pushProvider;

  /// Error dialog title for push notifications
  ///
  /// In en, this message translates to:
  /// **'Push Notifications Not Available'**
  String get pushNotificationsNotAvailable;

  /// Link to learn more
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learnMore;

  /// Option to hide warning permanently
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get doNotShowAgain;

  /// Warning when no UnifiedPush distributor is available
  ///
  /// In en, this message translates to:
  /// **'No push notification distributor found. Install ntfy or another UnifiedPush app.'**
  String get noUnifiedPushDistributor;

  /// Push notification status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get pushStatus;

  /// Connected status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Not connected status
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// Push distributor label
  ///
  /// In en, this message translates to:
  /// **'Distributor'**
  String get pushDistributor;

  /// No distributor selected
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get noneSelected;

  /// Push endpoint label
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get pushEndpoint;

  /// Action to select push distributor
  ///
  /// In en, this message translates to:
  /// **'Select Push Distributor'**
  String get selectPushDistributor;

  /// Action to unregister push
  ///
  /// In en, this message translates to:
  /// **'Unregister Push Notifications'**
  String get unregisterPush;

  /// Confirmation for unregister
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unregister from push notifications?'**
  String get unregisterPushConfirm;

  /// Unregister action
  ///
  /// In en, this message translates to:
  /// **'Unregister'**
  String get unregister;

  /// Info text about UnifiedPush
  ///
  /// In en, this message translates to:
  /// **'MonoChat uses UnifiedPush for notifications - a FOSS alternative to proprietary push services. Install a UnifiedPush distributor like ntfy, NextPush, or Gotify.'**
  String get pushInfoText;

  /// Link to learn about UnifiedPush
  ///
  /// In en, this message translates to:
  /// **'Learn more about UnifiedPush →'**
  String get learnMoreAboutUnifiedPush;

  /// Section title for notification rules
  ///
  /// In en, this message translates to:
  /// **'Notification Rules'**
  String get notificationRules;

  /// Important notifications section
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get importantNotifications;

  /// Advanced notifications section
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedNotifications;

  /// Master mute switch
  ///
  /// In en, this message translates to:
  /// **'Mute All Notifications'**
  String get muteAllNotifications;

  /// All muted status
  ///
  /// In en, this message translates to:
  /// **'All notifications are muted'**
  String get allNotificationsMuted;

  /// Notifications enabled status
  ///
  /// In en, this message translates to:
  /// **'Notifications are enabled'**
  String get notificationsEnabled;

  /// Master push rule
  ///
  /// In en, this message translates to:
  /// **'Master Switch'**
  String get pushRuleMaster;

  /// Master rule description
  ///
  /// In en, this message translates to:
  /// **'Mute all notifications globally'**
  String get pushRuleMasterDesc;

  /// Bot messages rule
  ///
  /// In en, this message translates to:
  /// **'Suppress Bot Messages'**
  String get pushRuleSuppressNotices;

  /// Bot messages description
  ///
  /// In en, this message translates to:
  /// **'Don\'t notify for bot/system messages'**
  String get pushRuleSuppressNoticesDesc;

  /// Invitations rule
  ///
  /// In en, this message translates to:
  /// **'Room Invitations'**
  String get pushRuleInviteForMe;

  /// Invitations description
  ///
  /// In en, this message translates to:
  /// **'Notify when invited to rooms'**
  String get pushRuleInviteForMeDesc;

  /// Membership rule
  ///
  /// In en, this message translates to:
  /// **'Membership Changes'**
  String get pushRuleMemberEvent;

  /// Membership description
  ///
  /// In en, this message translates to:
  /// **'Notify about joins, leaves, kicks'**
  String get pushRuleMemberEventDesc;

  /// User mention rule
  ///
  /// In en, this message translates to:
  /// **'User Mentions (@you)'**
  String get pushRuleUserMention;

  /// User mention description
  ///
  /// In en, this message translates to:
  /// **'Notify when someone mentions you'**
  String get pushRuleUserMentionDesc;

  /// Display name rule
  ///
  /// In en, this message translates to:
  /// **'Contains Display Name'**
  String get pushRuleContainsDisplayName;

  /// Display name description
  ///
  /// In en, this message translates to:
  /// **'Notify when your name is mentioned'**
  String get pushRuleContainsDisplayNameDesc;

  /// Room mention rule
  ///
  /// In en, this message translates to:
  /// **'Room Mentions (@room)'**
  String get pushRuleRoomMention;

  /// Room mention description
  ///
  /// In en, this message translates to:
  /// **'Notify when @room is used'**
  String get pushRuleRoomMentionDesc;

  /// Room notif rule
  ///
  /// In en, this message translates to:
  /// **'Room Notifications'**
  String get pushRuleRoomNotif;

  /// Room notif description
  ///
  /// In en, this message translates to:
  /// **'Room-level notification keywords'**
  String get pushRuleRoomNotifDesc;

  /// Tombstone rule
  ///
  /// In en, this message translates to:
  /// **'Room Upgrades'**
  String get pushRuleTombstone;

  /// Tombstone description
  ///
  /// In en, this message translates to:
  /// **'Notify about room version upgrades'**
  String get pushRuleTombstoneDesc;

  /// Reactions rule
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get pushRuleReaction;

  /// Reactions description
  ///
  /// In en, this message translates to:
  /// **'Notify when someone reacts to messages'**
  String get pushRuleReactionDesc;

  /// Suppress edits rule
  ///
  /// In en, this message translates to:
  /// **'Suppress Edits'**
  String get pushRuleSuppressEdits;

  /// Suppress edits description
  ///
  /// In en, this message translates to:
  /// **'Don\'t notify for message edits'**
  String get pushRuleSuppressEditsDesc;

  /// Calls rule
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get pushRuleCall;

  /// Calls description
  ///
  /// In en, this message translates to:
  /// **'Notify about incoming calls'**
  String get pushRuleCallDesc;

  /// Encrypted DM rule
  ///
  /// In en, this message translates to:
  /// **'Encrypted Direct Messages'**
  String get pushRuleEncryptedDM;

  /// Encrypted DM description
  ///
  /// In en, this message translates to:
  /// **'Notify for encrypted one-to-one chats'**
  String get pushRuleEncryptedDMDesc;

  /// DM rule
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get pushRuleDM;

  /// DM description
  ///
  /// In en, this message translates to:
  /// **'Notify for one-to-one chats'**
  String get pushRuleDMDesc;

  /// Group message rule
  ///
  /// In en, this message translates to:
  /// **'Group Messages'**
  String get pushRuleGroupMessage;

  /// Group message description
  ///
  /// In en, this message translates to:
  /// **'Notify for messages in group chats'**
  String get pushRuleGroupMessageDesc;

  /// Encrypted group rule
  ///
  /// In en, this message translates to:
  /// **'Encrypted Groups'**
  String get pushRuleEncryptedGroup;

  /// Encrypted group description
  ///
  /// In en, this message translates to:
  /// **'Notify for encrypted group chats'**
  String get pushRuleEncryptedGroupDesc;

  /// Username rule
  ///
  /// In en, this message translates to:
  /// **'Contains Username'**
  String get pushRuleContainsUserName;

  /// Username description
  ///
  /// In en, this message translates to:
  /// **'Notify when your username is mentioned'**
  String get pushRuleContainsUserNameDesc;

  /// Custom rule description
  ///
  /// In en, this message translates to:
  /// **'Custom notification rule'**
  String get pushRuleCustom;

  /// Override category
  ///
  /// In en, this message translates to:
  /// **'Priority Rules'**
  String get pushRuleCategoryOverride;

  /// Content category
  ///
  /// In en, this message translates to:
  /// **'Content Rules'**
  String get pushRuleCategoryContent;

  /// Room category
  ///
  /// In en, this message translates to:
  /// **'Room Rules'**
  String get pushRuleCategoryRoom;

  /// Sender category
  ///
  /// In en, this message translates to:
  /// **'Sender Rules'**
  String get pushRuleCategorySender;

  /// Underride category
  ///
  /// In en, this message translates to:
  /// **'Default Rules'**
  String get pushRuleCategoryUnderride;

  /// Registered devices section
  ///
  /// In en, this message translates to:
  /// **'Registered Devices'**
  String get registeredDevices;

  /// No devices message
  ///
  /// In en, this message translates to:
  /// **'No devices registered for push notifications'**
  String get noRegisteredDevices;

  /// Remove pusher action
  ///
  /// In en, this message translates to:
  /// **'Remove Device'**
  String get removePusher;

  /// Remove pusher confirmation
  ///
  /// In en, this message translates to:
  /// **'This device will no longer receive push notifications. Continue?'**
  String get removePusherConfirm;

  /// Remove action
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Troubleshooting section
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get troubleshooting;

  /// Test notification action
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get sendTestNotification;

  /// Test notification sent message
  ///
  /// In en, this message translates to:
  /// **'Test notification sent!'**
  String get testNotificationSent;

  /// Copy endpoint action
  ///
  /// In en, this message translates to:
  /// **'Copy Push Endpoint'**
  String get copyPushEndpoint;

  /// Endpoint copied message
  ///
  /// In en, this message translates to:
  /// **'Endpoint Copied'**
  String get endpointCopied;

  /// No endpoint title
  ///
  /// In en, this message translates to:
  /// **'No Endpoint'**
  String get noEndpoint;

  /// No endpoint message
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not configured yet.'**
  String get noEndpointMessage;

  /// Refresh status action
  ///
  /// In en, this message translates to:
  /// **'Refresh Push Status'**
  String get refreshPushStatus;

  /// Spaces title
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get spaces;

  /// All chats filter
  ///
  /// In en, this message translates to:
  /// **'All Chats'**
  String get allChats;

  /// Add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Create space action
  ///
  /// In en, this message translates to:
  /// **'Create Space'**
  String get createSpace;

  /// Create subspace action
  ///
  /// In en, this message translates to:
  /// **'Create Subspace'**
  String get createSubspace;

  /// Create group action
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// Space name placeholder
  ///
  /// In en, this message translates to:
  /// **'Space Name'**
  String get spaceName;

  /// Group name placeholder
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// Topic placeholder
  ///
  /// In en, this message translates to:
  /// **'Topic (optional)'**
  String get topicOptional;

  /// Space alias placeholder
  ///
  /// In en, this message translates to:
  /// **'Space Alias (e.g. my-space)'**
  String get spaceAlias;

  /// Public space label
  ///
  /// In en, this message translates to:
  /// **'Public Space'**
  String get publicSpace;

  /// Private space label
  ///
  /// In en, this message translates to:
  /// **'Private Space'**
  String get privateSpace;

  /// Public space description
  ///
  /// In en, this message translates to:
  /// **'Anyone can join'**
  String get anyoneCanJoin;

  /// Private space description
  ///
  /// In en, this message translates to:
  /// **'Invite only'**
  String get inviteOnly;

  /// Info text about spaces
  ///
  /// In en, this message translates to:
  /// **'Spaces help you organize your rooms and communities. Create subspaces and add rooms to build your community structure.'**
  String get spaceDescription;

  /// Error creating space
  ///
  /// In en, this message translates to:
  /// **'Failed to create space'**
  String get failedToCreateSpace;

  /// Space not found error
  ///
  /// In en, this message translates to:
  /// **'Space not found'**
  String get spaceNotFound;

  /// Empty space message
  ///
  /// In en, this message translates to:
  /// **'This space is empty'**
  String get emptySpace;

  /// Add to space action
  ///
  /// In en, this message translates to:
  /// **'Add to Space'**
  String get addToSpace;

  /// Remove from space action
  ///
  /// In en, this message translates to:
  /// **'Remove from Space'**
  String get removeFromSpace;

  /// Move to space action
  ///
  /// In en, this message translates to:
  /// **'Move to Different Space'**
  String get moveToSpace;

  /// Leave space confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this space?'**
  String get leaveSpaceConfirmation;

  /// Leave action
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Invite action
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// Members label
  ///
  /// In en, this message translates to:
  /// **'members'**
  String get members;

  /// Search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Load more button
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// Unread filter
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// Direct messages filter
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get directMessages;

  /// Empty chat list message
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// Start chat prompt
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get startAChat;

  /// New group action
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// New space action
  ///
  /// In en, this message translates to:
  /// **'New Space'**
  String get newSpace;

  /// Public group label
  ///
  /// In en, this message translates to:
  /// **'Public Group'**
  String get publicGroup;

  /// Private group label
  ///
  /// In en, this message translates to:
  /// **'Private Group'**
  String get privateGroup;

  /// Encryption toggle
  ///
  /// In en, this message translates to:
  /// **'Enable Encryption'**
  String get enableEncryption;

  /// E2EE label
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption'**
  String get endToEndEncryption;

  /// Invite members action
  ///
  /// In en, this message translates to:
  /// **'Invite Members'**
  String get inviteMembers;

  /// Search users placeholder
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get searchUsers;

  /// No users found message
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// Add members action
  ///
  /// In en, this message translates to:
  /// **'Add Members'**
  String get addMembers;

  /// Selected members count
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedMembers(int count);

  /// Group created message
  ///
  /// In en, this message translates to:
  /// **'Group created successfully'**
  String get groupCreated;

  /// Description for create group action
  ///
  /// In en, this message translates to:
  /// **'Create a new group for discussions'**
  String get createGroupDescription;

  /// Space created message
  ///
  /// In en, this message translates to:
  /// **'Space created successfully'**
  String get spaceCreated;

  /// Filter chats action
  ///
  /// In en, this message translates to:
  /// **'Filter chats'**
  String get filterChats;

  /// Pinned chats filter
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// Favorites filter
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Muted chats filter
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// Searchable toggle label
  ///
  /// In en, this message translates to:
  /// **'Searchable'**
  String get searchable;

  /// Searchable description
  ///
  /// In en, this message translates to:
  /// **'Allow users to find this group in public search'**
  String get searchableDescription;

  /// Join room by tag/alias
  ///
  /// In en, this message translates to:
  /// **'Join by Tag'**
  String get joinByTag;

  /// Placeholder for entering room tag
  ///
  /// In en, this message translates to:
  /// **'Enter room tag (e.g. #room:server.com)'**
  String get enterTag;

  /// Error message for invalid tag
  ///
  /// In en, this message translates to:
  /// **'Invalid room tag or ID'**
  String get invalidTag;

  /// Join action label
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// Loading messages text
  ///
  /// In en, this message translates to:
  /// **'Loading messages...'**
  String get loadingMessages;

  /// Loading wait text
  ///
  /// In en, this message translates to:
  /// **'Loading, please wait...'**
  String get loadingPleaseWait;

  /// Recovery Key title
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get recoveryKey;

  /// Description for chat backup
  ///
  /// In en, this message translates to:
  /// **'Your old messages are secured with a recovery key. Please enter it to restore your history.'**
  String get chatBackupDescription;

  /// Description for secure storage
  ///
  /// In en, this message translates to:
  /// **'Store the recovery key securely on this device.'**
  String get storeInSecureStorageDescription;

  /// Android keystore option
  ///
  /// In en, this message translates to:
  /// **'Store in Android Keystore'**
  String get storeInAndroidKeystore;

  /// Apple keychain option
  ///
  /// In en, this message translates to:
  /// **'Store in Apple KeyChain'**
  String get storeInAppleKeyChain;

  /// Generic secure storage option
  ///
  /// In en, this message translates to:
  /// **'Store securely on this device'**
  String get storeSecurlyOnThisDevice;

  /// Copy action
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// Manual save description
  ///
  /// In en, this message translates to:
  /// **'Save this key manually to a safe place.'**
  String get saveKeyManuallyDescription;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Unlock action
  ///
  /// In en, this message translates to:
  /// **'Unlock old messages'**
  String get unlockOldMessages;

  /// Transfer action
  ///
  /// In en, this message translates to:
  /// **'Transfer from another device'**
  String get transferFromAnotherDevice;

  /// Verify device title
  ///
  /// In en, this message translates to:
  /// **'Verify other device'**
  String get verifyOtherDevice;

  /// Verify device description
  ///
  /// In en, this message translates to:
  /// **'Please confirm the verification on your other device.'**
  String get verifyOtherDeviceDescription;

  /// Lost key action
  ///
  /// In en, this message translates to:
  /// **'Recovery key lost?'**
  String get recoveryKeyLost;

  /// Wipe backup action
  ///
  /// In en, this message translates to:
  /// **'Wipe chat backup'**
  String get wipeChatBackup;

  /// Chat backup title
  ///
  /// In en, this message translates to:
  /// **'Chat Backup'**
  String get chatBackup;

  /// Wipe warning
  ///
  /// In en, this message translates to:
  /// **'Warning: You are about to wipe your chat backup. You will lose access to old encrypted messages.'**
  String get chatBackupWarning;

  /// Skip backup action
  ///
  /// In en, this message translates to:
  /// **'Skip chat backup'**
  String get skipChatBackup;

  /// Skip warning
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to skip? You can set it up later.'**
  String get skipChatBackupWarning;

  /// Skip button
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Success title
  ///
  /// In en, this message translates to:
  /// **'Everything ready!'**
  String get everythingReady;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Your chat backup has been set up successfully.'**
  String get yourChatBackupHasBeenSetUp;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Oops, something went wrong...'**
  String get oopsSomethingWentWrong;

  /// Setup title
  ///
  /// In en, this message translates to:
  /// **'Setup Chat Backup'**
  String get setupChatBackup;

  /// Enter key description
  ///
  /// In en, this message translates to:
  /// **'Please enter your recovery key to access your old messages.'**
  String get pleaseEnterRecoveryKeyDescription;

  /// Error message for wrong key
  ///
  /// In en, this message translates to:
  /// **'Wrong recovery key.'**
  String get wrongRecoveryKey;

  /// Logout confirmation title
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureYouWantToLogout;

  /// Logout backup warning
  ///
  /// In en, this message translates to:
  /// **'Warning: You do not have a chat backup. You will lose access to encrypted messages.'**
  String get noBackupWarning;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Notification settings section title
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationsSettings;

  /// Mute notifications action
  ///
  /// In en, this message translates to:
  /// **'Mute Notifications'**
  String get muteNotifications;

  /// Unmute notifications action
  ///
  /// In en, this message translates to:
  /// **'Unmute Notifications'**
  String get unmuteNotifications;

  /// Status when notifications are muted
  ///
  /// In en, this message translates to:
  /// **'Notifications muted'**
  String get notificationsMuted;

  /// Status when notifications are on
  ///
  /// In en, this message translates to:
  /// **'Notifications on'**
  String get notificationsOn;

  /// Only notify on mentions
  ///
  /// In en, this message translates to:
  /// **'Mentions only'**
  String get mentionsOnly;

  /// Notify for all messages
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get allMessages;

  /// Success message after changing notification settings
  ///
  /// In en, this message translates to:
  /// **'Notification settings updated'**
  String get roomNotificationSuccess;

  /// Error message when notification settings fail
  ///
  /// In en, this message translates to:
  /// **'Failed to update notification settings'**
  String get roomNotificationError;

  /// Pin chat action
  ///
  /// In en, this message translates to:
  /// **'Pin Chat'**
  String get pinChat;

  /// Unpin chat action
  ///
  /// In en, this message translates to:
  /// **'Unpin Chat'**
  String get unpinChat;

  /// Header for pinned message in chat
  ///
  /// In en, this message translates to:
  /// **'Pinned Message'**
  String get pinnedMessage;

  /// Placeholder when pinned message content is not available
  ///
  /// In en, this message translates to:
  /// **'Message not found'**
  String get messageNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

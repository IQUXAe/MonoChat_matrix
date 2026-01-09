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

  /// Cancel action
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

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
}

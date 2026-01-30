
abstract class AppConfig {
  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String pushNotificationsChannelId = 'monochat_push';
  static const String pushNotificationsAppId = 'org.iquxae.monochat';
  static const String emojiFontName =
      'EmojiOneColor'; // Example, needed if referenced

  static const String enablePushTutorial =
      'https://unifiedpush.org/users/intro/';

  static const String mainIsolatePortName = 'monochat_main_isolate';
  static const String pushIsolatePortName = 'monochat_push_isolate';
  static const String pushNotificationsPusherFormat = 'event_id_only';
  static const String pushNotificationsGatewayUrl =
      'https://iquxae.org/_matrix/push/v1/notify';
}

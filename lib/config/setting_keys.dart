/// Settings keys for MonoChat
abstract class SettingKeys {
  static const String prefix = 'monochat_';

  // Push notification settings
  static const String unifiedPushEndpoint = 'monochat.unifiedpush.endpoint';
  static const String unifiedPushRegistered = 'monochat.unifiedpush.registered';
  static const String showNoGoogle = 'monochat.show_no_google';

  // Theme and appearance
  static const String fontSizeFactor = 'monochat.font_size_factor';
  static const String colorSchemeSeed = 'monochat.color_scheme_seed';
  static const String themeMode = 'monochat.theme_mode';

  // Chat settings
  static const String renderHtml = 'monochat.renderHtml';
  static const String hideRedactedEvents = 'monochat.hideRedactedEvents';
  static const String hideUnknownEvents = 'monochat.hideUnknownEvents';
  static const String autoplayImages = 'monochat.autoplay_images';
  static const String sendTypingNotifications =
      'monochat.send_typing_notifications';
  static const String sendPublicReadReceipts =
      'monochat.send_public_read_receipts';
  static const String swipeRightToLeftToReply =
      'monochat.swipeRightToLeftToReply';
  static const String sendOnEnter = 'monochat.send_on_enter';

  // Notifications
  static const String notificationsEnabled = 'monochat.notifications_enabled';
}

/// App settings values with defaults
abstract class AppSettings {
  // Push notifications
  static const String pushNotificationsGatewayUrl =
      'https://matrix.org/_matrix/push/v1/notify';
  static const String pushNotificationsPusherFormat = 'event_id_only';

  // App info
  static const String applicationName = 'MonoChat';

  // Feature flags
  static bool showNoGoogle = false;
  static bool sendPublicReadReceipts = true;
}

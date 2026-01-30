import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:monochat/config/app_config.dart';
import 'package:monochat/config/setting_keys.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/utils/notification_background_handler.dart';
import 'package:monochat/utils/platform_infos.dart';
import 'package:monochat/utils/push_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:unifiedpush_ui/unifiedpush_ui.dart';

class BackgroundPush {
  static BackgroundPush? _instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Client client;
  void Function(String errorMsg, {Uri? link})? onFcmError;
  AppLocalizations? l10n;

  Future<void> loadLocale() async {
    l10n ??= await AppLocalizations.delegate.load(
      PlatformDispatcher.instance.locale,
    );
  }

  final pendingTests = <String, Completer<void>>{};
  bool upRegistered = false;

  DateTime? lastReceivedPush;
  bool upAction = false;

  void _init() async {
    try {
      // Setup main isolate port listener for notification actions from background
      mainIsolateReceivePort?.listen((message) async {
        try {
          await notificationTap(
            NotificationResponseJson.fromJsonString(message),
            client: client,
            l10n: l10n,
          );
        } catch (e, s) {
          Logs().wtf('Main Notification Tap crashed', e, s);
        }
      });

      // Additional port for Android background tab handling
      if (PlatformInfos.isAndroid) {
        final port = ReceivePort();
        IsolateNameServer.removePortNameMapping('background_tab_port');
        IsolateNameServer.registerPortWithName(
          port.sendPort,
          'background_tab_port',
        );
        port.listen((message) async {
          try {
            await notificationTap(
              NotificationResponseJson.fromJsonString(message),
              client: client,
              l10n: l10n,
            );
          } catch (e, s) {
            Logs().wtf('Main Notification Tap crashed', e, s);
          }
        });
      }

      // Initialize local notifications
      await _flutterLocalNotificationsPlugin.initialize(
        InitializationSettings(
          android: const AndroidInitializationSettings('notification_icon'),
          iOS: const DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(
            defaultActionName: 'Open notification',
            defaultIcon: AssetsLinuxIcon(
              'assets/splash/splash_dark.png',
            ), // User requested icon
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            notificationTap(response, client: client, l10n: l10n),
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      Logs().v('Flutter Local Notifications initialized');

      // Initialize UnifiedPush for Android/iOS
      if (Platform.isAndroid || Platform.isIOS) {
        await UnifiedPush.initialize(
          onNewEndpoint: _newUpEndpoint,
          onRegistrationFailed: (_, i) => _upUnregistered(i),
          onUnregistered: _upUnregistered,
          onMessage: _onUpMessage,
        );
        Logs().i('[Push] UnifiedPush initialized');
      }
    } catch (e, s) {
      Logs().e('Unable to initialize push notifications', e, s);
    }
  }

  BackgroundPush._(this.client) {
    _init();
  }

  factory BackgroundPush.clientOnly(Client client) {
    return _instance ??= BackgroundPush._(client);
  }

  factory BackgroundPush(
    Client client, {
    final void Function(String errorMsg, {Uri? link})? onFcmError,
  }) {
    final instance = BackgroundPush.clientOnly(client);
    instance.onFcmError = onFcmError;
    return instance;
  }

  Future<void> cancelNotification(String roomId) async {
    Logs().v('Cancel notification for room', roomId);
    await _flutterLocalNotificationsPlugin.cancel(roomId.hashCode);

    // Workaround for app icon badge not updating
    if (Platform.isIOS) {
      final unreadCount = client.rooms
          .where((room) => room.isUnreadOrInvited && room.id != roomId)
          .length;
      if (unreadCount == 0) {
        FlutterNewBadger.removeBadge();
      } else {
        FlutterNewBadger.setBadge(unreadCount);
      }
      return;
    }
  }

  Future<void> setupPusher({
    String? gatewayUrl,
    String? token,
    Set<String?>? oldTokens,
    bool useDeviceSpecificAppId = false,
  }) async {
    if (PlatformInfos.isAndroid) {
      _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    final clientName = PlatformInfos.clientName;
    oldTokens ??= <String>{};

    final pushers =
        await client.getPushers().catchError((e) {
          Logs().w('[Push] Unable to request pushers', e);
          return <Pusher>[];
        }) ??
        [];

    var setNewPusher = false;
    const appId = AppConfig.pushNotificationsAppId;
    var deviceAppId = '$appId.${client.deviceID}';

    // appId may only be up to 64 chars as per spec
    if (deviceAppId.length > 64) {
      deviceAppId = deviceAppId.substring(0, 64);
    }
    final thisAppId = useDeviceSpecificAppId ? deviceAppId : appId;

    if (gatewayUrl != null && token != null) {
      final currentPushers = pushers.where((pusher) => pusher.pushkey == token);
      if (currentPushers.length == 1 &&
          currentPushers.first.kind == 'http' &&
          currentPushers.first.appId == thisAppId &&
          currentPushers.first.appDisplayName == clientName &&
          currentPushers.first.deviceDisplayName == client.deviceName &&
          currentPushers.first.lang == 'en' &&
          currentPushers.first.data.url.toString() == gatewayUrl &&
          currentPushers.first.data.format ==
              AppSettings.pushNotificationsPusherFormat) {
        Logs().i('[Push] Pusher already set');
      } else {
        Logs().i('Need to set new pusher');
        oldTokens.add(token);
        if (client.isLogged()) {
          setNewPusher = true;
        }
      }
    } else {
      Logs().w('[Push] Missing required push credentials');
    }

    for (final pusher in pushers) {
      if ((token != null &&
              pusher.pushkey != token &&
              deviceAppId == pusher.appId) ||
          oldTokens.contains(pusher.pushkey)) {
        try {
          await client.deletePusher(pusher);
          Logs().i('[Push] Removed legacy pusher for this device');
        } catch (err) {
          Logs().w('[Push] Failed to remove old pusher', err);
        }
      }
    }

    if (setNewPusher) {
      try {
        await client.postPusher(
          Pusher(
            pushkey: token!,
            appId: thisAppId,
            appDisplayName: clientName,
            deviceDisplayName: client.deviceName!,
            lang: 'en',
            data: PusherData(
              url: Uri.parse(gatewayUrl!),
              format: AppSettings.pushNotificationsPusherFormat,
            ),
            kind: 'http',
          ),
          append: false,
        );
        Logs().i('[Push] Pusher set successfully');
      } catch (e, s) {
        Logs().e('[Push] Unable to set pushers', e, s);
      }
    }
  }

  static bool _wentToRoomOnStartup = false;

  Future<void> setupPush() async {
    Logs().d('SetupPush');
    if (client.onLoginStateChanged.value != LoginState.loggedIn ||
        !PlatformInfos.isMobile) {
      return;
    }

    // Do not setup unifiedpush if this has been initialized by an unifiedpush action
    if (upAction) {
      return;
    }

    // Setup UnifiedPush (FOSS alternative)
    await setupUp();

    // ignore: unawaited_futures
    _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((
      details,
    ) {
      if (details == null ||
          !details.didNotificationLaunchApp ||
          _wentToRoomOnStartup) {
        return;
      }
      _wentToRoomOnStartup = true;
      final response = details.notificationResponse;
      if (response != null) {
        notificationTap(response, client: client, l10n: l10n);
      }
    });
  }

  Future<void> setupUp() async {
    final distributors = await UnifiedPush.getDistributors();

    if (distributors.isEmpty) {
      // No UnifiedPush distributors available
      await loadLocale();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onFcmError?.call(
          l10n?.noUnifiedPushDistributor ??
              'No push notification distributor found. Install ntfy or another UnifiedPush app.',
          link: Uri.parse(AppConfig.enablePushTutorial),
        );
      });
      return;
    }

    await UnifiedPushUi(
      context: WidgetsBinding.instance.rootElement!,
      instances: ['default'],
      unifiedPushFunctions: UPFunctions(),
      showNoDistribDialog: true,
      onNoDistribDialogDismissed: () {},
    ).registerAppWithDialog();
  }

  Future<void> _newUpEndpoint(PushEndpoint newPushEndpoint, String i) async {
    final newEndpoint = newPushEndpoint.url;
    upAction = true;
    if (newEndpoint.isEmpty) {
      await _upUnregistered(i);
      return;
    }
    var endpoint =
        'https://matrix.gateway.unifiedpush.org/_matrix/push/v1/notify';
    try {
      final url = Uri.parse(newEndpoint)
          .replace(path: '/_matrix/push/v1/notify', query: '')
          .toString()
          .split('?')
          .first;
      final res = json.decode(
        utf8.decode((await http.get(Uri.parse(url))).bodyBytes),
      );
      if (res['gateway'] == 'matrix' ||
          (res['unifiedpush'] is Map &&
              res['unifiedpush']['gateway'] == 'matrix')) {
        endpoint = url;
      }
    } catch (e) {
      Logs().i(
        '[Push] No self-hosted unified push gateway present: $newEndpoint',
      );
    }
    Logs().i('[Push] UnifiedPush using endpoint $endpoint');

    await setupPusher(
      gatewayUrl: endpoint,
      token: newEndpoint,
      useDeviceSpecificAppId: true,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingKeys.unifiedPushEndpoint, newEndpoint);
    await prefs.setBool(SettingKeys.unifiedPushRegistered, true);
    upRegistered = true;
  }

  Future<void> _upUnregistered(String i) async {
    upAction = true;
    upRegistered = false;
    Logs().i('[Push] Removing UnifiedPush endpoint...');

    final prefs = await SharedPreferences.getInstance();
    final oldEndpoint = prefs.getString(SettingKeys.unifiedPushEndpoint);

    await prefs.remove(SettingKeys.unifiedPushEndpoint);
    await prefs.setBool(SettingKeys.unifiedPushRegistered, false);

    if (oldEndpoint != null && oldEndpoint.isNotEmpty) {
      // remove the old pusher
      await setupPusher(oldTokens: {oldEndpoint});
    }
  }

  Future<void> _onUpMessage(PushMessage pushMessage, String i) async {
    Logs().i('[MonoChat Push] _onUpMessage called');
    Logs().i(
      '[MonoChat Push] Message content length: ${pushMessage.content.length}',
    );

    try {
      final message = pushMessage.content;
      upAction = true;

      final decodedJson = json.decode(utf8.decode(message));
      Logs().i('[MonoChat Push] Decoded JSON keys: ${decodedJson.keys}');

      if (decodedJson['notification'] == null) {
        Logs().e('[MonoChat Push] No notification key in payload!');
        return;
      }

      final data = Map<String, dynamic>.from(decodedJson['notification']);
      Logs().i('[MonoChat Push] Notification data: $data');

      // UP may strip the devices list
      data['devices'] ??= [];

      // Get active room ID only if app is in foreground
      String? activeRoomId;
      try {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          final matrixService = MatrixService();
          activeRoomId = matrixService.activeRoomId;
          Logs().i(
            '[MonoChat Push] App is resumed, activeRoomId: $activeRoomId',
          );
        } else {
          Logs().i('[MonoChat Push] App is in background, activeRoomId: null');
        }
      } catch (e) {
        Logs().w('[MonoChat Push] Error getting activeRoomId: $e');
      }

      Logs().i('[MonoChat Push] Calling pushHelper...');

      await pushHelper(
        PushNotification.fromJson(data),
        client: client,
        l10n: l10n,
        activeRoomId: activeRoomId,
        flutterLocalNotificationsPlugin: _flutterLocalNotificationsPlugin,
        useNotificationActions: true,
      );

      Logs().i('[MonoChat Push] pushHelper completed');
    } catch (e, s) {
      Logs().e('[MonoChat Push] Error in _onUpMessage: $e', e, s);
      rethrow;
    }
  }
}

class UPFunctions extends UnifiedPushFunctions {
  final List<String> features = [];

  @override
  Future<String?> getDistributor() async {
    return await UnifiedPush.getDistributor();
  }

  @override
  Future<List<String>> getDistributors() async {
    return await UnifiedPush.getDistributors(features);
  }

  @override
  Future<void> registerApp(String instance) async {
    await UnifiedPush.register(instance: instance, features: features);
  }

  @override
  Future<void> saveDistributor(String distributor) async {
    await UnifiedPush.saveDistributor(distributor);
  }
}

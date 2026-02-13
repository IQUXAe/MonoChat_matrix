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

/// Maximum number of registration retries before giving up
const _maxRegistrationRetries = 3;

/// Base delay for exponential backoff (doubles each retry)
const _retryBaseDelay = Duration(seconds: 5);

/// Interval for periodic endpoint health checks
const _healthCheckInterval = Duration(minutes: 30);

/// HTTP timeout for gateway detection requests
const _gatewayDetectTimeout = Duration(seconds: 10);

/// Max size of the duplicate push message cache
const _deduplicationCacheSize = 64;

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

  /// Registration retry state
  int _registrationRetryCount = 0;
  Timer? _retryTimer;

  /// Periodic health check timer
  Timer? _healthCheckTimer;

  /// LRU cache for deduplicating incoming push messages
  final _recentPushHashes = <String>[];

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
          onRegistrationFailed: _onRegistrationFailed,
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

  /// Clean up timers and resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
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

    Logs().i('[Push] Available distributors: ${distributors.join(", ")}');

    await UnifiedPushUi(
      context: WidgetsBinding.instance.rootElement!,
      instances: ['default'],
      unifiedPushFunctions: UPFunctions(),
      showNoDistribDialog: true,
      onNoDistribDialogDismissed: () {},
    ).registerAppWithDialog();
  }

  /// Handle registration failure with exponential backoff retry
  void _onRegistrationFailed(FailedReason reason, String i) {
    Logs().w(
      '[Push] Registration failed (attempt ${_registrationRetryCount + 1}/$_maxRegistrationRetries): $reason',
    );
    upAction = true;

    if (_registrationRetryCount < _maxRegistrationRetries) {
      final delay = _retryBaseDelay * (1 << _registrationRetryCount);
      _registrationRetryCount++;
      Logs().i('[Push] Scheduling retry in ${delay.inSeconds}s...');

      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () async {
        Logs().i(
          '[Push] Retrying registration (attempt $_registrationRetryCount/$_maxRegistrationRetries)...',
        );
        try {
          await UnifiedPush.register(instance: 'default');
        } catch (e) {
          Logs().e('[Push] Retry registration call failed', e);
          // Will trigger _onRegistrationFailed again if it fails
        }
      });
    } else {
      Logs().e(
        '[Push] Registration failed after $_maxRegistrationRetries attempts. Giving up.',
      );
      _registrationRetryCount = 0;

      loadLocale();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onFcmError?.call(
          'Push registration failed after multiple attempts. Please try again from Settings.',
          link: Uri.parse(AppConfig.enablePushTutorial),
        );
      });
    }
  }

  Future<void> _newUpEndpoint(PushEndpoint newPushEndpoint, String i) async {
    final newEndpoint = newPushEndpoint.url;
    upAction = true;
    // Reset retry count on successful endpoint receipt
    _registrationRetryCount = 0;
    _retryTimer?.cancel();

    if (newEndpoint.isEmpty) {
      Logs().w('[Push] Received empty endpoint, treating as unregistered');
      await _upUnregistered(i);
      return;
    }

    Logs().i('[Push] Received new endpoint: ${_redactEndpoint(newEndpoint)}');

    final endpoint = await _detectGateway(newEndpoint);
    Logs().i('[Push] Using gateway: $endpoint');

    await setupPusher(
      gatewayUrl: endpoint,
      token: newEndpoint,
      useDeviceSpecificAppId: true,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingKeys.unifiedPushEndpoint, newEndpoint);
    await prefs.setBool(SettingKeys.unifiedPushRegistered, true);
    await prefs.setString(
      SettingKeys.unifiedPushLastSuccess,
      DateTime.now().toIso8601String(),
    );
    upRegistered = true;

    // Start periodic health checks
    _startHealthChecks();
  }

  /// Auto-detect the push gateway URL with multiple fallback strategies
  Future<String> _detectGateway(String endpoint) async {
    const fallbackGateway =
        'https://matrix.gateway.unifiedpush.org/_matrix/push/v1/notify';

    // Strategy 1: Check if the endpoint provider supports matrix gateway natively
    try {
      final url = Uri.parse(endpoint)
          .replace(path: '/_matrix/push/v1/notify', query: '')
          .toString()
          .split('?')
          .first;

      final res = json.decode(
        utf8.decode(
          (await http.get(Uri.parse(url)).timeout(_gatewayDetectTimeout))
              .bodyBytes,
        ),
      );

      if (res is Map) {
        // Check standard response format
        if (res['gateway'] == 'matrix') {
          Logs().i('[Push] Self-hosted gateway detected at $url');
          return url;
        }
        // Check extended response format (UnifiedPush spec v2)
        if (res['unifiedpush'] is Map &&
            res['unifiedpush']['gateway'] == 'matrix') {
          Logs().i('[Push] Self-hosted gateway (v2 format) detected at $url');
          return url;
        }
      }
    } catch (e) {
      Logs().i(
        '[Push] Self-hosted gateway probe failed for endpoint: ${_redactEndpoint(endpoint)} — $e',
      );
    }

    // Strategy 2: Check the endpoint root for gateway info
    try {
      final rootUri = Uri.parse(endpoint).replace(path: '/', query: '');
      final rootUrl = rootUri.toString().split('?').first;
      final rootRes = json.decode(
        utf8.decode(
          (await http
                  .get(Uri.parse('${rootUrl}_matrix/push/v1/notify'))
                  .timeout(_gatewayDetectTimeout))
              .bodyBytes,
        ),
      );
      if (rootRes is Map && rootRes['gateway'] == 'matrix') {
        final gatewayUrl = '${rootUrl}_matrix/push/v1/notify';
        Logs().i('[Push] Root gateway detected at $gatewayUrl');
        return gatewayUrl;
      }
    } catch (e) {
      Logs().v('[Push] Root gateway probe failed — $e');
    }

    Logs().i('[Push] Using public fallback gateway: $fallbackGateway');
    return fallbackGateway;
  }

  /// Redact endpoint URL for logging (keep host, hide path params)
  String _redactEndpoint(String endpoint) {
    try {
      final uri = Uri.parse(endpoint);
      return '${uri.scheme}://${uri.host}/...';
    } catch (_) {
      return '<invalid>';
    }
  }

  /// Start periodic health check timer
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) async {
      await _performHealthCheck();
    });
  }

  /// Verify endpoint is still valid and re-register if needed
  Future<void> _performHealthCheck() async {
    if (!upRegistered) return;

    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString(SettingKeys.unifiedPushEndpoint);

    if (endpoint == null || endpoint.isEmpty) {
      Logs().w('[Push] Health check: no saved endpoint');
      return;
    }

    try {
      // Check if the distributor is still available
      final distributor = await UnifiedPush.getDistributor();
      if (distributor == null || distributor.isEmpty) {
        Logs().e('[Push] Health check: distributor disappeared, cleaning up');
        upRegistered = false;
        await prefs.setBool(SettingKeys.unifiedPushRegistered, false);
        return;
      }

      // Verify the pusher is still registered on the server
      final pushers = await client.getPushers().catchError((e) {
        Logs().w('[Push] Health check: unable to fetch pushers', e);
        return <Pusher>[];
      });

      final hasPusher = pushers?.any((p) => p.pushkey == endpoint) ?? false;
      if (!hasPusher) {
        Logs().w(
          '[Push] Health check: pusher not found on server, re-registering',
        );
        // Re-register to restore the pusher
        await UnifiedPush.register(instance: 'default');
      } else {
        Logs().v('[Push] Health check: endpoint healthy');
        await prefs.setString(
          SettingKeys.unifiedPushLastSuccess,
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      Logs().w('[Push] Health check failed: $e');
    }
  }

  Future<void> _upUnregistered(String i) async {
    upAction = true;
    upRegistered = false;
    _healthCheckTimer?.cancel();
    Logs().i('[Push] Removing UnifiedPush endpoint...');

    final prefs = await SharedPreferences.getInstance();
    final oldEndpoint = prefs.getString(SettingKeys.unifiedPushEndpoint);

    await prefs.remove(SettingKeys.unifiedPushEndpoint);
    await prefs.setBool(SettingKeys.unifiedPushRegistered, false);
    await prefs.remove(SettingKeys.unifiedPushLastSuccess);

    if (oldEndpoint != null && oldEndpoint.isNotEmpty) {
      // remove the old pusher
      await setupPusher(oldTokens: {oldEndpoint});
    }
  }

  /// Check if a push message is a duplicate (deduplication via content hash)
  bool _isDuplicatePush(List<int> content) {
    final hash = content.fold<int>(0, (prev, b) => prev * 31 + b).toString();

    if (_recentPushHashes.contains(hash)) {
      return true;
    }

    _recentPushHashes.add(hash);
    if (_recentPushHashes.length > _deduplicationCacheSize) {
      _recentPushHashes.removeAt(0);
    }
    return false;
  }

  Future<void> _onUpMessage(PushMessage pushMessage, String i) async {
    final stopwatch = Stopwatch()..start();
    Logs().i('[Push] _onUpMessage called');
    Logs().i('[Push] Message content length: ${pushMessage.content.length}');

    try {
      final message = pushMessage.content;
      upAction = true;

      // Deduplicate: skip if we've seen this exact message recently
      if (_isDuplicatePush(message)) {
        Logs().i('[Push] Duplicate push message detected, skipping');
        return;
      }

      Map<String, dynamic> decodedJson;
      try {
        decodedJson = json.decode(utf8.decode(message)) as Map<String, dynamic>;
      } catch (e) {
        Logs().e('[Push] Failed to decode push payload: $e');
        return;
      }

      Logs().v('[Push] Decoded JSON keys: ${decodedJson.keys}');

      if (decodedJson['notification'] == null) {
        Logs().w('[Push] No notification key in payload, ignoring');
        return;
      }

      final data = Map<String, dynamic>.from(decodedJson['notification']);

      // UP may strip the devices list
      data['devices'] ??= [];

      // Get active room ID only if app is in foreground
      String? activeRoomId;
      try {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          final matrixService = MatrixService();
          activeRoomId = matrixService.activeRoomId;
          Logs().v('[Push] App is resumed, activeRoomId: $activeRoomId');
        } else {
          Logs().v('[Push] App is in background');
        }
      } catch (e) {
        Logs().w('[Push] Error getting activeRoomId: $e');
      }

      await pushHelper(
        PushNotification.fromJson(data),
        client: client,
        l10n: l10n,
        activeRoomId: activeRoomId,
        flutterLocalNotificationsPlugin: _flutterLocalNotificationsPlugin,
        useNotificationActions: true,
      );

      // Track last successful push receipt
      lastReceivedPush = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          SettingKeys.unifiedPushLastSuccess,
          lastReceivedPush!.toIso8601String(),
        );
      } catch (_) {}

      stopwatch.stop();
      Logs().i('[Push] Push processed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, s) {
      stopwatch.stop();
      Logs().e(
        '[Push] Error in _onUpMessage after ${stopwatch.elapsedMilliseconds}ms: $e',
        e,
        s,
      );
      // Don't rethrow — crashing the handler prevents future messages
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

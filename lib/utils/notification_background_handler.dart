/*
 *   MonoChat

 */

import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:matrix/matrix.dart';
import 'package:monochat/config/app_config.dart';
import 'package:monochat/config/setting_keys.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/utils/client_download_content_extension.dart';
import 'package:monochat/utils/matrix_locals.dart';
import 'package:monochat/utils/platform_infos.dart';
import 'package:monochat/core/navigation_service.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/utils/push_helper.dart';

bool _vodInitialized = false;

/// Global receive port for main isolate to listen for background notifications
ReceivePort? mainIsolateReceivePort;

extension NotificationResponseJson on NotificationResponse {
  String toJsonString() => jsonEncode({
    'type': notificationResponseType.name,
    'id': id,
    'actionId': actionId,
    'input': input,
    'payload': payload,
    'data': data,
  });

  static NotificationResponse fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, Object?>;
    return NotificationResponse(
      notificationResponseType: NotificationResponseType.values.singleWhere(
        (t) => t.name == json['type'],
      ),
      id: json['id'] as int?,
      actionId: json['actionId'] as String?,
      input: json['input'] as String?,
      payload: json['payload'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

Future<void> waitForPushIsolateDone() async {
  if (IsolateNameServer.lookupPortByName(AppConfig.pushIsolatePortName) !=
      null) {
    Logs().i('Wait for Push Isolate to be done...');
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  final sendPort = IsolateNameServer.lookupPortByName(
    AppConfig.mainIsolatePortName,
  );
  if (sendPort != null) {
    sendPort.send(notificationResponse.toJsonString());
    Logs().i('Notification tap sent to main isolate!');
    return;
  }
  Logs().i(
    'Main isolate not up - Create temporary client for notification tap intent!',
  );

  final pushIsolateReceivePort = ReceivePort();
  IsolateNameServer.registerPortWithName(
    pushIsolateReceivePort.sendPort,
    AppConfig.pushIsolatePortName,
  );

  if (!_vodInitialized) {
    await vod.init();
    _vodInitialized = true;
  }

  // Initialize MatrixService for background processing
  final matrixService = MatrixService();
  await matrixService.init(startSync: false);
  final client = matrixService.client;

  if (client == null) {
    Logs().e('Failed to init client in background');
    pushIsolateReceivePort.sendPort.send('DONE');
    IsolateNameServer.removePortNameMapping(AppConfig.pushIsolatePortName);
    return;
  }

  await client.abortSync();
  await client.init(
    waitForFirstSync: false,
    waitUntilLoadCompletedLoaded: false,
  );

  if (!client.isLogged()) {
    throw Exception('Notification tap in background but not logged in!');
  }
  try {
    await notificationTap(notificationResponse, client: client);
  } finally {
    await client.dispose(closeDatabase: false);
    pushIsolateReceivePort.sendPort.send('DONE');
    IsolateNameServer.removePortNameMapping(AppConfig.pushIsolatePortName);
  }
  return;
}

Future<void> notificationTap(
  NotificationResponse notificationResponse, {
  required Client client,
  AppLocalizations? l10n,
}) async {
  Logs().d(
    'Notification action handler started',
    notificationResponse.notificationResponseType.name,
  );
  final payload = MonoChatPushPayload.fromString(
    notificationResponse.payload ?? '',
  );
  switch (notificationResponse.notificationResponseType) {
    case NotificationResponseType.selectedNotification:
      final roomId = payload.roomId;
      if (roomId == null) return;

      // In background we can't navigate UI, just log
      Logs().v('Open room from notification tap', roomId);
      await client.roomsLoading;
      await client.accountDataLoading;
      if (client.getRoomById(roomId) == null) {
        await client
            .waitForRoomInSync(roomId)
            .timeout(const Duration(seconds: 30));
      }

      // Navigate to room using global key
      final room = client.getRoomById(roomId);
      if (room != null) {
        final context = navigatorKey.currentState?.context;
        if (context != null && navigatorKey.currentState != null) {
          // Check if we are already in the room to avoid stacking
          // This is a simple check, a more robust solution would be named routes or RouteAware
          // But for now, just pushing is safe enough as user tapped notification.
          navigatorKey.currentState!.push(
            CupertinoPageRoute(builder: (_) => ChatScreen(room: room)),
          );
        }
      }

    case NotificationResponseType.selectedNotificationAction:
      final actionType = MonoChatNotificationActions.values.singleWhereOrNull(
        (action) => action.name == notificationResponse.actionId,
      );
      if (actionType == null) {
        throw Exception('Selected notification with action but no action ID');
      }
      final roomId = payload.roomId;
      if (roomId == null) {
        throw Exception('Selected notification with action but no payload');
      }
      await client.roomsLoading;
      await client.accountDataLoading;
      await client.userDeviceKeysLoading;
      final room = client.getRoomById(roomId);
      if (room == null) {
        throw Exception(
          'Selected notification with action but unknown room $roomId',
        );
      }
      switch (actionType) {
        case MonoChatNotificationActions.markAsRead:
          await room.setReadMarker(
            payload.eventId ?? room.lastEvent!.eventId,
            mRead: payload.eventId ?? room.lastEvent!.eventId,
            public: AppSettings.sendPublicReadReceipts,
          );
        case MonoChatNotificationActions.reply:
          final input = notificationResponse.input;
          if (input == null || input.isEmpty) {
            throw Exception(
              'Selected notification with reply action but without input',
            );
          }

          final eventId = await room.sendTextEvent(
            input,
            parseCommands: false,
            displayPendingEvent: false,
          );

          if (PlatformInfos.isAndroid) {
            final ownProfile = await room.client.fetchOwnProfile();
            final avatar = ownProfile.avatarUrl;
            final avatarFile = avatar == null
                ? null
                : await client
                      .downloadMxcCached(
                        avatar,
                        thumbnailMethod: ThumbnailMethod.crop,
                        width: notificationAvatarDimension,
                        height: notificationAvatarDimension,
                        animated: false,
                        isThumbnail: true,
                        rounded: true,
                      )
                      .timeout(const Duration(seconds: 3));
            final messagingStyleInformation =
                await AndroidFlutterLocalNotificationsPlugin()
                    .getActiveNotificationMessagingStyle(room.id.hashCode);
            if (messagingStyleInformation == null) return;
            l10n ??= await lookupL10n(PlatformDispatcher.instance.locale);
            messagingStyleInformation.messages?.add(
              Message(
                input,
                DateTime.now(),
                Person(
                  key: room.client.userID,
                  name: l10n.you,
                  icon: avatarFile == null
                      ? null
                      : ByteArrayAndroidIcon(avatarFile),
                ),
              ),
            );

            await FlutterLocalNotificationsPlugin().show(
              room.id.hashCode,
              room.getLocalizedDisplayname(MatrixLocals(l10n)),
              input,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  AppConfig.pushNotificationsChannelId,
                  l10n.incomingMessages,
                  category: AndroidNotificationCategory.message,
                  shortcutId: room.id,
                  styleInformation: messagingStyleInformation,
                  groupKey: room.id,
                  playSound: false,
                  enableVibration: false,
                  actions: <AndroidNotificationAction>[
                    AndroidNotificationAction(
                      MonoChatNotificationActions.reply.name,
                      l10n.reply,
                      inputs: [
                        AndroidNotificationActionInput(
                          label: l10n.writeAMessage,
                        ),
                      ],
                      cancelNotification: false,
                      allowGeneratedReplies: true,
                      semanticAction: SemanticAction.reply,
                    ),
                    AndroidNotificationAction(
                      MonoChatNotificationActions.markAsRead.name,
                      l10n.markAsRead,
                      semanticAction: SemanticAction.markAsRead,
                    ),
                  ],
                ),
              ),
              payload: MonoChatPushPayload(
                client.clientName,
                room.id,
                eventId,
              ).toString(),
            );
          }
      }
  }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get chatsTitle => 'Чаты';

  @override
  String get syncing => 'Синхронизация...';

  @override
  String get newChat => 'Новый чат';

  @override
  String get messagePlaceholder => 'Сообщение';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get choosePhoto => 'Выбрать фото';

  @override
  String get chooseVideo => 'Выбрать видео';

  @override
  String get chooseFile => 'Выбрать файл';

  @override
  String get cancel => 'Отмена';

  @override
  String get joinRoom => 'Вступить';

  @override
  String youHaveBeenInvited(String roomName) {
    return 'Вас пригласили в\n$roomName';
  }

  @override
  String typingIndicator(String names) {
    return '$names печатает...';
  }

  @override
  String replyingTo(String user) {
    return 'Ответ $user';
  }

  @override
  String get waitingForMessage => 'Ожидание сообщения...';

  @override
  String get filePickerError =>
      'Не удалось открыть системный выбор файлов. Это часто случается на Linux дистрибутивах без сервиса \"xdg-desktop-portal\".';

  @override
  String get ok => 'ОК';

  @override
  String get error => 'Ошибка';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get saveImageTitle => 'Сохранить изображение?';

  @override
  String get saveImageContent => 'Вы хотите сохранить это изображение?';

  @override
  String get imageSavedSuccess => 'Изображение успешно сохранено.';

  @override
  String systemDialogError(String path) {
    return 'Системный диалог недоступен. Изображение сохранено в:\n$path';
  }

  @override
  String failedToSave(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get send => 'Отправить';

  @override
  String get tapToRetry => 'Нажмите, чтобы повторить';

  @override
  String get file => 'Файл';

  @override
  String get you => 'Вы';

  @override
  String get sendPhoto => 'Отпр. фото';

  @override
  String sendPhotos(int count) {
    return 'Отпр. $count фото';
  }

  @override
  String get sendVideo => 'Отпр. видео';

  @override
  String get sendFile => 'Отпр. файл';

  @override
  String sendFiles(int count) {
    return 'Отпр. $count файлов';
  }

  @override
  String totalSize(String size) {
    return 'Размер: $size';
  }

  @override
  String get calculating => 'Считаем...';

  @override
  String get willBeCompressed => 'Будет сжато';

  @override
  String get compress => 'Сжать';

  @override
  String get compressDescription => 'Уменьшить размер для быстрой отправки';

  @override
  String get settings => 'Настройки';

  @override
  String get profile => 'Профиль';

  @override
  String get unknownUser => 'Неизвестный пользователь';

  @override
  String get startConversation => 'Начать чат';

  @override
  String get sendMessage => 'Написать';

  @override
  String get ignoreUser => 'Игнорировать';

  @override
  String ignoreUserConfirmation(String userName) {
    return 'Вы уверены, что хотите игнорировать $userName? Вы больше не будете видеть сообщения от этого пользователя.';
  }

  @override
  String get ignore => 'Игнорировать';

  @override
  String get close => 'Закрыть';

  @override
  String get online => 'В сети';

  @override
  String get offline => 'Не в сети';

  @override
  String get justNow => 'Только что';

  @override
  String lastSeenMinutesAgo(int minutes) {
    return 'Был(а) $minutes мин назад';
  }

  @override
  String lastSeenHoursAgo(int hours) {
    return 'Был(а) $hoursч назад';
  }

  @override
  String lastSeenAt(String date) {
    return 'Был(а) $date';
  }

  @override
  String get newMessageInMonoChat => 'Новое сообщение';

  @override
  String get openAppToReadMessages =>
      'Откройте приложение, чтобы прочитать сообщения';

  @override
  String get incomingMessages => 'Входящие сообщения';

  @override
  String unreadChatsInApp(String appName, String count) {
    return '$count непрочитанных чатов в $appName';
  }

  @override
  String get directChats => 'Личные чаты';

  @override
  String get groups => 'Группы';

  @override
  String get reply => 'Ответить';

  @override
  String get writeAMessage => 'Написать сообщение...';

  @override
  String get markAsRead => 'Прочитано';

  @override
  String get noGoogleServicesWarning =>
      'Push-уведомления могут не работать без Google Play Services. Рассмотрите использование UnifiedPush.';

  @override
  String get oopsPushError => 'Ой! Произошла ошибка push-уведомлений.';

  @override
  String get notifications => 'Уведомления';

  @override
  String get pushProvider => 'Провайдер уведомлений';

  @override
  String get pushNotificationsNotAvailable => 'Push-уведомления недоступны';

  @override
  String get learnMore => 'Узнать больше';

  @override
  String get doNotShowAgain => 'Не показывать снова';

  @override
  String get noUnifiedPushDistributor =>
      'Не найден провайдер push-уведомлений. Установите ntfy или другое UnifiedPush приложение.';

  @override
  String get pushStatus => 'Статус';

  @override
  String get connected => 'Подключено';

  @override
  String get notConnected => 'Не подключено';

  @override
  String get pushDistributor => 'Дистрибьютор';

  @override
  String get noneSelected => 'Не выбран';

  @override
  String get pushEndpoint => 'Endpoint';

  @override
  String get selectPushDistributor => 'Выбрать провайдер';

  @override
  String get unregisterPush => 'Отключить уведомления';

  @override
  String get unregisterPushConfirm =>
      'Вы уверены, что хотите отключить push-уведомления?';

  @override
  String get unregister => 'Отключить';

  @override
  String get pushInfoText =>
      'MonoChat использует UnifiedPush для уведомлений — FOSS альтернативу проприетарным сервисам. Установите UnifiedPush дистрибьютор: ntfy, NextPush или Gotify.';

  @override
  String get learnMoreAboutUnifiedPush => 'Узнать больше о UnifiedPush →';

  @override
  String get notificationRules => 'Правила уведомлений';

  @override
  String get importantNotifications => 'Важные';

  @override
  String get advancedNotifications => 'Дополнительные';

  @override
  String get muteAllNotifications => 'Отключить все уведомления';

  @override
  String get allNotificationsMuted => 'Все уведомления отключены';

  @override
  String get notificationsEnabled => 'Уведомления включены';

  @override
  String get pushRuleMaster => 'Главный переключатель';

  @override
  String get pushRuleMasterDesc => 'Отключить все уведомления глобально';

  @override
  String get pushRuleSuppressNotices => 'Скрыть сообщения ботов';

  @override
  String get pushRuleSuppressNoticesDesc =>
      'Не уведомлять о системных сообщениях';

  @override
  String get pushRuleInviteForMe => 'Приглашения в комнаты';

  @override
  String get pushRuleInviteForMeDesc => 'Уведомлять о приглашениях';

  @override
  String get pushRuleMemberEvent => 'Изменения участников';

  @override
  String get pushRuleMemberEventDesc => 'Уведомлять о входах, выходах, киках';

  @override
  String get pushRuleUserMention => 'Упоминания (@вы)';

  @override
  String get pushRuleUserMentionDesc => 'Уведомлять, когда вас упоминают';

  @override
  String get pushRuleContainsDisplayName => 'Содержит имя';

  @override
  String get pushRuleContainsDisplayNameDesc =>
      'Уведомлять, когда упоминают ваше имя';

  @override
  String get pushRuleRoomMention => 'Упоминания комнаты (@room)';

  @override
  String get pushRuleRoomMentionDesc => 'Уведомлять при использовании @room';

  @override
  String get pushRuleRoomNotif => 'Уведомления комнаты';

  @override
  String get pushRuleRoomNotifDesc => 'Ключевые слова на уровне комнаты';

  @override
  String get pushRuleTombstone => 'Обновления комнат';

  @override
  String get pushRuleTombstoneDesc =>
      'Уведомлять об обновлениях версии комнаты';

  @override
  String get pushRuleReaction => 'Реакции';

  @override
  String get pushRuleReactionDesc => 'Уведомлять о реакциях на сообщения';

  @override
  String get pushRuleSuppressEdits => 'Скрыть редактирования';

  @override
  String get pushRuleSuppressEditsDesc =>
      'Не уведомлять о редактировании сообщений';

  @override
  String get pushRuleCall => 'Звонки';

  @override
  String get pushRuleCallDesc => 'Уведомлять о входящих звонках';

  @override
  String get pushRuleEncryptedDM => 'Зашифрованные ЛС';

  @override
  String get pushRuleEncryptedDMDesc =>
      'Уведомлять о зашифрованных личных чатах';

  @override
  String get pushRuleDM => 'Личные сообщения';

  @override
  String get pushRuleDMDesc => 'Уведомлять о личных чатах';

  @override
  String get pushRuleGroupMessage => 'Сообщения групп';

  @override
  String get pushRuleGroupMessageDesc => 'Уведомлять о сообщениях в группах';

  @override
  String get pushRuleEncryptedGroup => 'Зашифрованные группы';

  @override
  String get pushRuleEncryptedGroupDesc =>
      'Уведомлять о зашифрованных групповых чатах';

  @override
  String get pushRuleContainsUserName => 'Содержит имя пользователя';

  @override
  String get pushRuleContainsUserNameDesc =>
      'Уведомлять при упоминании username';

  @override
  String get pushRuleCustom => 'Пользовательское правило';

  @override
  String get pushRuleCategoryOverride => 'Приоритетные правила';

  @override
  String get pushRuleCategoryContent => 'Правила контента';

  @override
  String get pushRuleCategoryRoom => 'Правила комнат';

  @override
  String get pushRuleCategorySender => 'Правила отправителей';

  @override
  String get pushRuleCategoryUnderride => 'Стандартные правила';

  @override
  String get registeredDevices => 'Зарегистрированные устройства';

  @override
  String get noRegisteredDevices => 'Нет устройств с push-уведомлениями';

  @override
  String get removePusher => 'Удалить устройство';

  @override
  String get removePusherConfirm =>
      'Это устройство больше не будет получать push-уведомления. Продолжить?';

  @override
  String get remove => 'Удалить';

  @override
  String get troubleshooting => 'Устранение неполадок';

  @override
  String get sendTestNotification => 'Отправить тестовое уведомление';

  @override
  String get testNotificationSent => 'Тестовое уведомление отправлено!';

  @override
  String get copyPushEndpoint => 'Скопировать endpoint';

  @override
  String get endpointCopied => 'Endpoint скопирован';

  @override
  String get noEndpoint => 'Нет endpoint';

  @override
  String get noEndpointMessage => 'Push-уведомления ещё не настроены.';

  @override
  String get refreshPushStatus => 'Обновить статус';

  @override
  String get spaces => 'Пространства';

  @override
  String get allChats => 'Все чаты';

  @override
  String get add => 'Добавить';

  @override
  String get create => 'Создать';

  @override
  String get createSpace => 'Создать пространство';

  @override
  String get createSubspace => 'Создать подпространство';

  @override
  String get createGroup => 'Создать группу';

  @override
  String get spaceName => 'Название пространства';

  @override
  String get groupName => 'Название группы';

  @override
  String get topicOptional => 'Тема (необязательно)';

  @override
  String get spaceAlias => 'Псевдоним (например, my-space)';

  @override
  String get publicSpace => 'Публичное пространство';

  @override
  String get privateSpace => 'Приватное пространство';

  @override
  String get anyoneCanJoin => 'Любой может присоединиться';

  @override
  String get inviteOnly => 'Только по приглашению';

  @override
  String get spaceDescription =>
      'Пространства помогают организовать ваши комнаты и сообщества. Создавайте подпространства и добавляйте комнаты для построения структуры сообщества.';

  @override
  String get failedToCreateSpace => 'Не удалось создать пространство';

  @override
  String get spaceNotFound => 'Пространство не найдено';

  @override
  String get emptySpace => 'Это пространство пусто';

  @override
  String get addToSpace => 'Добавить в пространство';

  @override
  String get removeFromSpace => 'Удалить из пространства';

  @override
  String get moveToSpace => 'Переместить в другое пространство';

  @override
  String get leaveSpaceConfirmation =>
      'Вы уверены, что хотите покинуть это пространство?';

  @override
  String get leave => 'Покинуть';

  @override
  String get invite => 'Пригласить';

  @override
  String get members => 'участников';

  @override
  String get search => 'Поиск';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String get unread => 'Непрочитанные';

  @override
  String get directMessages => 'Личные сообщения';

  @override
  String get noChatsYet => 'Пока нет чатов';

  @override
  String get startAChat => 'Начать чат';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get newSpace => 'Новое пространство';

  @override
  String get publicGroup => 'Публичная группа';

  @override
  String get privateGroup => 'Приватная группа';

  @override
  String get enableEncryption => 'Включить шифрование';

  @override
  String get endToEndEncryption => 'Сквозное шифрование';

  @override
  String get inviteMembers => 'Пригласить участников';

  @override
  String get searchUsers => 'Поиск пользователей';

  @override
  String get noUsersFound => 'Пользователи не найдены';

  @override
  String get addMembers => 'Добавить участников';

  @override
  String selectedMembers(int count) {
    return '$count выбрано';
  }

  @override
  String get groupCreated => 'Группа успешно создана';

  @override
  String get createGroupDescription => 'Создать новую группу для общения';

  @override
  String get spaceCreated => 'Пространство успешно создано';

  @override
  String get filterChats => 'Фильтр чатов';

  @override
  String get pinned => 'Закреплённые';

  @override
  String get favorites => 'Избранное';

  @override
  String get muted => 'Без звука';

  @override
  String get searchable => 'Поиск';

  @override
  String get searchableDescription => 'Группу можно найти в публичном поиске';

  @override
  String get joinByTag => 'Присоединиться по тегу';

  @override
  String get enterTag => 'Введите тег комнаты (напр. #room:server.com)';

  @override
  String get invalidTag => 'Неверный тег или ID комнаты';

  @override
  String get join => 'Присоединиться';

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
  String get notificationsSettings => 'Настройки уведомлений';

  @override
  String get muteNotifications => 'Отключить уведомления';

  @override
  String get unmuteNotifications => 'Включить уведомления';

  @override
  String get notificationsMuted => 'Уведомления отключены';

  @override
  String get notificationsOn => 'Уведомления включены';

  @override
  String get mentionsOnly => 'Только упоминания';

  @override
  String get allMessages => 'Все сообщения';

  @override
  String get roomNotificationSuccess => 'Настройки уведомлений обновлены';

  @override
  String get roomNotificationError =>
      'Не удалось обновить настройки уведомлений';
}

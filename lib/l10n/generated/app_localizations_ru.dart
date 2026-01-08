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
}

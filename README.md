# maxim — клиент мессенджера MAX на Flutter

Сторонний клиент мессенджера MAX (`api.oneme.ru`), целевая платформа iOS, кодовая база на Flutter (запускается также на Android и Windows-desktop для разработки). Говорит с боевой сетью MAX по родному бинарному протоколу — 10-байтный кадр + msgpack + распаковка тела (LZ4). Трафик неотличим от официального клиента, поэтому идёт там же, где MAX не режется оператором.

Протокол восстановлен из наработок: Python-клиент `telega-to-max`, пакет `maxclient` (реверс десктопного MAX) и декомпил APK. Сводная спецификация — [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Что работает

- Авторизация: SMS + 2FA, вход по готовому токену, восстановление сессии. Стабильный `deviceId`, официально-выглядящий `userAgent` (anti-ban).
- Список чатов наполняется из снэпшота LOGIN (`interactive=true`) + добор названий через `CHAT_INFO`; байт-скан id чатов из сырого ответа как fallback.
- Сообщения: отправка (полный payload `cid/detectShare/notify`), приём (push), пагинация истории, редактирование (op 67), статусы/outbox с повторной отправкой.
- Медиа: фото/видео/файлы — двухступенчатый upload, скачивание, галерея чата (op 51), транскрипция голосовых (op 202).
- Контакты: импорт адресной книги, поиск по номеру (троттлинг как anti-spam).
- Push-события по опкодам: удаление (142) применяется к БД; read/reactions/transcription доставляются типизированным потоком.
- Системные события чата (`_type=CONTROL`) — человекочитаемый текст.
- Активные сессии: список устройств (op 96), завершение чужой сессии (op 97).
- Глобальный поиск по тексту сообщений (Unicode-aware) и по названиям чатов.
- Устойчивость: авто-реконнект с backoff, DNS-over-HTTPS fallback (`1.1.1.1`/`8.8.8.8` по IP с сохранением SNI и проверки сертификата) против DNS-блокировки.
- iOS: Cupertino-переходы со свайпом-назад, адаптивные контролы, `Info.plist` с разрешениями, display name `MAX`.

## Стек

Flutter 3.29+/Dart 3.7+, Riverpod 2, sqflite (+ `sqflite_common_ffi` на desktop), `flutter_secure_storage`, `msgpack_dart`, `http`, `cached_network_image`, `image_picker`/`file_picker`, `flutter_contacts`.

## Структура

```
lib/
  core/                 константы протокола (host, proto v10, app 26.15.0), ошибки
  data/
    max/
      max_client.dart   TLS+DoH, кадры, опкоды, push-потоки
      max_codec.dart    упаковка/распаковка кадров, msgpack
      lz4_block.dart    чистый Dart LZ4-декомпрессор тела кадра
      snapshot.dart     разбор снэпшота LOGIN -> чаты/контакты/профиль
      control_event.dart текст системных событий CONTROL
      raw_parsers.dart  байтовые парсеры (extractChatIds и т.п.)
      device_profile.dart официальный userAgent (anti-ban)
      models/           message, chat, contact, attach, session, push_event, ...
    local/              sqflite (схема v6) + secure storage
    repositories/       auth, chats, messages, contacts, media, upload, sync
  state/                Riverpod-провайдеры и контроллеры
  ui/                   screens (splash/login/chats/chat/profile/contacts/
                        media/sessions/settings), widgets, theme (палитра MAX)
bin/maxim_cli.dart      headless-клиент на том же MaxClient
docs/                   PROTOCOL, MEDIA_OPCODES, ROADMAP-этапы (STAGE_XX), GITHUB
```

## Сборка и запуск

```
flutter pub get
flutter analyze        # чисто
flutter test           # 57 кейсов
```

- iOS (нужен Mac + Xcode): `cd ios && pod install && cd .. && flutter run -d <id>`.
- Windows desktop (для отладки UI): включить Developer Mode (`start ms-settings:developers`), затем `flutter run -d windows`.

### Проверка ядра без Mac (headless)

`bin/maxim_cli.dart` использует тот же `MaxClient`. Положи auth-token в `max_token.txt` и:

```
dart run bin/maxim_cli.dart
```

После входа печатается `Снэпшот логина: ... чатов(декод)=N ...`; команда `chats` — список, `send/hist/find/me` — операции. Это прямая проверка на боевом сервере без GUI. Заливка на GitHub — [docs/GITHUB.md](docs/GITHUB.md).

## Известные ограничения

- Отправка реакций — опкод не реверснут (не угадываем).
- Точные схемы payload push read/reactions/transcription не подтверждены: события доставляются, но в БД пишется только безопасное удаление.
- zstd-кадры (`cof=0xFF`) не распаковываются (редки; зрелого pure-Dart zstd нет).
- Пиксель-в-пиксель совпадение с iOS-обликом MAX требует референс-скриншотов и Mac для визуальной итерации.
- `app_version` (`26.15.0`) при мажорном обновлении официального MAX может потребовать поднятия.

## Дисклеймер

Учебный/исследовательский протокол-совместимый клиент для собственного аккаунта MAX. Использует реверс-инжиниринг протокола; не аффилирован с MAX/VK. Антифрод MAX работает по номеру/IP/поведению — детали и меры в [docs/PROGRESS.md](docs/PROGRESS.md) (Этап 7).

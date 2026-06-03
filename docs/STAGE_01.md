# Этап 1 — Бутстрап проекта

Дата: 2026-06-04. Цель: поднять чистую ветку `maxim` в каталоге `max iso` из наработки `max new maxim`, верифицировать рабочее состояние, инициализировать git.

## Сделано

- Перенесён проект `maxim_messenger` из `max new maxim` в `max iso` через robocopy. Исключены генерируемые/тяжёлые каталоги (`build`, `.dart_tool`, `.git`, `.idea`, `.gradle`, `ephemeral`, `Pods`) и устаревшие plugin-файлы (`.flutter-plugins*`, `*.iml`) — они содержали абсолютные пути к старому расположению и регенерируются.
- Итог копирования: 157 файлов, 62 каталога, 630 КБ исходников (без бинарей).
- `flutter pub get` — зависимости встали (`Got dependencies!`). Exit 1 — это лишь Windows-предупреждение про symlink/Developer Mode, оно относится к desktop-сборке, не к iOS-таргету и не к разрешению зависимостей.

## Верификация

- `flutter analyze` — чисто, **No issues found** (7.5 с).
- `flutter test` — **23/23 зелёных**: `lz4_test` (LZ4 round-trip), `max_codec_test` (раскладка кадра), `device_profile_test` (порядок полей userAgent), `attach_test`, `message_test`, `upload_input_test`, `reconnect_test`, `widget_test` (рендер LoginScreen).

## Состояние базы

Перенесённый код — это рабочий клиент MAX: реальный wire-протокол (TLS `api.oneme.ru:443`, 10-байтный заголовок + msgpack + LZ4-распаковка), auth SMS/2FA/token, опкоды 6/16/17/18/19/32/46/48/49/51/64/65/67/80–88/115/136/202/293, локальная БД (sqflite, схема v6), Riverpod, экраны splash/login/chats/chat/profile/contacts/media/settings, Material 3 тема с палитрой MAX (#0066FF).

## Документация этапа

- Заведена дорожная карта [ROADMAP.md](../ROADMAP.md).
- Сведена спецификация протокола [docs/PROTOCOL.md](PROTOCOL.md) из трёх реверс-реализаций.
- Унаследованы как исторический референс [docs/PROGRESS.md](PROGRESS.md) (этапы 0–7 прежнего репозитория) и [docs/MEDIA_OPCODES.md](MEDIA_OPCODES.md).

## Главный незакрытый пробел (вход в Этап 2)

После LOGIN (op 19, `interactive=true`) снэпшот с чатами приходит и распаковывается LZ4, но не парсится в локальную БД — главный экран не наполняется. Это первоочередная задача Этапа 2.

## Git

Инициализирован новый репозиторий, первый коммит — перенесённая база + документация этапа.

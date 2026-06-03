# Этап 2a — Ядро мессенджинга: чаты после входа

Дата: 2026-06-04. Цель: устранить главный функциональный пробел — после входа главный экран пуст, хотя сервер присылает чаты.

## Корневая причина

`MaxClient.login()` слал `interactive: false`. Проверенный рабочий `web_demo/bridge.py` прямо документирует (строка 332):

> `interactive=True` заставляет сервер вернуть полный снэпшот: профиль + контакты + чаты. При False чаты не приходят.

То есть клиент логинился, но снэпшот с чатами сервер не отдавал, а даже если бы отдал — `login()` возвращал сырые байты и никуда их не парсил.

## Сделано

- **`max_client.dart`**:
  - `login(token, {interactive = true})` — по умолчанию запрашивает полный снэпшот, таймаут поднят до 45 с (снэпшот ~200+ КБ, едет LZ4). Декодированный снэпшот кешируется в `lastLoginSnapshot` и возвращается вызывающему.
  - `reconnect()` логинится с `interactive: false` — на переподключении чаты уже в БД, трафик не дублируется.
  - `sendMessage()` шлёт полный payload официального клиента: `message:{cid, text, detectShare:true}`, `notify:true`, `randomId == cid` (раньше — только `{text}` + `randomId`). Источник формы: `bridge.py` + `maxclient`.
- **`snapshot.dart`** (новый, чистая функция) — `parseLoginSnapshot(decoded)`: порт `extract_chats`/`_peer_name` из `bridge.py`. Терпим к формату: `chats`/`contacts` приходят как list ЛИБО как map `{id: obj}` (WEB vs ANDROID). Разбирает профиль (id/имя), чаты (id, title/name/имя собеседника из participants со скипом себя, lastMessage→preview/time, unread из newMessages/unread/unreadCount, isGroup по type/membersCount), контакты.
- **`sync_repository.dart`** (новый) — `applyLoginSnapshot()`: пишет профиль (myUserId), контакты и чаты в БД. У существующих чатов сохраняет локальные флаги (pin/archive/mute), обновляя контент. Не бросает: ошибка синка не валит уже состоявшийся вход.
- **`providers.dart`** — `syncRepositoryProvider`.
- **`session_controller.dart`** — `_syncAfterLogin()` вызывается на всех четырёх путях входа (восстановление сессии, SMS, 2FA, вход по токену) перед переходом в `signedIn`, затем `invalidate(chatsListProvider)` — главный экран читает уже наполненную БД.

## Верификация

- `flutter analyze` — чисто.
- `flutter test` — 31 кейс зелёный, включая новый `snapshot_test.dart` (7 кейсов: list-формат, map-формат, имя собеседника со скипом себя, контакты, профиль, группа vs диалог, пропуск чата без id).

## Честный статус проверки

Сквозная проверка «реальные чаты с боевого сервера» требует живого входа (токен либо SMS) и запуска приложения/CLI — это действие пользователя (на Windows нужен Developer Mode для desktop-сборки либо Mac для iOS). Логика порта дословно повторяет проверенный `bridge.py`, парсер покрыт юнит-тестами на синтетических снэпшотах. Уверенность высокая, но финальное подтверждение — за живым логином.

## Перенесено в Этап 2b

Opcode-aware обработка push (NOTIF_MARK 130, NOTIF_MSG_DELETE 142, NOTIF_REACTIONS 155, NOTIF_TRANSCRIPTION 293), inbound typing, DNS-over-HTTPS, zstd-кадры (`cof=0xFF`). Приём новых сообщений (NOTIF_MESSAGE 128) уже работает через текущий `_parsePush`.

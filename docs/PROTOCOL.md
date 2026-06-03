# Протокол MAX — консолидированная спецификация

Сведено из трёх рабочих реверс-реализаций: `telega to max/max_client.py`, `max exe python/maxclient/`, и Dart-клиента `lib/data/max/`. Это единый источник правды по wire-протоколу для `maxim`.

## Транспорт

- Хост: `api.oneme.ru`, порт `443`, TLS поверх TCP (длинный сокет, фоновый цикл чтения).
- `tcpNoDelay = true`.
- Реконнект с экспоненциальным backoff: 2 → 4 → 8 → 16 → 32 → 60 с.
- DNS-over-HTTPS fallback: при сбое системного DNS — резолв через 1.1.1.1 (Cloudflare) и 8.8.8.8 (Google) по IP, SNI сохраняется. Снижает эффект DNS-блокировки.

## Формат кадра

10-байтный бинарный заголовок (big-endian) + тело.

| Смещение | Длина | Поле | Назначение |
| --- | --- | --- | --- |
| 0 | 1 | proto_ver | Версия протокола, фиксировано `10` |
| 1 | 1 | cmd | 0 = запрос/push; 1 = успешный ответ; иные = ошибки/состояния |
| 2–3 | 2 | seq | Номер последовательности (uint16), матчит запрос с ответом |
| 4–5 | 2 | opcode | Код операции (uint16) |
| 6–9 | 4 | length | uint32; старший байт = флаг сжатия `cof`, длина тела = `length & 0x00FFFFFF` |

seq — счётчик 0..0xFFFF, по кругу. Ответ сервера несёт тот же seq; нематченные кадры (или `cmd=0` с неизвестным seq) — это server push.

## Сжатие тела (cof)

Старший байт поля длины — флаг компрессии. Это была корневая причина всех ранних багов парсинга.

- `cof == 0` — тело не сжато.
- `cof == 0xFF` — zstd (редко; в Dart пока не распаковывается — TODO Этап 5).
- `cof > 0` — LZ4 block, размер после распаковки = `payload_len * cof`.

Распаковка идёт ДО msgpack. Источник формата: декомпил APK (`e1d.java` — кадр, `lp.java:172-191` — диспетчер zstd/LZ4). Dart-реализация: `lib/data/max/lz4_block.dart` (чистый Dart, без FFI, тест round-trip против python-lz4 — 21/21).

## Кодек тела

MessagePack (`use_bin_type=True`, строковые ключи). Из-за компактного/ref-кодирования в больших ответах (LOGIN op 19, HISTORY op 49) стандартный unpacker иногда падает — применяется fallback: попытки декода со смещений 0,1,2,3,4 (`max_codec.tryUnpack`), затем байтовый парсер по сигнатурам ключей (`raw_parsers.dart`):

```
"id"=\xa2id  "text"=\xa4text  "time"=\xa4time
"sender"=\xa6sender  "chatId"=\xa6chatId  "messages"=\xa8messages
int: \xd2 int32, \xd3 int64, \xcc-\xcf uint8-64, 0x00-0x7f fixint
str: 0xa0-0xbf fixstr, \xd9 str8, \xda str16, \xdb str32
```

## Опкоды

### Auth / сессия
| Op | Имя | Payload запроса |
| --- | --- | --- |
| 6 | INIT | `{userAgent:{...}, deviceId}` — handshake |
| 16 | PROFILE | `{}` |
| 17 | AUTH_REQUEST | `{phone, type:"START_AUTH"}` → verify-token в raw-ответе |
| 18 | AUTH_CONFIRM | `{token, verifyCode, authTokenType:"CHECK_CODE"}` → auth-token либо 2FA trackId |
| 19 | LOGIN | `{token, interactive, chatsCount, chatsSync, contactsSync, presenceSync, draftsSync}` — снэпшот в raw |
| 20 | LOGOUT | `{}` |
| 115 | TWO_FA | `{trackId, password}` → финальный auth-token |
| 96 | SESSIONS_INFO | `{}` — список активных сессий |
| 97 | SESSIONS_CLOSE | `{sessionIds:[int]}` |

### Контакты / чаты / сообщения
| Op | Имя | Payload запроса |
| --- | --- | --- |
| 32 | CONTACT_INFO | `{contactIds:[int]}` |
| 46 | CONTACT_INFO_BY_PHONE | `{phone}` — троттлить (anti-fraud), 1.1–1.8 с, кап 50 |
| 48 | CHAT_INFO | `{chatIds:[int]}` |
| 49 | CHAT_HISTORY | `{chatId, from, forward, backward}` |
| 51 | CHAT_MEDIA | `{chatId, messageId?, attachTypes:[...], forward?, backward?}` |
| 64 | MSG_SEND | см. ниже |
| 65 | TYPING | `{chatId, typing:bool}` |
| 67 | MSG_EDIT | `{chatId, messageId, text?, attachments?, elements?}` |

### Медиа (двухступенчатый upload)
| Op | Имя | Payload запроса |
| --- | --- | --- |
| 80 | PHOTO_UPLOAD | `{count, profile:bool}` → upload URL + `photoToken` |
| 81 | STICKER_UPLOAD | поля не реверснуты (вероятно как PHOTO) |
| 82 | VIDEO_UPLOAD | `{type, count, uploaderType}` (VIDEO/VIDEO_MSG/AUDIO) |
| 83 | VIDEO_PLAY | `{videoId, chatId?, messageId?, token?}` → play URL |
| 87 | FILE_UPLOAD | `{count}` → upload URL + token/fileId |
| 88 | FILE_DOWNLOAD | `{fileId, chatId, messageId}` → `{url, unsafe}` |
| 202 | TRANSCRIBE_MEDIA | `{mediaId, chatId, messageId}` |

### Server push (ответ не нужен)
| Op | Имя | Назначение |
| --- | --- | --- |
| 128 | NOTIF_MESSAGE | Новое сообщение `{chatId, message:{id, sender, text, time, attaches?}}` |
| 130 | NOTIF_MARK | Обновление прочитанности |
| 136 | NOTIF_ATTACH | Статус attach (видео доконвертилось и т.п.) |
| 142 | NOTIF_MSG_DELETE | Сообщение удалено |
| 155 | NOTIF_REACTIONS | Реакции изменились |
| 293 | NOTIF_TRANSCRIPTION | Транскрипция готова |

## Аутентификация (последовательность)

1. INIT (6) с `deviceType=ANDROID` (или `WEB` для веб-токенов).
2. AUTH_REQUEST (17) → verify-token (извлекается из raw как самая длинная строка из набора `[A-Za-z0-9_\-+.~=]`, >100 символов).
3. AUTH_CONFIRM (18) → либо auth-token, либо маркер `passwordChallenge` + `trackId` (UUID) при включённой 2FA.
4. (если 2FA) TWO_FA (115) → финальный auth-token.
5. LOGIN (19) — основная инициализация сессии; в raw-ответе снэпшот `{profile, chats[], messages, contacts, presence, config, token, updates}`.

Особенности:
- Токены привязаны к типу устройства: WEB-токен (из web.max.ru) принимается только при `deviceType=WEB`; ANDROID-токен (по SMS) — при `deviceType=ANDROID`. Несовпадение → `FAIL_LOGIN_TOKEN`. Клиент умеет авто-ретрай с альтернативным типом.
- `deviceId` — UUID v4, СТАБИЛЬНЫЙ на установку (anti-ban: новый UUID на каждый запуск = поток «устройств» на одном номере). Хранится в secure storage, переживает logout.
- Под VPN с локацией вне reg-country сервер выключает phone-auth (`phone-auth-enabled:false`).

## MSG_SEND (op 64) — полный payload

Текущий Dart-клиент шлёт усечённо (`{chatId, message:{text, attaches?, replyTo?}, randomId}`). Официальный клиент (и `maxclient`) шлёт полнее — Этап 2 приводит к этой форме:

```
{
  "chatId": int,            // либо "userId" для диалога
  "message": {
    "cid": int,             // client id = millis, дедуп/порядок
    "text": str,
    "detectShare": bool,    // true = включить превью ссылок
    "isLive": bool,         // false для обычных
    "attaches": [ {...} ],  // опционально
    "elements": [...],      // форматирование/упоминания (опционально)
    "link": {...}           // reply/forward (опционально)
  },
  "notify": bool,           // true = слать нотификацию получателю
  "randomId": int           // == cid, для дедупа
}
```

Входящее сообщение (push 128 или history): `{id, sender, text, time, attaches?[{_type, baseUrl(https://i.oneme.ru/...), width, height, duration, name, mime, size, ...}]}`.

Дедуп входящих: по `(chatId, message.id)` — сервер может прислать своё же эхо.

## Attach (`message.attaches[]`)

Обязательное поле `_type` из набора: `UNKNOWN, CONTROL, PHOTO, VIDEO, AUDIO, STICKER, SHARE, APP, CALL, FILE, CONTACT, PRESENT, INLINE_KEYBOARD, LOCATION, REPLY_KEYBOARD, VIDEO_MSG, WIDGET, POLL`.

- PHOTO: `{_type, photoToken}`
- VIDEO: `{_type, videoId|token, videoType, wave?, duration?, thumbhash?}`
- AUDIO: `{_type, audioId|token, wave?, duration?}`
- FILE: `{_type, fileId|token}`
- STICKER: `{_type, stickerId}`
- CONTROL: системные события чата `{_type:"CONTROL", event:"new|add|remove|title|icon|pin|...", userId?/userIds?, title?, photoToken?, chatType?}`

Двухступенчатый upload: запрос URL (80/82/87) → multipart HTTP POST бинарника → токен в ответе (`photoToken`/`token`/`videoId`/`fileId`) → токен в `attach` внутри MSG_SEND (64). Парсинг ответа upload терпим к вариантам ключей (`url`/`uploadUrl`/`endpoint`, вложенность в `result`/`data`/`response`).

## Константы

- proto_ver = `10`.
- appVersion: текущий код — `26.15.0`, build `6689` (синхронизирован с официальным APK). `telega to max` использовал `26.11.0` — при рассинхроне ориентироваться на свежий APK.
- locale = `ru`.
- deviceType: `ANDROID` (SMS-auth) или `WEB` (веб-токен).
- userAgent для ANDROID — 11 полей в строгом порядке официального клиента (`pushDeviceType` второй, `deviceType` в upper-case), реальные значения через `device_info_plus`. WEB — минимальный (3 поля, проверенная рабочая форма). Реализация: `lib/data/max/device_profile.dart`.

## Anti-ban (резюме)

Антифрод работает по номеру/IP/поведению, не по анализу клиента. TLS/JA3 сервером не проверяется — подделка бессмысленна. Что реально снижает риск: стабильный deviceId, полный официальный userAgent, отказ от скрейпинга контактов (троттлинг op 46) и спам-рассылок, отказ от датацентровых/иностранных VPN-IP (сервер собирает VPN-флаг через `HOST_REACHABILITY`). Что не лечится клиентом: репутация номера, скорость поддержки. Подробно — [docs/PROGRESS.md](PROGRESS.md), Этап 7.

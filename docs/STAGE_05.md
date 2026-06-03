# Этап 5 — Расширенные функции и устойчивость (в работе)

## DNS-over-HTTPS fallback — против блокировки оператором (2026-06-04)

Прямо отвечает на требование «чтобы не блокировал оператор»: частый способ блокировки — фильтрация/подмена DNS у провайдера, когда сам IP сервера доступен. Порт `_open_raw_socket`/`_doh_resolve` из `maxclient`.

Логика в `MaxClient._openSecureSocket`:
1. Сначала обычный `SecureSocket.connect(api.oneme.ru:443)`.
2. При `SocketException` (DNS не резолвится / режется) — резолвим A-запись через DNS-over-HTTPS: `https://1.1.1.1/dns-query?name=api.oneme.ru&type=A` и `https://8.8.8.8/resolve?...`, заголовок `accept: application/dns-json`. Endpoint'ы заданы по IP, поэтому сами не зависят от системного DNS.
3. Коннектимся к полученному IP raw-сокетом, затем `SecureSocket.secure(raw, host: 'api.oneme.ru')` — TLS-хендшейк идёт с правильным SNI, сертификат валидируется против реального хоста. Обхода TLS нет: соединение остаётся доверенным.

Если DoH тоже недоступен — честная ошибка `MaxNotConnected` («проверьте интернет, DNS или VPN»), без зацикливания.

Разбор JSON вынесен в чистую `parseDohAnswer(body)` (берёт первую A-запись `type==1`), покрыт `doh_test.dart` (4 кейса: Cloudflare-ответ, пропуск CNAME, нет Answer, мусор).

Важно: TLS/JA3 сервер MAX не проверяет (см. PROGRESS Этап 7), поэтому DoH-обход DNS — рабочая мера, а не подделка клиента. Что DoH НЕ лечит: блокировку по самому IP сервера и блокировку по номеру/репутации.

Проверка: `flutter analyze` чисто; `flutter test` 38/38.

## Opcode-aware push-события (2026-06-04)

`MaxClient` раскладывает server-push по опкоду в типизированный поток `pushEvents` (`classifyPushEvent`): 130 read, 142 deleted, 155 reactions, 293 transcription. NOTIF_MESSAGE (128) по-прежнему идёт в `incomingStream`. `MessagesRepository._onEvent` мутирует БД ТОЛЬКО на явном удалении по серверному id (`deleteMessageByServerId`); read/reactions/transcription прокинуты на будущее без догадок о схеме. id сообщений для удаления берутся только из декодированной карты (не из байт-скана) — чтобы не удалить чужое. `push_event_test` — 7 кейсов.

## Системные события чата (CONTROL) (2026-06-04)

Входящее сообщение может нести attach `_type=CONTROL` (создание чата, добавление/удаление участника, смена названия/аватара, закреп). Раньше он ошибочно мапился в FILE. Теперь `controlEventText` (чистая, по docs/MEDIA_OPCODES.md) превращает событие в человекочитаемый текст, который становится текстом сообщения; как медиа CONTROL больше не сохраняется. `control_event_test` — 6 кейсов.

## Активные сессии (op 96/97) (2026-06-04)

`MaxClient.sessionsInfo()` (96) и `sessionsClose(ids)` (97). Чистый парсер `parseSessions` (модель `MaxSession`, терпим к именам полей: id/sessionId, name/appName/deviceName, device/deviceType/platform, lastSeen/lastActiveTime, isCurrent), покрыт `session_test` (4 кейса). UI: `SessionsScreen` (список устройств, завершение чужой сессии), вход из «Настройки → Активные сессии».

## Глобальный поиск по сообщениям (2026-06-04)

`AppDatabase.searchMessages(query)` — поиск по тексту во всех чатах. SQLite `LOWER()` кириллицу не приводит к нижнему регистру, поэтому регистронезависимость делаем в Dart (Unicode-aware `toLowerCase`) над 2000 свежих сообщений. `messageSearchProvider` (family по запросу). В `ChatsListScreen` при поиске список делится на секции «Чаты» и «Сообщения», тап по найденному сообщению открывает чат. Появилась инфраструктура DB-тестов (in-memory ffi, `AppDatabase.forDb`/`createSchemaForTest`); `database_search_test` — 2 кейса (кириллица регистронезависимо, лимит).

## Тема оформления (2026-06-04)

Ручной выбор темы (системная/светлая/тёмная) с персистом в secure storage (`themeModeProvider`, не стирается при logout). `app.dart` watch'ит провайдер, в настройках — выбор через диалог. Чистый маппинг `themeModeFromString`/`toString` покрыт `theme_controller_test` (3 кейса).

## Осталось в этапе

- Реакции (отправка) — опкод отправки не реверснут, без догадок не делаем.
- zstd-распаковка кадров (`cof=0xFF`) — нет зрелого pure-Dart zstd, FFI тянет нативную зависимость; кадры редки, пока graceful-лог.
- Точные схемы payload для read/reactions/transcription-push требуют живого pcap (эталонные клиенты их не парсят): события доставляются, но в БД пишется только безопасное удаление.

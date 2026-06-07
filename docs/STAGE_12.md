# Этап 12 — Переезд на master форка + марафон фиксов на устройстве (2026-06-07/08)

Версии `0.2.0 → 0.2.8`. Ветка `adopt-master`. По решению владельца взяли его
рабочий форк `github.com/sansmaster1982/maxim-messenger` (ветка master, 5fc4b1c)
за основу: он на Android работает лучше старого max iso (корректные имена,
медиа, устойчивость). Наша iOS-обвязка (подпись/CI/bundle id) сохранена.

## Что сделано

### 1. Adopt master как основа (0.2.0)
Кодовые базы max iso и форка разошлись почти полностью (~50 файлов), поэтому не
порт кусков, а замена: `lib/` + `test/` + `bin/` ← из master; `ios/`,
`.github/workflows`, подпись `Release.xcconfig` manual distribution, bundle id
`com.sansmaster.maxim`, Info.plist, иконки — НАШИ. Зависимости в pubspec
идентичны, оставили наш (с icon-конфигом). Собралось и залилось в TestFlight.

### 2. Диагностика на устройстве без Mac (0.2.1)
Главное открытие отладки: **в release-сборке Flutter `print`/logger НЕ попадают
в os_log iPhone** — idevicesyslog показывает только системные логи iOS. Решение:
- `providers.kDeviceDiagnostics`: ProductionFilter + SimplePrinter, логи идут и
  в release.
- `main._initDiagLog`: дублируем лог в `Documents/maxim_diag.log`.
- Info.plist: `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` —
  открывает Documents для afc.
- Инструмент: `pymobiledevice3` (pip), напрямую по USB видит устройство, тянет
  лог и SQLite-базу (`apps pull com.sansmaster.maxim Documents/...`). Это и стало
  «logcat для iOS», по которому добили все баги.

### 3. Цепочка багов и фиксов (по версиям)

| Версия | Симптом | Корень | Фикс |
| --- | --- | --- | --- |
| 0.2.2/0.2.3 | чужие/старые чаты в списке | при смене аккаунта/апгрейде локальная БД не чистилась — копились чаты прежних входов (прежняя SIM) | `_wipeOnAccountChange`: при `last_synced_account_id != myId` (включая первый запуск) `db.wipe()` |
| 0.2.4 | фикс списка чатов не срабатывал | гонка: LOGIN (op19) эмитит чаты в broadcast-стрим РАНЬШЕ подписки репозитория → события роняются | кешируем чаты LOGIN в `max_client._lastSyncedChats`, дотягиваем в `MessagesRepository.start()` |
| **0.2.5** | **сообщения не отправляются (op64 не уходит, ни ошибки, ни «часиков»); имена чатов «Чат N»** | **несовместимость БД**: и старый max iso, и master дошли до `version=7`, но с РАЗНЫМИ колонками (max iso: `messages.reactions/your_reaction`, БЕЗ `cid`; chats БЕЗ `peer_user_id/server_chat_id`. master — наоборот). Один номер версии → sqflite не мигрирует → запись master падает на «no such column» ВНЕ try → молча. Подтверждено дампом базы с устройства. | `version 7→8`, в `_onUpgrade` при `oldVersion<8` дроп всех таблиц + `_onCreate` (схема master). Данные тянутся с сервера заново. |
| 0.2.6 | все чаты названы «Maxim» (своё имя) | `storage.myUserId` ещё не записан при разборе диалога (профиль грузится после логина) → из participants «собеседником» выбирался сам пользователь | парсим `profile.contact.id` из LOGIN в `max_client.myProfileId`; `_ingestChatList` берёт `myId = storage ?? myProfileId`; имена резолвим op32 на каждом синке (само-исцеление старых) |
| 0.2.7 | дубль диалога (напр. «Ирина») | чат из контакта ключён по `peerUserId`, тот же из синка — по серверному `chatId` → две строки | `_ingestChatList`: если есть строка по peerUserId, сливаем синк в неё (`reassignMessages` + `deleteChat`), serverChatId проставлен — маршрут работает |
| 0.2.8 | (фича) смена своего имени | — | `max_client.updateProfileName` (payload из декомпила `r2e.java`: Tasks.Profile {requestId, firstName, lastName?}, опкод PROFILE 16); Настройки → «Изменить имя» |

### 4. Анти-бан — проверен на устройстве (по device-логу 0.2.5)
- **LOGIN (op19): 1 раз за сессию** — без шторма переавторизаций.
- **INIT (op6): 1** — без реконнект-шторма.
- **keepalive op16 (PROFILE) каждые ~25с** — держит сокет, reconnect не нужен.
- Поведение «одного живого клиента» — то, что не банится. Анти-бан НЕ ослаблялся
  при переезде (reconnect_policy форка на месте: throttle 1 LOGIN/30с, breaker
  6/5мин→8мин, стабильный deviceId).

## Что предстоит

1. **Переименовать собеседника** (кастомное имя контакта) — отдельная фича,
   опкод `CONTACT_UPDATE` (34), payload `{contactId: {firstName, lastName}}`
   (декомпил `aj4.java`). UI в профиле чата.
2. **Ошибка при добавлении нового чата** (вход в диалог с новым человеком) —
   баг, нужен device-лог попытки, чтобы увидеть точную ошибку (op46/маршрут/БД).
3. **Чат с большой историей открывается не на последнем сообщении, а
   посередине** — скролл-позиция: ListView не прыгает в низ (к последнему) после
   асинхронной догрузки истории. Фикс в `chat_screen.dart`.
4. Смержить `adopt-master` → `main` после подтверждения.
5. Выключить диагностику (`kDeviceDiagnostics=false`) и убрать DIAG-строки для
   чистого релиза.

## Ключевые уроки

- iOS release Flutter-логи в syslog не идут — нужен файл-лог + afc-pull.
- Самый коварный баг — несовместимость схемы БД под одним номером версии при
  слиянии двух веток. Лечится дроп+recreate с бампом версии.
- Гонка login/подписки на broadcast-стрим — кешировать и дотягивать.
- При разборе диалога свой id нужен СРАЗУ — берём из LOGIN-профиля, не из storage.

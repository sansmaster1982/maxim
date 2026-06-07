# Этап 11 — Порт анти-бана из рабочего форка maxim-messenger (2026-06-06)

Версия `0.1.3`. Источник истины — публичный форк пользователя
`github.com/sansmaster1982/maxim-messenger` (тот же Flutter), который НЕ банит
номер. Задача: перенести его анти-бан/протокольные правила в `max iso`, не
сломав наши фичи (reactions, snapshot/sync, sessions, push_event, control_event).

Порт — хирургический, не копирование: проекты разошлись. У нас есть то, чего нет
в форке (`reactions.dart`, `snapshot.dart`, `sync_repository.dart`,
`push_event.dart`, `session.dart`, `control_event.dart`), у форка —
`reconnect_policy.dart`, которого не было у нас.

## Метод

Склонировали форк, прогнали два воркфлоу: (1) извлечение правил из реального кода
форка с построением плана порта (6 агентов на аспект + 7 агентов-верификаторов
по правилам), (2) adversarial-review фактического диффа (3 агента). Плюс
`flutter analyze` + 78 юнит-тестов.

## 7 правил и что потребовалось

| # | Правило | Статус до | Что сделано |
| --- | --- | --- | --- |
| 1 | Не логиниться чаще 1 LOGIN/30с | НЕ было | `ReconnectPolicy.minAuthInterval=30с` + `_sinceLogin` (время с авторизации, не с разрыва) |
| 2 | Keepalive op16 PROFILE/25с | был op1 PING | заменён на **op16 PROFILE** (пустой payload), старт в `login()`, стоп в `_disconnect`+`_handleDrop`, `MaxOp.ping` удалён |
| 3 | backoff 5с + предохранитель >6/5мин→8мин | был backoff 5с/cap 60с, без предохранителя | `ReconnectPolicy` (cap 5мин, breaker 6/5мин→8мин) + `rearm()` после LOGIN |
| 4 | Стабильный deviceId | УЖЕ было (Этап 7) | без изменений (1:1 с форком: UUID в Keychain, переживает logout) |
| 5 | userAgent | УЖЕ совпадал | без изменений — см. ниже |
| 6 | Не слать пустой payload; перманентный отказ дропать | НЕ было | `MaxRejected`, guard пустого text, `cmd=3`-классификация, дроп из outbox |
| 7 | Не держать аккаунт одновременно в офиц. клиенте | УЖЕ покрыто | наши `sessionsInfo/Close` (op96/97) + SessionsScreen — сохранены |

## Главная поправка: правило 5 (IOS/APNS) — ложная премиса

ТЗ просило для iOS слать `deviceType=IOS`, `pushDeviceType=APNS`, реальные поля
iPhone. Проверка кода форка (grep `IOS|APNS|iosInfo`) показала: ничего этого там
НЕТ. Форк на iPhone логинится по SMS как **ANDROID**, `pushDeviceType=GCM`.
`appVersion 26.15.0` / `build 6689` — это версия Android-приложения MAX, валидного
iOS-userAgent из них не собрать; IOS-флоу сервера не реверснут. Менять на IOS =
регрессия и риск бана. Наш 0.1.2 уже совпадал с форком по протокольным полям и
маскируется лучше (согласованный пресет Samsung SM-A546E против заглушки
`deviceName="Android"`+iOS-экран у форка). Оставили как есть, добавили защитный
комментарий в `device_profile.dart`, чтобы будущий «порт» не переписал на IOS.

## Ключевые правки

- `lib/data/max/reconnect_policy.dart` — новый, дословная копия форка
  (`minAuthInterval`, `baseBackoff`, `authThrottle`, breaker, `nextDelay`).
- `lib/data/max/max_client.dart` — `_sinceLogin` + `sinceLastLogin`;
  `_ReconnectManager` переписан на `ReconnectPolicy` (start/cancel/rearm/
  _pruneWindow/_tryReconnect); keepalive op16 PROFILE; `login()` фиксирует
  момент авторизации, стартует keepalive, дёргает `rearm()`; `sendMessage` —
  guard пустого payload + `cmd=3`→`MaxRejected`.
- `lib/core/errors.dart` — `MaxRejected`. `models/message.dart` — статус
  `rejected`. `messages_repository.dart` — ветки `on MaxRejected` в
  `sendText`/`drainOutbox`/`sendMedia` (перманентный → дроп из outbox, не петля).
- `lib/core/constants.dart` — удалён `MaxOp.ping`.
- `test/reconnect_policy_test.dart` — 6 кейсов на политику (throttle, breaker,
  backoff cap).

## Почему это закрывает баны (поверх Этапа 10)

Этап 10 убрал idle-дроп (keepalive), но наш reconnect на каждый успех сбрасывал
паузу в базу и не имел пола частоты LOGIN — при патологии всё ещё мог штормить.
Теперь: LOGIN физически не чаще 1/30с, при флаппинге — пауза 8 мин, keepalive
держит сокет, невалидный payload не уходит в бесконечный повтор. Это поведение
рабочего форка, который не банит.

## Оговорки

- Уже забаненный номер клиентом не лечится. Проверять на свежем номере.
- «Считать только успешные re-auth» (буква правила 3): и форк, и мы считаем ВСЕ
  попытки в окне предохранителя — сознательное отклонение в безопасную сторону
  (тормозим раньше).
- Те же правки нужны другим клиентам (`max new maxim`, `max exe python`), если
  ими пользоваться, — здесь не делались.

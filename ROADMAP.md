# maxim — дорожная карта

`maxim` — полнофункциональный сторонний клиент мессенджера MAX на Flutter, целевая платформа iOS. Говорит с боевой сетью MAX (`api.oneme.ru:443`) по родному бинарному протоколу, поэтому трафик неотличим от официального клиента и не режется оператором.

Эта сборка (`max iso`) — чистая ветка проекта, поднятая из наработки `max new maxim` (проект `maxim_messenger`). История реверса и прежних этапов 0–7 лежит в [docs/PROGRESS.md](docs/PROGRESS.md) — она относится к прежнему репозиторию, хеши коммитов там не применимы к текущему git. Здесь ведётся свой журнал по этапам в `docs/STAGE_XX.md`.

Спецификация протокола: [docs/PROTOCOL.md](docs/PROTOCOL.md). Медиа-опкоды: [docs/MEDIA_OPCODES.md](docs/MEDIA_OPCODES.md).

## Принципы

- Совместимость с боевым протоколом важнее «своих» решений. Любое поле, которое шлёт официальный клиент, шлём так же (порядок полей userAgent, `cid`, `detectShare`, `notify`).
- Каждый этап заканчивается: `flutter analyze` чисто, `flutter test` зелёный, запись в `docs/STAGE_XX.md`, git-коммит.
- Стек на Windows-машине проверяется через `flutter analyze` + юнит-тесты + headless `bin/maxim_cli.dart`. GUI-прогон требует Developer Mode (Windows) или Mac (iOS) — это действие пользователя, не блокер для кода.

## Этапы

- [x] **Этап 1 — Бутстрап.** Перенос `maxim_messenger` в `max iso`, `pub get`, базовая верификация, git init. Детали: [docs/STAGE_01.md](docs/STAGE_01.md).
- [x] **Этап 2a — Ядро мессенджинга: чаты после входа.** Детали: [docs/STAGE_02.md](docs/STAGE_02.md).
  - Парсинг снэпшота LOGIN (op 19, `interactive=true`) → запись `chats`/`contacts`/профиля в локальную БД, наполнение главного экрана. Корневая причина пустого списка — `interactive:false` — устранена.
  - Полный payload `MSG_SEND` (64): `cid`, `detectShare`, `notify`, `randomId` как у официального клиента.
- [x] **Этап 2b — Надёжное наполнение списка чатов.** Детали: [docs/STAGE_02b.md](docs/STAGE_02b.md).
  - Кеш сырого тела LOGIN + байт-скан id чатов (`RawParsers.extractChatIds`, порт из maxclient) + добор названий/аватаров через CHAT_INFO (op 48). Двухуровневое наполнение в `SyncRepository`: богатые объекты из декода, плюс id из raw для случаев, когда compact-msgpack не декодируется.
- [x] **Этап 3 — Нативный iOS-слой поведения.** Детали: [docs/STAGE_03.md](docs/STAGE_03.md). Cupertino-переходы на всех платформах (edge-swipe-back) через `pageTransitionsTheme`, адаптивные контролы (`Switch.adaptive`, spinner). Палитра уже совпадает с реверс-цветами десктопа MAX. Пиксель-в-пиксель доводка под iOS-облик требует референс-скриншотов и Mac.
- [ ] **Этап 4 — Готовность iOS-сборки.** `ios/Runner` Info.plist (камера, фото, контакты, микрофон), bundle id, display name `MAX`, иконки, launch screen, заготовка APNs/push.
- [x] **Этап 5 — Расширенные функции и устойчивость.** Детали: [docs/STAGE_05.md](docs/STAGE_05.md).
  - [x] DNS-over-HTTPS fallback (1.1.1.1/8.8.8.8 по IP, SNI и проверка сертификата сохранены) — против DNS-блокировки оператором.
  - [x] Opcode-aware push: удаление (142) применяется к БД; read/reactions/transcription доставляются типизированным потоком.
  - [x] Системные события чата (`_type=CONTROL`) -> человекочитаемый текст.
  - [x] Активные сессии (op 96/97) + экран в настройках.
  - [x] Глобальный поиск по тексту сообщений (Unicode-aware) + секции в списке.
  - [x] Выбор темы оформления (система/светлая/тёмная) с персистом.
  - [ ] Обоснованно НЕ сделано: отправка реакций (опкод не реверснут), zstd-кадры (`cof=0xFF`; нет зрелого pure-Dart zstd, редки), точные схемы payload read/reactions/transcription-push (нужен живой pcap — эталонные клиенты их не парсят).
- [x] **Этап 6 — Залито на GitHub.** Приватный репозиторий: https://github.com/sansmaster1982/maxim (ветка `main`, синхронна с локальной). Подключение — `gh auth login` через браузерный device-flow. Шаги и проверка ядра по токену: [docs/GITHUB.md](docs/GITHUB.md).

## Открытые блокеры окружения

- `gh` не авторизован — push на GitHub потребует `gh auth login` или `GH_TOKEN`.
- GUI-сборка на этом Windows-ПК: либо Developer Mode (desktop), либо Mac+Xcode (iOS). На код не влияет.

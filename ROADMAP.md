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
- [ ] **Этап 5 — Расширенные функции и устойчивость.** Реакции (send), события групп/каналов (`_type=CONTROL`), поиск, доводка настроек, zstd-распаковка кадров (`cof=0xFF`), DNS-over-HTTPS fallback. Push-опкоды 130/142/155 и inbound typing — требуют живого pcap: эталонные клиенты (bridge.py, maxclient) их не парсят, угадывать поля нельзя.
- [ ] **Этап 6 — Заливка на GitHub.** `gh auth login` (действие пользователя), создание репозитория, push.

## Открытые блокеры окружения

- `gh` не авторизован — push на GitHub потребует `gh auth login` или `GH_TOKEN`.
- GUI-сборка на этом Windows-ПК: либо Developer Mode (desktop), либо Mac+Xcode (iOS). На код не влияет.

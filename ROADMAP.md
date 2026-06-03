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
- [ ] **Этап 2b — Push-события и устойчивость.**
  - Opcode-aware диспетчер push: 128 NOTIF_MESSAGE (есть), 130 NOTIF_MARK, 142 NOTIF_MSG_DELETE, 155 NOTIF_REACTIONS, 293 NOTIF_TRANSCRIPTION.
  - Inbound typing на экран чата.
  - DNS-over-HTTPS fallback (1.1.1.1 / 8.8.8.8 по IP с сохранением SNI) — устойчивость к DNS-блокировке.
- [ ] **Этап 3 — iOS-паритет интерфейса.** Cupertino-навигация (swipe-back, SafeArea, Dynamic Island), типографика SF Pro, доводка экранов под облик оригинального MAX.
- [ ] **Этап 4 — Готовность iOS-сборки.** `ios/Runner` Info.plist (камера, фото, контакты, микрофон), bundle id, display name `MAX`, иконки, launch screen, заготовка APNs/push.
- [ ] **Этап 5 — Расширенные функции.** Реакции (send), события групп/каналов (`_type=CONTROL`), поиск, доводка настроек, zstd-распаковка кадров (`cof=0xFF`).
- [ ] **Этап 6 — Заливка на GitHub.** `gh auth login` (действие пользователя), создание репозитория, push.

## Открытые блокеры окружения

- `gh` не авторизован — push на GitHub потребует `gh auth login` или `GH_TOKEN`.
- GUI-сборка на этом Windows-ПК: либо Developer Mode (desktop), либо Mac+Xcode (iOS). На код не влияет.

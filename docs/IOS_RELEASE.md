# Заливка maxim в App Store Connect / TestFlight (без Mac)

Схема как в `DarkMessage-iOS`: сборка/подпись/загрузка идут на macOS-раннере GitHub Actions (`.github/workflows/build-ios.yml`). Локальный Mac не нужен. Загрузка — `xcodebuild -exportArchive` с App Store Connect API key (altool не используем — он делает server-side валидацию и отвергал билд).

## Что нужно один раз в Apple Developer

1. **Apple Developer Program** (платный, $99/год) — обязателен для TestFlight/App Store. Team у тебя уже есть: `aleksandr bronnikov` (`TEAM_ID = L7NT62PCSB`).
2. **App ID** для maxim: developer.apple.com → Identifiers → новый App ID с Bundle ID `com.sansmaster.maxim` (значение из `env.BUNDLE_ID` в воркфлоу; `com.sansmaster.maxim` глобально занят — bundle id уникален во всём Apple). Поменяешь bundle — поменяй и `env.BUNDLE_ID`.
3. **Distribution provisioning profile** под этот App ID: Profiles → App Store → выбрать App ID `com.sansmaster.maxim` и distribution-сертификат → скачать `.mobileprovision`.
4. **App в App Store Connect**: My Apps → + → New App, Bundle ID `com.sansmaster.maxim`, имя (напр. «maxim»).

Сертификат (Apple Distribution) и App Store Connect API key — **те же, что для Dark Message**, заводить заново не нужно.

## Секреты GitHub (Settings → Secrets and variables → Actions → New repository secret)

8 секретов, имена совпадают с `DarkMessage-iOS`. 7 из 8 переиспользуются один-в-один:

| Секрет | Что | Источник |
| --- | --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution `.p12` в base64 | как в Dark Message |
| `P12_PASSWORD` | пароль от `.p12` | как в Dark Message |
| `KEYCHAIN_PASSWORD` | любой пароль для временного keychain раннера | как в Dark Message |
| `TEAM_ID` | `L7NT62PCSB` | как в Dark Message |
| `APP_STORE_CONNECT_API_KEY` | `.p8` ключ в base64 | как в Dark Message |
| `APP_STORE_CONNECT_KEY_ID` | Key ID ключа | как в Dark Message |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | как в Dark Message |
| `BUILD_PROVISION_PROFILE_BASE64` | **НОВЫЙ** — профиль под `com.sansmaster.maxim` в base64 | п.3 выше |

Base64 профиля/сертификата (на Windows PowerShell):
```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("maxim_AppStore.mobileprovision")) | Set-Clipboard
```
Получившуюся строку вставить в значение секрета `BUILD_PROVISION_PROFILE_BASE64`.

Секреты в репозиторий не коммитятся (только в защищённое хранилище Actions). `.gitignore` уже исключает `*.p12`, `*.mobileprovision`, `key.properties`.

## Запуск

GitHub → вкладка **Actions** → workflow «Build & Upload iOS (TestFlight)» → **Run workflow** (ветка `main`). На macOS-раннере: ставится Flutter, импортируются сертификат+профиль, `flutter build ios --no-codesign` → `xcodebuild archive` (manual signing) → `-exportArchive` с `destination: upload` грузит билд в App Store Connect. Номер билда = `date +%y%m%d%H%M` (всегда растёт).

После загрузки билд появляется в App Store Connect → TestFlight. **Internal Testing** доступен без ревью (тестировщики из твоей команды). Public-ссылка TestFlight работает только после прохождения External-ревью.

## Важная оговорка про App Store

Публичный App Store почти наверняка отклонит сторонний клиент чужого протокола (правила про неофициальные клиенты/имперсонацию). Реалистично — TestFlight Internal для себя/своих. Это ограничение Apple-ревью, не кода.

## Токен GitHub для пуша воркфлоу

Файлы в `.github/workflows/` пуш принимает только токеном со scope `workflow`. Если push воркфлоу отбился — один раз обновить scope: `gh auth refresh -s workflow` (браузерный device-flow), потом повторить push.

## Итог (2026-06-04/05)

Схема доведена до конца: билд `0.1.0 (2606042007)` собран на `macos-latest`, подписан новым Apple Distribution, залит в App Store Connect (run `26976490854`, 9m45s), прошёл processing и установлен на реальный iPhone через **Internal TestFlight**. Mac не использовался. Полная хроника подписи (7 прогонов, канонический фикс через `ios/Flutter/Release.xcconfig`) и нюансы Internal/External TestFlight — в `docs/STAGE_08.md`.

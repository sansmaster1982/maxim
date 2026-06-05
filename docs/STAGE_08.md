# Этап 8 — Деплой на iOS через TestFlight без Mac (2026-06-04/05)

Цель этапа простая на словах и злая на практике: поставить maxim на реальный
iPhone, не имея ни одного Mac. Схема перенесена из `DarkMessage-iOS` — сборка,
подпись и заливка целиком идут на macOS-раннере GitHub Actions, локально только
`git push`. Результат: билд `0.1.0 (2606042007)` собран, подписан
distribution-сертификатом, залит в App Store Connect, прошёл processing, роздан
через **Internal TestFlight** и установлен на телефон. Приложение запускается и
работает; известные баги вынесены в конец дока, чинятся отдельно.

## Инфраструктура

- Репозиторий: `github.com/sansmaster1982/maxim`.
- Воркфлоу: `.github/workflows/build-ios.yml`, запуск ручной (`workflow_dispatch`),
  раннер `macos-latest`, Flutter 3.29.2.
- Bundle ID: `com.sansmaster.maxim` (`com.maxim.ios` глобально занят — bundle id
  уникален во всём Apple, см. раздел про сертификат).
- Team: `aleksandr bronnikov`, `TEAM_ID = L7NT62PCSB`.
- Номер билда: `date +%y%m%d%H%M` — монотонно растёт, ручной инкремент не нужен.

Шаги воркфлоу: checkout → выбрать Xcode → поставить Flutter → `flutter pub get`
→ `pod install` → импорт сертификата+профиля во временный keychain →
`flutter build ios --no-codesign` → `xcodebuild archive` → `ExportOptions.plist`
→ `xcodebuild -exportArchive` с `destination: upload` (грузит в App Store
Connect через App Store Connect API key). `altool` не используем — он делает
server-side валидацию и заворачивал билд.

## Цепочка подписи — 7 прогонов до зелёного

Главная боль iOS-сборки без Mac — code signing. CocoaPods-фреймворки (поды) не
принимают provisioning profile, а Runner — обязан его иметь. Глобальные
signing-флаги в `xcodebuild` бьют по всем таргетам сразу, и из-за этого профиль
уезжает на поды, которые его не понимают. Прошли 7 прогонов; каждый отвалился на
своём шаге.

| # | Run ID | Где упал | Причина | Фикс |
| --- | --- | --- | --- | --- |
| 1 | 26972604136 | archive | `<Pod> does not support provisioning profiles` — глобальный `PROVISIONING_PROFILE_SPECIFIER` прилетел на все таргеты | архивировать без подписи (`CODE_SIGNING_ALLOWED=NO`) + подпись на экспорте |
| 2 | 26973097496 | export | `Error Downloading App Information` (exit 70) — в App Store Connect нет App-записи | создать App в App Store Connect |
| 3 | 26973824519 | export | то же (App ещё не создан) | (та же причина) |
| 4 | 26974949807 | export | `<framework>.framework does not support provisioning profiles` — ручной экспорт неподписанного архива тащит профиль на фреймворки | перейти на automatic (cloud) signing |
| 5 | 26975445379 | archive | automatic-подпись свалилась в development: `No profiles for 'com.sansmaster.maxim' (iOS App Development)`, у команды нет устройств | неподписанный архив + automatic на экспорте |
| 6 | 26975875454 | export | `Cloud signing permission error` / `No profiles found` — роль API-ключа (App Manager) не имеет права cloud-signing | ручная distribution-подпись, только для Runner |
| 7 | 26976490854 | — | **SUCCESS**, build in 9m45s, exit 0 | залит в App Store Connect |

## Канонический фикс (то, что сработало)

Суть: подпись задаётся **только таргету Runner** через xcconfig, а не глобально
через `xcodebuild`. Поды собираются со своими xcconfig'ами и профиль не получают.

1. `ios/Flutter/Release.xcconfig` — ручная distribution-подпись Runner:
   ```
   #include "Generated.xcconfig"
   CODE_SIGN_STYLE = Manual
   DEVELOPMENT_TEAM = L7NT62PCSB
   CODE_SIGN_IDENTITY = Apple Distribution
   CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution
   PROVISIONING_PROFILE_SPECIFIER = 42180dac-dd59-451d-a6cb-851123d31a09
   ```
2. `ios/Runner.xcodeproj/project.pbxproj` — bundle id всех конфигураций заменён
   на `com.sansmaster.maxim`.
3. `xcodebuild archive` запускается **без** глобальных signing-флагов — подпись
   приходит из xcconfig, поэтому поды не трогаются.
4. `ExportOptions.plist` — `signingStyle: manual`, `signingCertificate: Apple
   Distribution`, явный маппинг `provisioningProfiles[com.sansmaster.maxim] =
   <UUID>`, `method: app-store-connect`, `destination: upload`.
5. App Store Connect API key (`.p8`) используется **только** на шаге заливки
   (`-authenticationKeyPath/ID/IssuerID`), не для подписи.

## Сертификат и bundle id

- `com.maxim.ios` оказался глобально занят → ушли на `com.sansmaster.maxim`
  (namespace по нику владельца, гарантированно свободен).
- Рабочий distribution-`.p12` лежал на другом компьютере и был недоступен,
  поэтому выпущен **новый Apple Distribution** через CSR (OpenSSL): сгенерили
  приватный ключ + CSR, загрузили CSR в developer.apple.com, скачали `.cer`,
  собрали `.p12`. Под него выпущен App Store provisioning profile
  (UUID `42180dac-dd59-451d-a6cb-851123d31a09`).
- `.p12` хранится только локально, в репозиторий не попадает (`.gitignore`
  исключает `*.p12`/`*.mobileprovision`/`*.cer`/`*.p8`). Пароль `.p12` живёт
  только в секрете `P12_PASSWORD`, в док и в код не выписан.

8 секретов GitHub (Settings → Secrets → Actions), имена совпадают с
`DarkMessage-iOS`: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`,
`KEYCHAIN_PASSWORD`, `TEAM_ID`, `APP_STORE_CONNECT_API_KEY`,
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
`BUILD_PROVISION_PROFILE_BASE64` (последний — новый, под новый профиль).

Пуш файлов в `.github/workflows/` требует токена со scope `workflow`
(`gh auth refresh -s workflow`), иначе push воркфлоу отбивается.

## Заливка, processing, TestFlight

- Run 7 (`26976490854`) залил билд 4 июня 23:14. В App Store Connect → TestFlight
  → Build Uploads билд встал в статус **Processing** (обработка на стороне Apple,
  10–30 мин, для первого билда дольше). До конца обработки билд не выбирается ни в
  одной группе — это не ошибка.
- После обработки билд `0.1.0 (2606042007)` перешёл в статус **Testing** и стал
  виден в группе.
- **Internal vs External.** Раздавали через **Internal Testing** (группа `maxim`):
  без Beta App Review, доступно сразу после processing, тестеры — из команды.
  Публичная ссылка и форма «What to Test → Submit for Review» — это **External**,
  оно требует ревью Apple (24–48 ч). Публичная ссылка до прохождения ревью пишет
  «приложение не принимает бета-тестирование» — раздавать ещё нечего.
- Отдельный блокер External: вход в MAX идёт по номеру телефона + SMS-код,
  ревьюер Apple код из чужой SMS не получит и в приложение не войдёт. Поэтому
  внешнее ревью для такого клиента почти наверняка завернут. Для своих тестов это
  не нужно — Internal закрывает задачу.
- Установка на телефон: приложение **TestFlight** из App Store → войти **тем же
  Apple ID, что добавлен в Internal-группу как тестер** (TestFlight логинится
  отдельно от iCloud телефона) → билд MAX появляется сам, кнопка Install.
  Главная типовая засада — TestFlight на телефоне залогинен другим Apple ID, чем
  в списке Testers.

## Итог

maxim установлен и запускается на реальном iPhone. Полная цепочка без Mac
работает воспроизводимо: код → GitHub Actions → подпись → App Store Connect →
processing → Internal TestFlight → устройство.

Баги, найденные при прогоне на устройстве, и их статус — в Этапе 9
(`docs/PROGRESS.md`). Кратко: артефакт имени контакта `[{name:...}]`, цифровой
пад вместо букв в пароле 2FA, реалистичность профиля устройства — исправлены
в версии 0.1.1.

## Как выкатить следующую версию

1. Поднять `version:` в `pubspec.yaml` (напр. `0.1.1+1`).
2. `git push`.
3. GitHub → Actions → «Build & Upload iOS (TestFlight)» → Run workflow (ветка
   `main`). Сборка сама подпишет и зальёт.
4. После processing новый билд прилетит в TestFlight как обновление; внутреннему
   тестеру отдельное подтверждение не нужно.

## Важная оговорка про публичный App Store

Публичный App Store почти наверняка отклонит сторонний клиент чужого протокола
(правила про неофициальные клиенты и имперсонацию) — и упрётся в тот же
SMS-вход для ревьюера. Реалистичный потолок без отдельной обвязки — TestFlight
Internal для себя и своих. Это ограничение Apple-ревью, не кода.

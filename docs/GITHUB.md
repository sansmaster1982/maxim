# Заливка maxim на GitHub

Репозиторий готов к пушу: ветка `main`, дерево чистое, история по этапам. Осталось одно, что я не могу сделать за тебя — авторизоваться под твоим аккаунтом. На этой машине `gh` не залогинен, `GH_TOKEN` не задан.

Любой из трёх путей:

## Вариант 1 — gh CLI (проще всего)

```
gh auth login            # GitHub.com → HTTPS → войти через браузер
gh repo create maxim --private --source=. --remote=origin --push
```

`--private` можно заменить на `--public`. После этого код на `github.com/<логин>/maxim`.

## Вариант 2 — репозиторий уже создан в вебе

```
git remote add origin https://github.com/<логин>/maxim.git
git push -u origin main
```

## Вариант 3 — дать мне токен

Создай Personal Access Token (classic, scope `repo`), затем:

```
$env:GH_TOKEN = "ghp_..."
```

и напиши «запушь» — я создам репозиторий и залью сам.

## Проверка ядра без сборки (на этой Windows-машине)

iOS-сборка требует Mac, GUI на Windows — Developer Mode. Но протокол и
наполнение чатов проверяются headless, нужен лишь auth-token:

```
echo <твой_auth_token> > max_token.txt
dart run bin/maxim_cli.dart
```

После входа CLI печатает `Снэпшот логина: ... чатов(декод)=N ...` и по команде
`chats` — список чатов. Это прямая проверка Этапа 2 на боевом сервере.

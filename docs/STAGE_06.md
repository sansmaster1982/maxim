# Этап 6 — Реверс нативного APK: реакции, схемы push, zstd

Дата: 2026-06-04. Источники: декомпил нативного клиента `apk_check/max_full_decompiled/sources` (опкод-енам `defpackage/ewc.java`, билдеры `kgb`/`kfb`, парсеры `n7l`/`zu6`/`swb`/`kwb`/`mwb`/`xwb`, диспетчер сжатия `lp.java`/`e1d.java`) и публичные клиенты `nyakokitsu/MaxProtoExplanation`, `nsdkinx/vkmax`, `Grovvik/vkmax-nodejs`. Три ранее «заблокированных» пункта оказались разрешимы — поля взяты из первоисточника, не угаданы.

## Реакции (опкоды найдены в ewc.java)

- `MSG_REACTION = 178` — поставить: `{chatId:int64, messageId:int64, reaction:{reactionType:"EMOJI", id:"<эмодзи>"}}` (билдер `kgb.l()`; подтверждено vkmax и MaxProtoExplanation).
- `MSG_CANCEL_REACTION = 179` — снять: `{chatId, messageId}` (билдер `kfb.l()`).
- `MSG_GET_REACTIONS = 180`, `MSG_GET_DETAILED_REACTIONS = 181`.
- Объект реакции сервер->клиент: `reaction` приходит ГОЛОЙ строкой-эмодзи (декомпил `u7l.b`), не объектом. counters: `[{reaction:"👍", count:3}]`.

## Корректные схемы server-push (заменили угаданные)

| Опкод | Событие | Реальные поля (декомпил) |
| --- | --- | --- |
| 129 | NOTIF_TYPING | `chatId, userId, type` (type — enum вида TEXT/PHOTO/...; парсер `xwb`) |
| 130 | NOTIF_MARK | `chatId, userId, mark, unread` (`n7l`→`uvb`) — НЕ marker/time/messageId |
| 142 | NOTIF_MSG_DELETE | `chat{id}, messageIds[]` (long-массив), `ttl` (`zu6`→`gwb`) |
| 155 | NOTIF_MSG_REACTIONS_CHANGED | `chatId, messageId, totalCount, counters[]` (`kwb`) |
| 156 | NOTIF_MSG_YOU_REACTED | `chatId, messageId, reactionInfo{counters,totalCount,yourReaction}` (`mwb`) |
| 293 | NOTIF_TRANSCRIPTION | `chatId, messageId, mediaId, transcription, transcriptionStatus` (`swb`) |

## Исправление reply

Ответ в MAX — это `message.link = {type:"REPLY", messageId}` (vkmax + MaxProtoExplanation), а не отдельный `replyTo`. `sendMessage` приведён к этому виду.

## zstd-кадры (cof=0xFF) — разобрано, но binding отложен

`lp.java` для `cof==0xFF` зовёт `one.me.sdk.zsrd.ZstdUtil.nativeDecompress(byte[])` из бандленного `libzstd.so` — **один аргумент, без словаря**. Значит это стандартный zstd-кадр (магия `28 B5 2F FD`), который декодирует любой generic zstd без словаря. Тело передаётся как есть, магия не срезается. LZ4 (`cof>0`) — block-формат, размер распаковки `payloadLen*cof` (lz4-java).

Вывод: распаковка zstd возможна, но безопасного кросс-платформенного pure-Dart zstd нет, а FFI-нативка рискует iOS-сборкой. Поэтому в Round 3 — подключаемый декодер (hook), по умолчанию graceful-лог; интегрируется дроп-ином, когда появится платформенный zstd. Кадры zstd редки (основной трафик LZ4).

## Round 1 (сделано)

- Опкоды 129/156/178/179/180 в `MaxOp`.
- `reactions.dart`: `reactionSetPayload`/`reactionCancelPayload`/`parseReactionCounters` (чистые).
- `MaxClient.setReaction`/`cancelReaction`.
- `push_event.dart`: модель `MaxPushEvent` расширена реальными полями, `classifyPushEvent` переписан под выверенные схемы (129/130/142/155/156/293).
- Reply через `message.link`.
- Тесты: `reactions_test` (4), переписан `push_event_test` (9). Всего 66, analyze чисто.

## Round 2 (сделано)

- БД-схема v7: `messages.reactions` (JSON {emoji:count}) + `messages.your_reaction`. Миграция ALTER, поля `MaxMessage.reactions/yourReaction`.
- `MessagesRepository._onEvent`: 155 → `setMessageReactions(counts)`; 156 → `setMessageReactions(counts, yourReaction)`; 293 → `setAttachTranscriptionByFileId(mediaId, text)`; 142 → удаление по `messageIds`; 129 → поток `typingEvents`.
- Отправка: `react`/`cancelReact` (оптимистично помечают свою реакцию, точные счётчики приходят push'ом), `ChatHistoryController.react/cancelReact`, `typingProvider` (StreamProvider.family).
- UI: long-press → ряд эмодзи (👍❤️😂😮😢🔥) ставит/снимает; чипы реакций под пузырём (своя подсвечена, тап переключает); индикатор «печатает…» в AppBar (сброс через 5с).
- Тест: roundtrip реакций через in-memory БД (`database_search_test`). Всего 67, analyze чисто.

## Round 3 (план)

Подключаемый zstd-декодер (cof=0xFF).

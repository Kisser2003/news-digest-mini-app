# News Digest — Telegram Mini App

Telegram Mini App компаньон для бота @news_digest_bot.
Показывает историю AI-дайджестов, которые бот генерирует 2 раза в день.

---

## Бот (уже работает)

### Workflow 1: Telegram News Digest 2x/day
**ID:** `Oyw6fggNKFIErBRg`
**URL:** https://kisser.app.n8n.cloud/workflow/Oyw6fggNKFIErBRg

Расписание:
- 🌅 Утро: `0 5 * * *` UTC (08:00 МСК) — тип `morning`
- 🌙 Вечер: `0 17 * * *` UTC (20:00 МСК) — тип `evening`

Источники (RSS через прокси tg.i-c-a.su):
- `@Ateobreaking` — https://tg.i-c-a.su/rss/Ateobreaking
- `@vcnews` — https://tg.i-c-a.su/rss/vcnews
- `@easy_qa_ru` — https://tg.i-c-a.su/rss/easy_qa_ru
- `@media_apple` — https://tg.i-c-a.su/rss/media_apple

AI: Google Gemini 2.5 Flash
Получатель: chatId `810176982`

### Workflow 2: Telegram Bot Commands
**ID:** `DWvgqOTzbAFBKCWm`
**URL:** https://kisser.app.n8n.cloud/workflow/DWvgqOTzbAFBKCWm

Команды:
- `/now` — дайджест по запросу (тип `manual`)
- `/history` — последние 5 дайджестов
- `/sources` — статистика за 7 дней
- Любая другая команда → help

Разрешённые chatId: `810176982`, `505915947`

---

## База данных

**DataTable ID:** `bL4xDbh1n1RLAwLT` (n8n встроенная таблица)

Схема:
| Поле | Тип | Описание |
|------|-----|----------|
| `date` | string (ISO 8601) | Время создания дайджеста |
| `type` | string | `morning` / `evening` / `manual` |
| `text` | string | Текст дайджеста (plain text + emoji) |

Записи добавляются нодами:
- `Save Digest History` (morning)
- `Save Evening Digest History` (evening)
- `Save Now History` (manual /now)

---

## Mini App (в разработке)

**Файл:** `index.html` (single-file SPA)

### Реализовано
- Карточная лента с expand/collapse (тап раскрывает полный текст)
- Время выпуска: "Сегодня, 08:00", "Вчера, 20:00"
- 4 круглые аватарки каналов-источников
- Превью текста 2-3 строки с "..."
- Светлая и тёмная тема (Telegram native CSS vars)
- Без своего хедера — используется системная шапка Telegram
- Скелетоны при загрузке
- Pull-to-refresh
- Пустое состояние "Дайджестов пока нет"
- Sticky кнопка "Обновить" в стиле Telegram MainButton
- CSS mesh-gradient / chrome glow эффект (Variant B — явное свечение, особенно на тёмной теме)

### Нужно сделать
- [ ] Подключить реальный API для чтения из DataTable `bL4xDbh1n1RLAwLT`
- [ ] Webhook-эндпоинт в n8n для отдачи истории (GET /digest-history)
- [ ] Деплой Mini App (GitHub Pages / Cloudflare Pages / etc.)
- [ ] Привязать Mini App URL к боту через BotFather

---

## Архитектура API

Mini App должна получать данные через n8n webhook:

```
GET https://kisser.app.n8n.cloud/webhook/digest-history
→ [{ date, type, text }, ...]  (последние N записей, новые сверху)
```

Нужно создать отдельный workflow с Webhook trigger, который читает из
DataTable `bL4xDbh1n1RLAwLT` и возвращает JSON.

---

## Каналы-источники (для аватарок в UI)

| Канал | Slug для CSS/аватарки | Тематика |
|-------|----------------------|----------|
| @Ateobreaking | `ateo` | Новости/политика |
| @vcnews | `vc` | Технологии/бизнес |
| @easy_qa_ru | `qa` | QA/разработка |
| @media_apple | `apple` | Apple/гаджеты |

---

## Технические детали

- n8n instance: `kisser.app.n8n.cloud`
- Telegram Bot: @news_digest_bot
- RSS прокси: `tg.i-c-a.su` (конвертирует Telegram-каналы в RSS)
- Timezone бота: Europe/Moscow (UTC+3)

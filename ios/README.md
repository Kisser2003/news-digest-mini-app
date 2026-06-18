# News Digest — iOS (SwiftUI + Supabase)

Нативное iOS-приложение, отображающее AI-дайджесты, которые генерирует n8n.
Заменяет связку «Telegram-бот + Mini App». Транспорт данных — Supabase
(PostgREST для чтения + Realtime для живых обновлений).

```
n8n workflow ──POST /rest/v1/digests──▶ Supabase (Postgres)
                                              │
                                  PostgREST + Realtime
                                              │
                                     iOS app (SwiftUI)
```

---

## 1. Схема базы (Supabase / PostgreSQL)

Выполни в Supabase → SQL Editor:

```sql
-- Таблица дайджестов
create table public.digests (
  id            uuid        primary key default gen_random_uuid(),
  published_at  timestamptz not null,                 -- когда выпущен дайджест
  type          text        not null
                  check (type in ('morning','evening','manual')),
  content       text        not null,                 -- текст выжимки
  created_at    timestamptz not null default now()    -- когда вставлена запись
);

-- Индекс под сортировку ленты (новые сверху)
create index digests_published_at_idx
  on public.digests (published_at desc);

-- Включаем Realtime для таблицы
alter publication supabase_realtime add table public.digests;

-- RLS: публичное чтение через anon-ключ, запись только сервисным ключом
alter table public.digests enable row level security;

create policy "public read"
  on public.digests for select
  to anon
  using (true);
-- INSERT-политику не добавляем: n8n пишет service_role-ключом (обходит RLS).
```

> Поля специально названы `published_at` / `content`, а не `date` / `text`,
> чтобы не цеплять зарезервированные слова Postgres. В Swift они мапятся
> обратно через `CodingKeys` (см. `Models/Digest.swift`).

---

## 2. n8n → Supabase (push)

В воркфлоу-генераторах дайджеста (`Save Digest History` и аналоги) **замени**
ноду отправки в Telegram на **HTTP Request**:

| Параметр | Значение |
|----------|----------|
| Method | `POST` |
| URL | `https://<PROJECT_REF>.supabase.co/rest/v1/digests` |
| Authentication | None (ключи в заголовках) |

**Headers:**

```
apikey:        <SUPABASE_SERVICE_ROLE_KEY>
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
Content-Type:  application/json
Prefer:        return=minimal
```

**Body (JSON):**

```json
{
  "published_at": "={{ $now.toISO() }}",
  "type": "morning",
  "content": "={{ $json.text }}"
}
```

`service_role`-ключ обходит RLS — это серверный ключ, держи его только в n8n,
**никогда не клади в iOS-приложение** (там идёт `anon`-ключ).

Готов вписать эту HTTP-ноду прямо в твои n8n-воркфлоу через MCP — как только
будет создан Supabase-проект и появятся URL + service_role ключ.

### Разовая миграция существующих записей

Текущая история лежит в n8n DataTable `bL4xDbh1n1RLAwLT`. Чтобы перенести её
в Supabase, можно одноразово прогнать `GET /digest-history` → маппинг
(`date→published_at`, `text→content`) → bulk POST. Скажи — соберу воркфлоу.

---

## 3. iOS-приложение

### Зависимость
Единственная — официальный [supabase-swift](https://github.com/supabase/supabase-swift)
(REST + Realtime). Добавь через Xcode → File → Add Package Dependencies:

```
https://github.com/supabase/supabase-swift
```

Минимальная цель: **iOS 17** (используются `@Observable` и `.task`).

### Конфигурация
Открой `Config/SupabaseConfig.swift` и подставь:
- `supabaseURL` — `https://<PROJECT_REF>.supabase.co`
- `supabaseAnonKey` — **anon/public** ключ (не service_role!)

### Структура
```
NewsDigest/
├─ NewsDigestApp.swift          // @main, точка входа
├─ Config/
│   └─ SupabaseConfig.swift     // URL + anon-ключ + общий клиент
├─ Models/
│   └─ Digest.swift             // Codable-модель + title/excerpt
├─ Services/
│   ├─ DigestRepository.swift   // протокол (абстракция источника)
│   └─ SupabaseDigestRepository.swift // реализация: fetch + realtime
├─ ViewModels/
│   └─ FeedViewModel.swift      // @Observable, состояние ленты
├─ Views/
│   ├─ FeedView.swift           // лента (List + pull-to-refresh)
│   └─ DigestCardView.swift     // карточка: title/excerpt/share/expand
└─ Support/
    └─ DateFormatting.swift     // «Сегодня, 08:00» / «Вчера, 20:00»
```

Источник данных спрятан за протоколом `DigestRepository`, так что при желании
заменить Supabase на что-то ещё достаточно одной новой реализации — UI и
ViewModel не трогаются.

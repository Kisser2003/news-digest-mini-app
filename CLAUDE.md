# News Digest — нативное iOS-приложение

SwiftUI-приложение (iOS 17+), показывает **сырые посты** из 4 Telegram-каналов
в виде **живой ленты, сгруппированной по каналам** (картинки и видео).
Тап по посту → оригинал в Telegram. **Без AI-выжимки** (решение принято).
Выпуски утро/вечер убраны 20.06.2026 — теперь непрерывный live-поток.

> Проект вырос из Telegram-бота `@news_digest_bot` и Telegram Mini App.
> Та эпоха — легаси; актуально только нативное iOS-приложение.

---

## Структура

Xcode-проект в подпапке `NewsDigest/` (`NewsDigest.xcodeproj`).

```
NewsDigest/NewsDigest/
├── Config/SupabaseConfig.swift      // URL + anon-ключ + единый клиент `supabase`
├── Models/Post.swift                // Post, Edition, ChannelGroup, EditionType, ChannelRoute
├── Services/
│   ├── PostRepository.swift         // протокол источника постов
│   ├── SupabasePostRepository.swift // PostgREST-чтение + Realtime-инсерты
│   ├── ReadStore.swift              // прочитанное (бейджи/метки)
│   └── NotificationManager.swift    // локальные напоминания
├── ViewModels/FeedViewModel.swift   // @Observable; sections:[ChannelGroup], кеш
├── Views/
│   ├── FeedView.swift               // live-лента: секции по каналам
│   ├── ChannelScreen.swift          // все посты одного канала
│   ├── SettingsView.swift           // тема, акценты, напоминания, прочитанное
│   ├── PostCard.swift               // картинка/видео через CachedImage
│   ├── ImageViewer.swift            // зум картинок
│   └── VideoPlayerScreen.swift      // инлайн-плеер видео
└── Support/                          // Theme, ChannelInfo, Haptics, DateFormatting

NewsDigestWidget/                     // target NewsDigestWidgetExtension (medium)
├── NewsDigestWidget.swift           // bundle, widget, Provider, view
├── WidgetData.swift                 // модель + WidgetAPI (прямой URLSession в Supabase)
└── Info.plist                       // NSExtension widgetkit
```

### Сделано
Live-лента по каналам (до 6 постов в секции + «показать все»), экран канала,
поиск, фильтр каналов, непрочитанное (снимок «новых» на сессию), вибрация,
кеш+даунсэмплинг картинок, видео (постер + плеер), зум, локальные напоминания,
градиент-фон, настройки (тема + 7 акцентов), иконка.

### Бэклог
- [ ] Закладки
- [ ] Контекстное меню поста (long-press)
- [ ] Размер шрифта
- [ ] Удалить легаси-таблицу `digests` в Supabase (старый воркфлоу уже деактивирован)

---

## Бэкенд

### Supabase
- ref `puxvslevqvdbkezyfdjm`, URL `https://puxvslevqvdbkezyfdjm.supabase.co`
- publishable (anon) ключ — в `SupabaseConfig.swift`, безопасен для клиента (RLS public read)
- secret (`service_role`) ключ живёт **только в n8n**, в приложение не кладётся

**Таблица `posts`:**
| Поле | Тип | Описание |
|------|-----|----------|
| `channel` | string | слаг канала |
| `message_id` | int | id поста в Telegram |
| `text` | string | текст поста |
| `image_url` | string | картинка |
| `link` | string | ссылка на оригинал в Telegram |
| `published_at` | timestamptz | время публикации |
| `edition` | string | `morning`/`evening` — приложением НЕ используется, но `Post.edition` декодится non-optional, поэтому бэкенд обязан класть валидное значение (по часу МСК) |
| `edition_date` | date | `YYYY-MM-DD` |

Уникальный индекс `(channel, message_id)` → дедуп на стороне БД. Таблица
`digests` — легаси (AI-дайджесты), приложением не используется.

### n8n
- instance `kisser.app.n8n.cloud`
- **АКТИВНЫЙ:** `LzPottf3uOCMsvSH` «News Feed Live (posts every 30 min)» —
  cron `*/30 * * * *` → 4 RSS (`tg.i-c-a.su`) → merge → Code «Build Posts»
  (split-парсинг, фильтр 12ч, edition по МСК) → HTTP «Push Posts» с
  `on_conflict=channel,message_id` + `resolution=ignore-duplicates`.
- **ДЕАКТИВИРОВАН:** `Oyw6fggNKFIErBRg` (старый 2×/день Gemini AI-дайджест +
  Telegram) — выключен 20.06.2026 при переходе на live-ленту.
- секретный ключ зашит в HTTP-ноде

---

## Каналы-источники

| Канал | Слаг | Тематика |
|-------|------|----------|
| @Ateobreaking | `ateobreaking` | Новости/политика |
| @vcnews | `vcnews` | Технологии/бизнес |
| @easy_qa_ru | `easy_qa_ru` | QA/разработка |
| @media_apple | `media_apple` | Apple/гаджеты |

Порядок каналов в выпуске задаётся `FeedViewModel.channelOrder`.

---

## Сборка и грабли

**Стек:** SwiftUI, supabase-swift 2.48, Personal Team (бесплатно),
Bundle `com.kisser.newsdigest`.

**Ограничения бесплатного Apple-аккаунта:**
- подпись живёт 7 дней (раз в неделю переподписывать — ⌘R)
- серверные push нельзя (только локальные уведомления)
- App Groups нельзя → виджет должен ходить в Supabase напрямую

**Проверка сборки из CLI:**
```bash
cd NewsDigest && xcodebuild -project NewsDigest.xcodeproj \
  -scheme NewsDigest \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"
```

**Грабли:**
- Xcode держит старый буфер при внешних правках файлов → если изменения не видны:
  ⌘Q, переоткрыть проект, ⌘⇧K (clean), ⌘R.
- VPN ломает DNS симулятора (ошибка -1003) → выключить VPN / Device → Restart.

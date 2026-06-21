import SwiftUI

/// Экран настроек: напоминания, управление прочитанным, инфо о каналах.
struct SettingsView: View {
    let allPosts: [Post]

    @Environment(NotificationManager.self) private var notifications
    @Environment(ReadStore.self) private var readStore
    @Environment(ThemeStore.self) private var theme
    @Environment(ChannelStore.self) private var channelStore
    @Environment(\.dismiss) private var dismiss

    @State private var cacheBytes = 0
    @State private var isClearingCache = false
    @State private var newChannel = ""

    var body: some View {
        @Bindable var notifications = notifications
        @Bindable var theme = theme

        NavigationStack {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $theme.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Акцент")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            ForEach(AccentTheme.allCases) { option in
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if theme.accent == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay {
                                        Circle().stroke(.primary.opacity(theme.accent == option ? 0.35 : 0), lineWidth: 2)
                                    }
                                    .onTapGesture {
                                        Haptics.selection()
                                        theme.accent = option
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Напоминания") {
                    Toggle("Уведомления о выпусках", isOn: Binding(
                        get: { notifications.isEnabled },
                        set: { _ in
                            Haptics.selection()
                            Task { await notifications.toggle() }
                        }
                    ))
                    if notifications.isEnabled {
                        DatePicker("Утром", selection: $notifications.morningDate,
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Вечером", selection: $notifications.eveningDate,
                                   displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Toggle("Уведомлять о новых постах", isOn: Binding(
                        get: { notifications.newPostsEnabled },
                        set: { _ in
                            Haptics.selection()
                            Task { await notifications.toggleNewPosts() }
                        }
                    ))
                } header: {
                    Text("Новые посты")
                } footer: {
                    Text("Приложение проверяет ленту в фоне и присылает уведомление о новых постах. Момент проверки выбирает iOS (обычно раз в 15–60 минут) — мгновенной доставки на бесплатном аккаунте нет.")
                }

                Section("Лента") {
                    Button {
                        Haptics.success()
                        readStore.markSeen(allPosts)
                    } label: {
                        Label("Отметить всё прочитанным", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive) {
                        Haptics.impact(.medium)
                        readStore.reset()
                    } label: {
                        Label("Сбросить прочитанное", systemImage: "arrow.counterclockwise")
                    }
                }

                Section {
                    ForEach(channelStore.slugs, id: \.self) { channel in
                        let info = ChannelInfo.of(channel)
                        HStack(spacing: 10) {
                            Text(info.short)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(info.color, in: .circle)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(info.displayName)
                                Text("@\(channel)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let removing = offsets.map { channelStore.slugs[$0] }
                        Haptics.impact(.medium)
                        Task { for slug in removing { await channelStore.remove(slug) } }
                    }

                    HStack {
                        TextField("@канал или ссылка t.me/…", text: $newChannel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { addChannel() }
                        Button(action: addChannel) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                        }
                        .disabled(ChannelStore.normalize(newChannel) == nil)
                    }
                } header: {
                    Text("Каналы")
                } footer: {
                    Text("Добавляй по @имени или ссылке t.me. Новые посты появятся в течение ~30 минут — бэкенд подтянет канал. Свайп влево — удалить.")
                }

                Section {
                    LabeledContent("Размер кэша",
                                   value: ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file))
                    Button(role: .destructive) {
                        Haptics.impact(.medium)
                        Task {
                            isClearingCache = true
                            await CacheManager.clearAll()
                            cacheBytes = await CacheManager.totalSizeBytes()
                            isClearingCache = false
                        }
                    } label: {
                        HStack {
                            Label("Очистить кэш", systemImage: "trash")
                            if isClearingCache {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isClearingCache)
                } header: {
                    Text("Кэш")
                } footer: {
                    Text("Картинки, видео-превью и сохранённые посты. После очистки они загрузятся заново.")
                }

                Section {
                    LabeledContent("Версия", value: appVersion)
                } header: {
                    Text("О приложении")
                } footer: {
                    Text("Живая лента из Telegram-каналов, сгруппированная по каналам. Без AI-выжимки — оригинальные посты.")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .task { cacheBytes = await CacheManager.totalSizeBytes() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func addChannel() {
        guard ChannelStore.normalize(newChannel) != nil else { return }
        let raw = newChannel
        newChannel = ""
        Haptics.success()
        Task { await channelStore.add(raw) }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

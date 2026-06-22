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
    @State private var showAddChannel = false

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

                    Picker("Размер текста", selection: $theme.textSize) {
                        ForEach(TextSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
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

                    Button {
                        Haptics.selection()
                        showAddChannel = true
                    } label: {
                        Label("Добавить канал", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Каналы")
                } footer: {
                    Text("Добавляй по @имени или ссылке t.me с именем и цветом. Новые посты появятся в течение ~30 минут — бэкенд подтянет канал. Свайп влево — удалить.")
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
            .sheet(isPresented: $showAddChannel) {
                AddChannelSheet()
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Лист добавления канала: слаг + опциональное имя + выбор цвета, с превью.
private struct AddChannelSheet: View {
    @Environment(ChannelStore.self) private var channelStore
    @Environment(\.dismiss) private var dismiss

    @State private var slug = ""
    @State private var name = ""
    @State private var colorHex = AddChannelSheet.palette[0]

    static let palette = ["E0564F", "FF9F0A", "30B0C7", "1A9E8F",
                          "0A84FF", "5E5CE6", "BF5AF2", "FF375F", "8E8E93"]

    private var isValid: Bool { ChannelStore.normalize(slug) != nil }
    private var previewName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? (ChannelStore.normalize(slug) ?? "Канал") : n
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Канал") {
                    TextField("@имя или ссылка t.me/…", text: $slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Название (необязательно)", text: $name)
                }

                Section("Цвет") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 14) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle().stroke(.primary.opacity(hex == colorHex ? 0.3 : 0), lineWidth: 2)
                                }
                                .onTapGesture {
                                    Haptics.selection()
                                    colorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Превью") {
                    HStack(spacing: 10) {
                        Text(ChannelInfo.shortLabel(previewName))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: colorHex), in: .circle)
                        Text(previewName)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Новый канал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        Haptics.success()
                        let s = slug, n = name, c = colorHex
                        Task { await channelStore.add(s, title: n, color: c) }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

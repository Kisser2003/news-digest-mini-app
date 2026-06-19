import SwiftUI

/// Экран настроек: напоминания, управление прочитанным, инфо о каналах.
struct SettingsView: View {
    let allPosts: [Post]

    @Environment(NotificationManager.self) private var notifications
    @Environment(ReadStore.self) private var readStore
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismiss) private var dismiss

    private let channels = ["Ateobreaking", "vcnews", "easy_qa_ru", "media_apple"]

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

                Section("Каналы") {
                    ForEach(channels, id: \.self) { channel in
                        let info = ChannelInfo.of(channel)
                        HStack(spacing: 10) {
                            Text(info.short)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(info.color, in: .circle)
                            Text(info.displayName)
                            Spacer()
                            Text("@\(channel)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    LabeledContent("Версия", value: appVersion)
                } header: {
                    Text("О приложении")
                } footer: {
                    Text("Лента собирается из Telegram-каналов дважды в день. Без AI-выжимки — оригинальные посты.")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

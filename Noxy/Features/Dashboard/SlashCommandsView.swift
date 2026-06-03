import SwiftUI

struct SlashCommandsView: View {
    @Environment(\.services) private var services
    @State private var commands: [SlashCommand] = []
    @State private var isLoading = true
    @State private var selectedCommand: SlashCommand? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if commands.isEmpty {
                    EmptyStateView(
                        icon: "bolt.slash",
                        title: "コマンドがありません",
                        description: "スラッシュコマンドが登録されていません。"
                    )
                } else {
                    List {
                        ForEach($commands) { $command in
                            CommandRow(command: $command, onToggle: { id, enabled in
                                Task { try? await services.bot.toggleCommand(id: id, enabled: enabled) }
                            })
                            .onTapGesture { selectedCommand = command }
                        }
                    }
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("コマンド")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $selectedCommand) { command in
                CommandDetailView(command: command)
            }
        }
        .task {
            commands = (try? await services.bot.fetchCommands()) ?? []
            isLoading = false
        }
    }
}

private struct CommandRow: View {
    @Binding var command: SlashCommand
    let onToggle: (String, Bool) -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing8) {
                    Text("/" + command.name)
                        .font(.mono)
                        .foregroundStyle(Color.accentIndigo)
                    Badge(text: "\(command.usageCount)", color: .accentIndigo, style: .outlined)
                }
                Text(command.description)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { command.enabled },
                set: { newVal in
                    command.enabled = newVal
                    onToggle(command.id, newVal)
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, .spacing4)
    }
}

struct CommandDetailView: View {
    let command: SlashCommand
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("コマンド") {
                    LabeledContent("名前") {
                        Text("/" + command.name).font(.mono).foregroundStyle(Color.accentIndigo)
                    }
                    LabeledContent("説明") { Text(command.description) }
                }

                if !command.options.isEmpty {
                    Section("オプション") {
                        ForEach(command.options, id: \.self) { option in
                            Label(option, systemImage: "doc.text")
                        }
                    }
                }

                Section("使用状況") {
                    LabeledContent("合計使用回数") { Text("\(command.usageCount)") }
                    LabeledContent("ステータス") {
                        Text(command.enabled ? "有効" : "無効")
                            .foregroundStyle(command.enabled ? Color.accentGreen : Color.textTertiary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Label("コマンドを削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("/" + command.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SlashCommandsView()
        .environment(\.services, ServiceContainer.live())
}

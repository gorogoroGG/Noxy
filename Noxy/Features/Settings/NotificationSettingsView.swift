import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notif_master")   private var masterEnabled = true
    @AppStorage("notif_mentions") private var mentions = true
    @AppStorage("notif_tickets")  private var tickets = true
    @AppStorage("notif_replies")  private var replies = true
    @AppStorage("notif_joins")    private var joins = false
    @AppStorage("notif_botstatus") private var botStatus = true
    @AppStorage("notif_scheduled") private var scheduled = true
    @AppStorage("notif_quietStart") private var quietStart: Double = 22
    @AppStorage("notif_quietEnd")   private var quietEnd: Double = 8

    var body: some View {
        Form {
            Section {
                Toggle("通知を許可", isOn: $masterEnabled)
                    .tint(Color.accentIndigo)
                    .font(.titleMedium)
            }

            Section("カテゴリ") {
                NotifToggle("メンション", systemImage: "at", on: $mentions, master: masterEnabled)
                NotifToggle("新規チケット", systemImage: "ticket.fill", on: $tickets, master: masterEnabled)
                NotifToggle("チケット返信", systemImage: "bubble.left.and.bubble.right.fill", on: $replies, master: masterEnabled)
                NotifToggle("メンバー参加", systemImage: "person.badge.plus", on: $joins, master: masterEnabled)
                NotifToggle("Botステータス", systemImage: "bolt.fill", on: $botStatus, master: masterEnabled)
                NotifToggle("予約送信", systemImage: "calendar.badge.clock", on: $scheduled, master: masterEnabled)
            }
            .disabled(!masterEnabled)

            Section("おやすみモード") {
                HStack {
                    Text("開始")
                    Spacer()
                    Text("\(Int(quietStart)):00").foregroundStyle(Color.textSecondary)
                }
                Slider(value: $quietStart, in: 0...23, step: 1)
                    .tint(Color.accentIndigo)
                HStack {
                    Text("終了")
                    Spacer()
                    Text("\(Int(quietEnd)):00").foregroundStyle(Color.textSecondary)
                }
                Slider(value: $quietEnd, in: 0...23, step: 1)
                    .tint(Color.accentIndigo)
            }
            .disabled(!masterEnabled)
        }
        .navigationTitle("通知")
    }
}

private struct NotifToggle: View {
    let label: String
    let systemImage: String
    @Binding var isOn: Bool
    let master: Bool

    init(_ label: String, systemImage: String, on: Binding<Bool>, master: Bool) {
        self.label = label
        self.systemImage = systemImage
        self._isOn = on
        self.master = master
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(label, systemImage: systemImage)
        }
        .tint(Color.accentIndigo)
        .opacity(master ? 1 : 0.5)
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
        .preferredColorScheme(.dark)
}

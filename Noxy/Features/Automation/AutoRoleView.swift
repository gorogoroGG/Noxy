import SwiftUI

struct AutoRoleView: View {
    @State private var isEnabled = true
    @State private var selectedRoles: Set<String> = ["Member", "Verified"]
    @State private var requireVerification = false
    @State private var assignDelayMinutes = 0
    @State private var toast: ToastMessage? = nil

    private let availableRoles = [
        ("Member", "新規メンバーに自動付与"),
        ("Verified", "認証済みメンバー"),
        ("Newbie", "初心者"),
        ("Community", "コミュニティメンバー"),
        ("Notification", "通知受け取り"),
    ]

    var body: some View {
        List {
            Section {
                Toggle("自動ロールを有効にする", isOn: $isEnabled.animation())
                    .tint(Color.accentGreen)
            }

            if isEnabled {
                Section("付与するロール") {
                    ForEach(availableRoles, id: \.0) { role, desc in
                        HStack(spacing: .spacing12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(role)")
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)
                                Text(desc)
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { selectedRoles.contains(role) },
                                set: { isOn in
                                    if isOn { selectedRoles.insert(role) }
                                    else { selectedRoles.remove(role) }
                                }
                            ))
                            .tint(Color.accentGreen)
                            .labelsHidden()
                        }
                    }
                }

                Section("オプション") {
                    Toggle("認証が必要", isOn: $requireVerification)
                        .tint(Color.accentGreen)
                    if assignDelayMinutes > 0 || true {
                        Stepper("遅延付与: \(assignDelayMinutes) 分後", value: $assignDelayMinutes, in: 0...60)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: .spacing8) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.accentIndigo)
                            Text("\(selectedRoles.count) 個のロールが入室時に自動付与されます")
                                .font(.captionRegular)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, .spacing24)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("自動ロール")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    toast = ToastMessage(type: .success, message: "自動ロール設定を保存しました")
                }
                .fontWeight(.semibold)
            }
        }
        .toast($toast)
    }
}

#Preview {
    NavigationStack { AutoRoleView() }
        .preferredColorScheme(.dark)
}

import SwiftUI

struct SupabaseSettingsView: View {
    @AppStorage("supabase_url")       private var supabaseURL = ""
    @AppStorage("supabase_anon_key")  private var anonKey    = ""

    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                FormSection("Supabase", icon: "server.rack", footer: "Project Settings → API から取得") {
                    VStack(spacing: Theme.Spacing.sm) {
                        FormField.text(label: "Project URL", text: $supabaseURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        FormField(label: "anon key") {
                            SecureField("anon key", text: $anonKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .inputStyle(height: 44)
                        }
                    }
                }

                Card {
                    VStack(spacing: Theme.Spacing.sm) {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            HStack {
                                if isTesting {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Text(isTesting ? "接続中..." : "接続テスト")
                                    .font(Theme.Font.bodySmall)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isTesting || supabaseURL.isEmpty || anonKey.isEmpty)
                        .frame(maxWidth: .infinity)

                        if let result = testResult {
                            Text(result)
                                .font(Theme.Font.caption)
                                .foregroundStyle(result.hasPrefix("✅") ? Theme.Color.statusOK : Theme.Color.statusBad)
                        }
                    }
                }

                Card {
                    Button {
                        Task {
                            try? await SupabaseAuthService().logout()
                        }
                    } label: {
                        Text("ログアウト")
                            .font(Theme.Font.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Color.statusBad)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, 24)
        }
        .background(Theme.Color.bg)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        do {
            let embeds: [EmbedModel] = try await SupabaseClient().get("embeds", limit: 1)
            testResult = "✅ 接続成功（\(embeds.count) 件のテンプレート）"
        } catch {
            testResult = "❌ \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        SupabaseSettingsView()
    }
}

#Preview("Dark") {
    NavigationStack {
        SupabaseSettingsView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack {
        SupabaseSettingsView()
    }
    .preferredColorScheme(.light)
}

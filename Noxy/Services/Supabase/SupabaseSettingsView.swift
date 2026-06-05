import SwiftUI

struct SupabaseSettingsView: View {
    @AppStorage("supabase_url")       private var supabaseURL = ""
    @AppStorage("supabase_anon_key")  private var anonKey    = ""

    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                FormSection("Supabase", icon: "server.rack", footer: "Project Settings → API から取得") {
                    VStack(spacing: .spacing12) {
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
                    VStack(spacing: .spacing12) {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            HStack {
                                if isTesting {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Text(isTesting ? "接続中..." : "接続テスト")
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isTesting || supabaseURL.isEmpty || anonKey.isEmpty)
                        .frame(maxWidth: .infinity)

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                        }
                    }
                }

                Card {
                    Button("ログアウト", role: .destructive) {
                        Task {
                            try? await SupabaseAuthService().logout()
                        }
                    }
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.spacing16)
            .padding(.bottom, 24)
        }
        .background(Color.bgPrimary)
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

import SwiftUI

struct SupabaseSettingsView: View {
    @AppStorage("supabase_url")       private var supabaseURL = ""
    @AppStorage("supabase_anon_key")  private var anonKey    = ""

    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                TextField("Project URL", text: $supabaseURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("anon key", text: $anonKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Supabase")
            } footer: {
                Text("Project Settings → API から取得")
            }

            Section {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        }
                        Text(isTesting ? "接続中..." : "接続テスト")
                    }
                }
                .disabled(isTesting || supabaseURL.isEmpty || anonKey.isEmpty)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                }
            }

            Section {
                Button("ログアウト", role: .destructive) {
                    Task {
                        try? await SupabaseAuthService().logout()
                    }
                }
            } header: {
                Text("アカウント")
            }
        }
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

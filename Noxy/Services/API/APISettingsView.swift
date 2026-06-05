import SwiftUI

/// 設定画面の「API接続」セクションから呼ぶ
struct APISettingsView: View {
    @AppStorage("use_live_api")  private var useLiveAPI  = false
    @AppStorage("api_base_url")  private var baseURL     = "http://192.168.1.2:3000"
    @AppStorage("api_key")       private var apiKey      = ""

    @State private var testResult: String?
    @State private var isTesting  = false

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                FormSection("接続モード", icon: "network", footer: "オフにするとモックデータで動作します") {
                    FormField.toggle(
                        label: "実サーバーに接続",
                        isOn: $useLiveAPI
                    )
                }

                if useLiveAPI {
                    FormSection("サーバーURL", icon: "link") {
                        FormField.text(label: "URL", text: $baseURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    FormSection("API キー（任意）", icon: "key") {
                        FormField(label: "キー") {
                            SecureField("未設定の場合は空欄", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .inputStyle(height: 44)
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
                            .disabled(isTesting)
                            .frame(maxWidth: .infinity)

                            if let result = testResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                            }
                        }
                    }
                }
            }
            .padding(.spacing16)
            .padding(.bottom, 24)
        }
        .background(Color.bgPrimary)
        .navigationTitle("API 設定")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: baseURL) { _, _ in testResult = nil }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        // UserDefaultsに即時反映してからテスト
        UserDefaults.standard.set(baseURL, forKey: "api_base_url")
        UserDefaults.standard.set(apiKey, forKey: "api_key")

        do {
            let status: BotStatus = try await APIClient().get("/api/v1/bot/status")
            testResult = "✅ 接続成功 — Bot \(status.isOnline ? "オンライン" : "オフライン") / latency \(status.latency)ms"
        } catch {
            testResult = "❌ \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        APISettingsView()
    }
}

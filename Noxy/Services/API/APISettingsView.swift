import SwiftUI

/// 設定画面の「API接続」セクションから呼ぶ
struct APISettingsView: View {
    @AppStorage("use_live_api")  private var useLiveAPI  = false
    @AppStorage("api_base_url")  private var baseURL     = "http://192.168.1.2:3000"
    @AppStorage("api_key")       private var apiKey      = ""

    @State private var testResult: String?
    @State private var isTesting  = false

    var body: some View {
        Form {
            Section {
                Toggle("実サーバーに接続", isOn: $useLiveAPI)
                    .onChange(of: useLiveAPI) { _, _ in testResult = nil }
            } footer: {
                Text("オフにするとモックデータで動作します")
            }

            if useLiveAPI {
                Section("サーバーURL") {
                    TextField("http://100.64.x.x:3000", text: $baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("API キー（任意）") {
                    SecureField("未設定の場合は空欄", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                    }
                }
            }
        }
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

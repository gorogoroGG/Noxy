import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isLoggingIn = false
    @State private var errorMessage: String? = nil

    @AppStorage("supabase_url")       private var supabaseURL = ""
    @AppStorage("supabase_anon_key")  private var anonKey    = ""
    @State private var showConfig = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentIndigo.opacity(0.3), Color.clear],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width / 2 - 200, y: -80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentPink.opacity(0.2), Color.clear],
                            center: .center, startRadius: 0, endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 150, y: 60)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: .spacing16) {
                    RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentIndigo, Color.accentPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.accentIndigo.opacity(0.5), radius: 20, x: 0, y: 10)

                    Text("Noxy")
                        .font(.displayLarge)
                        .foregroundStyle(Color.textPrimary)

                    Text("Discordボットをどこからでも管理")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, .spacing32)
                }

                Spacer()

                VStack(spacing: .spacing12) {
                    // Supabase 設定（折りたたみ）
                    if showConfig {
                        VStack(spacing: .spacing12) {
                            TextField("Project URL (https://xxx.supabase.co)", text: $supabaseURL)
                                .font(.captionRegular)
                                .padding(.spacing10)
                                .background(Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            SecureField("anon key", text: $anonKey)
                                .font(.captionRegular)
                                .padding(.spacing10)
                                .background(Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Text("Supabase の Project Settings → API から取得")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, .spacing24)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        withAnimation { showConfig.toggle() }
                    } label: {
                        Text(showConfig ? "設定を閉じる" : "Supabase 設定")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Discord ログインボタン
                    Button {
                        Task { await performLogin() }
                    } label: {
                        HStack(spacing: .spacing12) {
                            if isLoggingIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            Text(isLoggingIn ? "ログイン中..." : "Discordでログイン")
                                .font(.titleMedium)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .disabled(isLoggingIn)
                    .buttonStyle(ScalePressButtonStyle())
                    .padding(.horizontal, .spacing24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.captionRegular)
                            .foregroundStyle(.red)
                            .padding(.horizontal, .spacing24)
                    }
                }
                .padding(.bottom, .spacing48)
            }
        }
    }

    private func performLogin() async {
        isLoggingIn = true
        errorMessage = nil
        do {
            try await authManager.login()
        } catch {
            // ユーザーがキャンセルした場合はエラー表示しない
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
                && nsError.code == 1 {
                errorMessage = nil
            } else {
                errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
            }
            isLoggingIn = false
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager(services: ServiceContainer.live()))
}

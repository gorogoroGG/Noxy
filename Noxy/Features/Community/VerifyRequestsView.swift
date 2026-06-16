import SwiftUI

struct VerifyRequestsView: View {
    let guildId: String
    let panelId: String?  // nil = 全パネルの申請を表示

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var requests: [VerifyRequest] = []
    @State private var isLoading = true
    @State private var processingId: String? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.top, 30)
                } else if requests.isEmpty {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "person.badge.clock.fill")
                            .font(.system(size: 36)).foregroundStyle(Theme.Color.textTertiary)
                        Text("承認待ちの申請はありません")
                            .font(Theme.Font.title3).foregroundStyle(Theme.Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVStack(spacing: .spacing12) {
                        ForEach(requests) { req in
                            RequestRow(
                                request: req,
                                isProcessing: processingId == req.id,
                                onApprove: { Task { await approve(req) } },
                                onDeny: { Task { await deny(req) } }
                            )
                            .padding(.horizontal, .spacing16)
                        }
                    }
                }

                Color.clear.frame(height: 40)
            }
            .padding(.top, .spacing12)
        }
        .background(Theme.Color.bg)
        .refreshable { await load() }
        .navigationTitle("承認待ち")
        .navigationBarTitleDisplayMode(.large)
        .toast($toast)
        .task { await load() }
    }

    private func load() async {
        if let cached: [VerifyRequest] = appState.guildData(.verifyRequests, guild: guildId) {
            requests = cached
            isLoading = false
        } else {
            isLoading = true
        }
        if let fetched = try? await services.verify.fetchRequests(guildId: guildId, status: .pending) {
            requests = fetched
            appState.setGuildData(fetched, .verifyRequests, guild: guildId)
        }
        isLoading = false
    }

    private func approve(_ req: VerifyRequest) async {
        processingId = req.id
        do {
            _ = try await services.verify.approveRequest(id: req.id)
            requests.removeAll { $0.id == req.id }
            toast = ToastMessage(type: .success, message: "承認しました")
        } catch {
            toast = ToastMessage(type: .error, message: "承認に失敗しました")
        }
        processingId = nil
    }

    private func deny(_ req: VerifyRequest) async {
        processingId = req.id
        do {
            _ = try await services.verify.denyRequest(id: req.id)
            requests.removeAll { $0.id == req.id }
            toast = ToastMessage(type: .success, message: "拒否しました")
        } catch {
            toast = ToastMessage(type: .error, message: "拒否に失敗しました")
        }
        processingId = nil
    }
}

// MARK: - RequestRow

private struct RequestRow: View {
    let request: VerifyRequest
    let isProcessing: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                // アバター
                ZStack {
                    Circle()
                        .fill(Theme.Color.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    if let avatarUrl = request.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16)).foregroundStyle(Theme.Color.accent)
                        }
                        .frame(width: 40, height: 40).clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16)).foregroundStyle(Theme.Color.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(request.username)")
                        .font(Theme.Font.body).fontWeight(.semibold).foregroundStyle(Theme.Color.textPrimary)
                    Text(request.createdAt.formatted(.relative(presentation: .named)))
                        .font(Theme.Font.caption2).foregroundStyle(Theme.Color.textTertiary)
                }
                Spacer()
            }
            .padding(.spacing12)

            Divider().padding(.horizontal, .spacing12)

            HStack(spacing: 0) {
                Button(action: onApprove) {
                    Group {
                        if isProcessing {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("承認", systemImage: "checkmark.circle.fill")
                                .font(Theme.Font.caption).fontWeight(.semibold)
                                .foregroundStyle(Theme.Color.statusOK)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain).disabled(isProcessing)

                Divider().frame(height: 20)

                Button(action: onDeny) {
                    Label("拒否", systemImage: "xmark.circle.fill")
                        .font(Theme.Font.caption).fontWeight(.semibold).foregroundStyle(Theme.Color.statusBad)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain).disabled(isProcessing)
            }
            .background(Theme.Color.surfaceRaised)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }
}

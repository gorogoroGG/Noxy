import SwiftUI

struct VerifyRequestsView: View {
    let guildId: String
    let panelId: String?  // nil = 全パネルの申請を表示

    @Environment(\.services) private var services
    @State private var requests: [VerifyRequest] = []
    @State private var isLoading = true
    @State private var processingId: String? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden).padding(.top, 30)
            } else if requests.isEmpty {
                VStack(spacing: .spacing12) {
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 36)).foregroundStyle(Color.textTertiary)
                    Text("承認待ちの申請はありません")
                        .font(.titleMedium).foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity).padding(.top, 60)
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
            } else {
                ForEach(requests) { req in
                    RequestRow(
                        request: req,
                        isProcessing: processingId == req.id,
                        onApprove: { Task { await approve(req) } },
                        onDeny: { Task { await deny(req) } }
                    )
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                }
            }

            Color.clear.frame(height: 40)
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .refreshable { await load() }
        .navigationTitle("承認待ち")
        .navigationBarTitleDisplayMode(.large)
        .toast($toast)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        requests = (try? await services.verify.fetchRequests(guildId: guildId, status: .pending)) ?? []
        isLoading = false
    }

    private func approve(_ req: VerifyRequest) async {
        processingId = req.id
        do {
            _ = try await services.verify.approveRequest(id: req.id)
            requests.removeAll { $0.id == req.id }
            toast = ToastMessage(type: .success, message: "✅ 承認しました")
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
                        .fill(Color.accentIndigo.opacity(0.15))
                        .frame(width: 40, height: 40)
                    if let avatarUrl = request.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16)).foregroundStyle(Color.accentIndigo)
                        }
                        .frame(width: 40, height: 40).clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16)).foregroundStyle(Color.accentIndigo)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(request.username)")
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text(request.createdAt.formatted(.relative(presentation: .named)))
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
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
                                .font(.captionRegular).fontWeight(.semibold)
                                .foregroundStyle(Color.accentGreen)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain).disabled(isProcessing)

                Divider().frame(height: 20)

                Button(action: onDeny) {
                    Label("拒否", systemImage: "xmark.circle.fill")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain).disabled(isProcessing)
            }
            .background(Color(.tertiarySystemGroupedBackground))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

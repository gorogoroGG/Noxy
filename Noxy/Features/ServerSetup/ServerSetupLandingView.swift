import SwiftUI

struct ServerSetupLandingView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: .spacing32) {
                        heroSection
                        startOptionCards
                        popularTemplatesTeaser
                        Spacer(minLength: .spacing48)
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing8)
                }
            }
            .navigationTitle("サーバーセットアップ")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SetupDestination.self) { dest in
                switch dest {
                case .templatePicker:
                    TemplatePickerView(path: $path)
                case .editor(let draft):
                    ServerSetupEditorView(vm: ServerSetupViewModel(draft: draft))
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo.opacity(0.2), Color.accentPurple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                HStack(spacing: .spacing20) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(Color.accentIndigo)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text("サーバーを\n自分好みに設計")
                            .font(.titleLarge)
                            .foregroundStyle(Color.textPrimary)
                        Text("カテゴリ・チャンネル・ロールをまとめて一括作成")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(.spacing20)
            }
        }
    }

    // MARK: - Start Options

    private var startOptionCards: some View {
        VStack(spacing: .spacing12) {
            Text("はじめ方を選ぶ")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                path.append(SetupDestination.templatePicker)
            } label: {
                StartOptionCard(
                    icon: "square.grid.2x2.fill",
                    iconColor: .accentIndigo,
                    title: "テンプレートから始める",
                    subtitle: "ゲーミング・開発チームなど用途別の完成構成を選ぶ",
                    badge: "おすすめ"
                )
            }
            .buttonStyle(.plain)

            Button {
                path.append(SetupDestination.editor(ServerSetupDraft()))
            } label: {
                StartOptionCard(
                    icon: "plus.square.dashed",
                    iconColor: .accentGreen,
                    title: "ゼロから作る",
                    subtitle: "カテゴリとチャンネルを自由に組み合わせる"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Popular Templates Teaser

    private var popularTemplatesTeaser: some View {
        VStack(spacing: .spacing12) {
            HStack {
                Text("人気のテンプレート")
                    .font(.titleMedium)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    path.append(SetupDestination.templatePicker)
                } label: {
                    Text("すべて見る")
                        .font(.bodySmall)
                        .foregroundStyle(Color.accentIndigo)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacing12) {
                    ForEach(ServerTemplate.all.prefix(4)) { template in
                        Button {
                            path.append(SetupDestination.editor(template.draft))
                        } label: {
                            MiniTemplateCard(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Navigation Destinations

enum SetupDestination: Hashable {
    case templatePicker
    case editor(ServerSetupDraft)

    static func == (lhs: SetupDestination, rhs: SetupDestination) -> Bool {
        switch (lhs, rhs) {
        case (.templatePicker, .templatePicker): true
        case (.editor(let a), .editor(let b)): a.id == b.id
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .templatePicker: hasher.combine("picker")
        case .editor(let d): hasher.combine(d.id)
        }
    }
}

// MARK: - StartOptionCard

private struct StartOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: .spacing16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: .spacing4) {
                HStack(spacing: .spacing8) {
                    Text(title)
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    if let badge {
                        Text(badge)
                            .font(.captionSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentIndigo)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

// MARK: - MiniTemplateCard

private struct MiniTemplateCard: View {
    let template: ServerTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            Image(systemName: template.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(template.iconColor)
                .frame(width: 44, height: 44)
                .background(template.iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(template.name)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)

            Text(formattedUsage)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.spacing12)
        .frame(width: 120)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var formattedUsage: String {
        template.usageCount >= 1000
            ? "\(template.usageCount / 1000)k 人が使用"
            : "\(template.usageCount) 人が使用"
    }
}

#Preview {
    ServerSetupLandingView()
        .preferredColorScheme(.dark)
}

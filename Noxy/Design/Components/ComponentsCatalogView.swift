import SwiftUI

struct ComponentsCatalogView: View {
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing24) {
                    // Buttons
                    SectionHeader(title: "Buttons")
                    VStack(spacing: .spacing8) {
                        PrimaryButton("Send", style: .filled, icon: "paperplane.fill") {}
                        PrimaryButton("Outlined", style: .outlined) {}
                        PrimaryButton("Ghost", style: .ghost) {}
                        PrimaryButton("Large", style: .filled, size: .large, icon: "bolt.fill") {}
                        PrimaryButton("Loading", style: .filled, isLoading: true) {}
                    }
                    .padding(.horizontal)

                    // Badges
                    SectionHeader(title: "Badges")
                    HStack(spacing: .spacing8) {
                        Badge(text: "BOT")
                        Badge(text: "NEW", color: .accentGreen)
                        Badge(text: "BETA", color: .accentOrange)
                        Badge(text: "PRO", color: .accentPink)
                        Badge(text: "ADMIN", color: .accentPurple, style: .outlined)
                    }
                    .padding(.horizontal)

                    // Avatars
                    SectionHeader(title: "Avatars")
                    HStack(spacing: .spacing16) {
                        Avatar(name: "Luna K", size: 32, status: .online)
                        Avatar(name: "田中太郎", size: 40, status: .idle, accentColor: .accentPink)
                        Avatar(name: "DevBot", size: 56, status: .dnd, accentColor: .accentPurple)
                    }
                    .padding(.horizontal)

                    // Server Icons
                    SectionHeader(title: "Server Icons")
                    HStack(spacing: .spacing12) {
                        ServerIconView(name: "Valorant JP", size: 40)
                        ServerIconView(name: "星宮ルナ", gradientColors: [.accentPink, .accentPurple], size: 40)
                        ServerIconView(name: "DevHub", gradientColors: [.accentGreen, .accentIndigo], size: 40)
                        ServerIconView(name: "Shop", gradientColors: [.accentOrange, .accentPink], size: 40)
                    }
                    .padding(.horizontal)

                    // Stat Cards
                    SectionHeader(title: "Stat Cards")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .spacing12) {
                        StatCard(label: "Members", value: "16,287", trend: 12, icon: "person.3.fill")
                        StatCard(label: "Messages", value: "4,521", trend: -3, icon: "bubble.left.fill", accentColor: .accentGreen)
                    }
                    .padding(.horizontal)

                    // Channels
                    SectionHeader(title: "Channels")
                    VStack(spacing: 2) {
                        ChannelRow(name: "general", isSelected: true)
                        ChannelRow(name: "announcements", type: .announcement)
                        ChannelRow(name: "voice-chat", type: .voice)
                        ChannelRow(name: "staff-only", isLocked: true)
                    }
                    .padding(.horizontal)
                    .background(Color.bgSurface)

                    // Embed Preview
                    SectionHeader(title: "Embed Preview")
                    EmbedPreviewCard(embed: EmbedData(
                        color: .accentPurple,
                        title: "Welcome to the Server!",
                        description: "We're glad you're here. Please read the rules.",
                        fields: [
                            EmbedField(name: "Rules", value: "#rules", inline: true),
                            EmbedField(name: "Support", value: "#help", inline: true)
                        ],
                        footerText: "BotForge"
                    ))
                    .padding(.horizontal)

                    // Empty State
                    SectionHeader(title: "Empty State")
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: "No embeds yet",
                        description: "Create your first embed to get started.",
                        actionTitle: "Create Embed"
                    ) {}

                    // Toast trigger
                    SectionHeader(title: "Toast")
                    HStack(spacing: .spacing8) {
                        ForEach([(ToastType.success, "Success"), (.warning, "Warning"), (.error, "Error"), (.info, "Info")], id: \.1) { type, label in
                            Button(label) {
                                toast = ToastMessage(type: type, message: "\(label) message!")
                            }
                            .font(.captionRegular)
                            .padding(.horizontal, .spacing8)
                            .padding(.vertical, .spacing4)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                            .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Components")
            .navigationBarTitleDisplayMode(.large)
        }
        .toast($toast)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ComponentsCatalogView()
}

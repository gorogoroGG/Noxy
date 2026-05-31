import SwiftUI

struct GiveawaysView: View {
    @State private var giveaways: [Giveaway] = [
        Giveaway(id: "1", prize: "Nitro Classic 1ヶ月", winnerCount: 1, participants: 142, endsAt: Date().addingTimeInterval(172800), isActive: true),
        Giveaway(id: "2", prize: "オリジナルスタンプセット", winnerCount: 5, participants: 89, endsAt: Date().addingTimeInterval(86400), isActive: true),
        Giveaway(id: "3", prize: "カスタムロール", winnerCount: 3, participants: 256, endsAt: Date().addingTimeInterval(-3600), isActive: false, winners: ["GoroGoro", "ShadowX", "TaroYamada"]),
    ]
    @State private var showCreateSheet = false
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(giveaways) { giveaway in
                    GiveawayCard(giveaway: giveaway)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ギブアウェイ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateGiveawaySheet { newGiveaway in
                    giveaways.insert(newGiveaway, at: 0)
                    toast = ToastMessage(type: .success, message: "ギブアウェイを開始しました")
                }
            }
        }
        .toast($toast)
    }
}

// MARK: - Giveaway Card

private struct GiveawayCard: View {
    let giveaway: Giveaway

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(spacing: .spacing8) {
                Image(systemName: "gift.fill")
                    .font(.titleMedium)
                    .foregroundStyle(Color.accentPink)
                Text(giveaway.prize)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Badge(
                    text: giveaway.isActive ? "進行中" : "終了",
                    color: giveaway.isActive ? .accentGreen : .textTertiary,
                    style: .outlined
                )
            }

            HStack(spacing: .spacing16) {
                Label("\(giveaway.participants) 参加者", systemImage: "person.3.fill")
                Label("当選者 \(giveaway.winnerCount) 名", systemImage: "trophy.fill")
            }
            .font(.captionRegular)
            .foregroundStyle(Color.textSecondary)

            if giveaway.isActive {
                HStack(spacing: .spacing8) {
                    Image(systemName: "clock.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentOrange)
                    Text("残り \(giveaway.endsAt.formatted(.relative(presentation: .named)))")
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentOrange)
                }
            } else if !giveaway.winners.isEmpty {
                Text("当選者: \(giveaway.winners.joined(separator: ", "))")
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentGreen)
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

// MARK: - Create Sheet

private struct CreateGiveawaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (Giveaway) -> Void

    @State private var prize = ""
    @State private var winnerCount = 1
    @State private var durationHours = 24
    @State private var requireRole = ""

    var body: some View {
        NavigationStack {
            List {
                Section("景品") {
                    TextField("景品名を入力...", text: $prize)
                }

                Section("設定") {
                    Stepper("当選者 \(winnerCount) 名", value: $winnerCount, in: 1...20)
                    Stepper("期間 \(durationHours) 時間", value: $durationHours, in: 1...168)
                    TextField("参加に必要なロール（任意）", text: $requireRole)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ギブアウェイを開始")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("開始") {
                        let giveaway = Giveaway(
                            id: UUID().uuidString,
                            prize: prize,
                            winnerCount: winnerCount,
                            participants: 0,
                            endsAt: Date().addingTimeInterval(TimeInterval(durationHours * 3600)),
                            isActive: true,
                            winners: []
                        )
                        onCreate(giveaway)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(prize.isEmpty)
                }
            }
        }
    }
}

// MARK: - Models

struct Giveaway: Identifiable {
    let id: String
    var prize: String
    var winnerCount: Int
    var participants: Int
    var endsAt: Date
    var isActive: Bool
    var winners: [String] = []
}

#Preview {
    NavigationStack { GiveawaysView() }
        .preferredColorScheme(.dark)
}

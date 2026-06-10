import SwiftUI
import Charts

struct AnalyticsView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var stats: AnalyticsStats? = nil
    @State private var isLoading = true
    @State private var selectedPeriod = "7d"

    private let periods = ["7d", "30d", "90d"]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if let stats {
                VStack(spacing: .spacing24) {
                    periodPicker
                    statsGrid(stats)
                    memberGrowthChart(stats)
                    messageChart(stats)
                }
                .padding(.vertical)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("アナリティクス")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .onChange(of: selectedPeriod) { Task { await load() } }
    }

    // MARK: Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(periods, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: Stats Grid

    private func statsGrid(_ stats: AnalyticsStats) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: .spacing12), GridItem(.flexible(), spacing: .spacing12)],
            spacing: .spacing12
        ) {
            StatCard(label: "Members", value: stats.totalMembers.formatted(),
                     trend: stats.memberGrowthPercent, icon: "person.3.fill")
            StatCard(label: "Messages", value: stats.messagesToday.formatted(),
                     trend: stats.messageGrowthPercent, icon: "bubble.left.fill", accentColor: .accentGreen)
            StatCard(label: "Voice Minutes", value: stats.voiceMinutes.formatted(),
                     icon: "speaker.wave.2.fill", accentColor: .accentPurple)
            StatCard(label: "Commands Used", value: stats.commandsUsed.formatted(),
                     trend: stats.commandGrowthPercent, icon: "bolt.fill", accentColor: .accentOrange)
        }
        .padding(.horizontal)
    }

    // MARK: Member Growth Chart

    private func memberGrowthChart(_ stats: AnalyticsStats) -> some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionHeader(title: "Member Growth")

            Chart {
                ForEach(Array(stats.memberHistory.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Members", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentIndigo.opacity(0.5), Color.accentIndigo.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", index),
                        y: .value("Members", value)
                    )
                    .foregroundStyle(Color.accentIndigo)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v.formatted(.number.notation(.compactName)))
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Message Chart

    private func messageChart(_ stats: AnalyticsStats) -> some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionHeader(title: "Messages")

            Chart {
                ForEach(Array(stats.messageHistory.enumerated()), id: \.offset) { index, value in
                    BarMark(
                        x: .value("Day", index),
                        y: .value("Messages", value)
                    )
                    .foregroundStyle(Color.accentGreen.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            .frame(height: 120)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v.formatted(.number.notation(.compactName)))
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .padding(.horizontal)
        }
    }

    private func load() async {
        stats = try? await services.analytics.fetchStats(guildId: guildId)
        isLoading = false
    }
}

#Preview {
    AnalyticsView(guildId: "g001")
        .environment(\.services, ServiceContainer.live())
}

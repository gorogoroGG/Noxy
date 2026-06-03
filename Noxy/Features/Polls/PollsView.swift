import SwiftUI

struct PollsView: View {
    @State private var polls: [Poll] = [
        Poll(id: "1", question: "今週のイベントは何がいい？", options: [
            PollOption(text: "カスタムマッチ", votes: 12),
            PollOption(text: "ランク募集", votes: 8),
            PollOption(text: "ミニゲーム", votes: 5),
            PollOption(text: "お休み", votes: 2),
        ], totalVotes: 27, endsAt: Date().addingTimeInterval(86400), isActive: true),
        Poll(id: "2", question: "新しいロールカラーどれが好き？", options: [
            PollOption(text: "青", votes: 15),
            PollOption(text: "赤", votes: 10),
            PollOption(text: "緑", votes: 20),
        ], totalVotes: 45, endsAt: Date().addingTimeInterval(-3600), isActive: false),
    ]
    @State private var showCreateSheet = false
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(polls) { poll in
                    PollCard(poll: poll)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("投票")
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
                CreatePollSheet { newPoll in
                    polls.insert(newPoll, at: 0)
                    toast = ToastMessage(type: .success, message: "投票を作成しました")
                }
            }
        }
        .toast($toast)
    }
}

// MARK: - Poll Card

private struct PollCard: View {
    let poll: Poll

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(spacing: .spacing8) {
                Text(poll.question)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Badge(
                    text: poll.isActive ? "進行中" : "終了",
                    color: poll.isActive ? .accentGreen : .textTertiary,
                    style: .outlined
                )
            }

            VStack(spacing: .spacing8) {
                ForEach(poll.options) { option in
                    PollBar(option: option, total: poll.totalVotes)
                }
            }

            HStack {
                Label("\(poll.totalVotes) 票", systemImage: "person.3.fill")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if poll.isActive {
                    Text("残り \(poll.endsAt.formatted(.relative(presentation: .named)))")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Text("終了")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

private struct PollBar: View {
    let option: PollOption
    let total: Int

    private var percentage: Double {
        total == 0 ? 0 : Double(option.votes) / Double(total)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.bgElevated)
                    .frame(height: 32)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentIndigo.opacity(0.2))
                    .frame(width: geo.size.width * CGFloat(percentage), height: 32)

                HStack {
                    Text(option.text)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.leading, .spacing12)
                    Spacer()
                    Text("\(Int(percentage * 100))% (\(option.votes))")
                        .font(.captionRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentIndigo)
                        .padding(.trailing, .spacing12)
                }
            }
        }
        .frame(height: 32)
    }
}

// MARK: - Create Sheet

private struct CreatePollSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (Poll) -> Void

    @State private var question = ""
    @State private var options = ["", ""]
    @State private var durationHours = 24

    var body: some View {
        NavigationStack {
            List {
                Section("質問") {
                    TextField("投票の質問を入力...", text: $question, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("選択肢") {
                    ForEach(options.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.captionRegular)
                                .foregroundStyle(Color.textTertiary)
                            TextField("選択肢 \(index + 1)", text: $options[index])
                        }
                    }
                    .onDelete { indexSet in
                        options.remove(atOffsets: indexSet)
                    }

                    if options.count < 10 {
                        Button {
                            options.append("")
                        } label: {
                            Label("選択肢を追加", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.accentGreen)
                        }
                    }
                }

                Section("期間") {
                    Stepper("\(durationHours) 時間", value: $durationHours, in: 1...168)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("投票を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        let poll = Poll(
                            id: UUID().uuidString,
                            question: question,
                            options: options.filter { !$0.isEmpty }.map { PollOption(text: $0, votes: 0) },
                            totalVotes: 0,
                            endsAt: Date().addingTimeInterval(TimeInterval(durationHours * 3600)),
                            isActive: true
                        )
                        onCreate(poll)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(question.isEmpty || options.filter { !$0.isEmpty }.count < 2)
                }
            }
        }
    }
}

// MARK: - Models

struct Poll: Identifiable {
    let id: String
    var question: String
    var options: [PollOption]
    var totalVotes: Int
    var endsAt: Date
    var isActive: Bool
}

struct PollOption: Identifiable {
    let id = UUID()
    var text: String
    var votes: Int
}

#Preview {
    NavigationStack { PollsView() }
}

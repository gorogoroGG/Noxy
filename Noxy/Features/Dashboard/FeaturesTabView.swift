import SwiftUI

struct FeaturesTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                contentSection
                communitySection
                automationSection
                moderationSection
                toolsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("機能")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var contentSection: some View {
        Section("コンテンツ") {
            NavigationLink {
                EmbedListView()
            } label: {
                FeatureRow(icon: "rectangle.stack.fill", title: "埋め込みメッセージ", subtitle: "Embedテンプレートの作成・送信")
            }
        }
    }

    private var communitySection: some View {
        Section("コミュニティ") {
            NavigationLink {
                MembersListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(icon: "person.3.fill", title: "メンバー", subtitle: "メンバー一覧と管理")
            }

            NavigationLink {
                if appState.isPro {
                    VerifyPanelListView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "checkmark.shield.fill",
                        featureTitle: "認証パネル",
                        description: "参加したばかりのメンバーにCAPTCHA認証を課すことで、BOTや荒らしを自動でブロック。安全なコミュニティを維持します。",
                        flowSteps: [
                            .init("👤", "新メンバーがサーバーに参加"),
                            .init("✅", "認証チャンネルでCAPTCHAをクリア",
                                  "人間であることを確認するだけのシンプルな手順"),
                            .init("🏷", "ロールが自動付与、チャンネルが一斉解禁",
                                  "認証完了と同時に指定ロールが付与され、全チャンネルにアクセスできるようになる"),
                        ],
                        useCases: [
                            .init("🛡", "BOT・荒らしを入口でシャットアウト",
                                  "自動化されたBOTや大量アカウントによる荒らしは認証を突破できません。コミュニティの質を長期的に保てます。"),
                            .init("🔐", "「見るだけ可」→「認証済み専用」の2段階設計",
                                  "認証前は案内チャンネルのみ表示し、認証後に全チャンネルを解禁するアクセス制御を簡単に実装できます。"),
                            .init("📊", "本当にアクティブなメンバー数を把握",
                                  "参加だけして放置している幽霊アカウントと、実際に認証を完了したアクティブメンバーを区別して管理できます。"),
                        ],
                        advancedTips: [
                            "認証前専用チャンネルにサーバーの魅力や規約を記載しておくと、認証率と初回エンゲージメントが向上します",
                            "定期的に幽霊アカウントをキックして再認証を求めることで、常にアクティブなメンバーだけが残る健全な環境を維持できます",
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "認証",
                    subtitle: "CAPTCHA認証でロールを自動付与",
                    accentColor: Theme.Color.statusOK
                )
            }

            NavigationLink {
                if appState.isPro {
                    TicketsCoordinatorView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "ticket.fill",
                        featureTitle: "チケット",
                        description: "メンバーがボタン1つでサポートチケットを作成。専用チャンネルで1対1の対応ができ、問い合わせを見落としません。",
                        flowSteps: [
                            .init("🎫", "メンバーがパネルのボタンをクリック"),
                            .init("📬", "専用チャンネルが自動で作成される",
                                  "スタッフのみ参加できるプライベートチャンネルが即座に開く"),
                            .init("💬", "スタッフと1対1でやり取り"),
                            .init("✅", "解決後にクローズ・会話ログを保存"),
                        ],
                        useCases: [
                            .init("🎨", "コミッション・制作依頼の受付",
                                  "イラスト・動画・音楽などの依頼をチケット経由で受け付け。要件ヒアリングから納品確認まで1つのチャンネルで完結します。"),
                            .init("📦", "購入・取引後のサポート窓口",
                                  "ショップや自販機と組み合わせて購入後の問い合わせ窓口として活用。トラブル時もチャットログが証拠になります。"),
                            .init("❓", "規約違反の報告・運営への相談",
                                  "メンバーからの報告や相談を整理された形で受け付け。証拠を残しながら丁寧に対応できます。"),
                        ],
                        advancedTips: [
                            "「購入」「質問」「報告」のようにカテゴリ別の複数パネルを設置することで、担当スタッフへの自動振り分けが可能になります",
                            "トランスクリプト保存をONにしておくと過去のやり取りを参照でき、リピーター対応やFAQ整備に活用できます",
                        ]
                    )
                }
            } label: {
                FeatureRow(icon: "ticket.fill", title: "チケット", subtitle: "サポートチケットの管理")
            }

            NavigationLink {
                if appState.isPro {
                    TempVCListView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "waveform.and.mic",
                        featureTitle: "一時チャンネル",
                        description: "参加すると自動でVCが作成され、全員が退出すると自動削除。チャンネルを増やさずに、いつでも自由に通話できます。",
                        flowSteps: [
                            .init("🔊", "作成用の「ロビーVC」に参加"),
                            .init("✨", "自分専用のVCが自動で作られる",
                                  "チャンネル名や人数制限はメンバー自身が変更可能"),
                            .init("👥", "仲間を招待して通話開始"),
                            .init("🗑", "全員が退出したらチャンネルが自動削除",
                                  "使い終わった部屋が残らず、サーバーが常にすっきり"),
                        ],
                        useCases: [
                            .init("🎮", "ゲームセッション用の即席VC",
                                  "「今から人狼5人」「Apex組む人」など、その場の雰囲気で気軽にVCを立ち上げられます。終わったら自動削除で跡形もなし。"),
                            .init("📚", "作業・勉強通話の部屋",
                                  "好きなタイミングで作業部屋を作り、集中したい仲間を招いて作業通話。使い終わったら自動で消えます。"),
                            .init("🎙", "小規模イベント・打ち合わせ",
                                  "スタッフ間の打ち合わせや、メンバー限定の小規模イベントVCを素早く用意できます。常設チャンネルを増やさずに済みます。"),
                        ],
                        advancedTips: [
                            "チャンネル名を「作業中 🔴」「歓迎！🟢」などメンバー自身がカスタマイズできるため、入りやすい雰囲気を作れます",
                            "人数制限を2〜3人に設定することで、少人数限定のプライベート通話部屋として運用できます",
                        ]
                    )
                }
            } label: {
                FeatureRow(icon: "waveform.and.mic", title: "一時チャンネル", subtitle: "参加すると自動でVCを作成")
            }

            NavigationLink {
                if appState.isPro {
                    InviteTrackerView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "person.badge.plus",
                        featureTitle: "招待トラッカー",
                        description: "誰が誰を招待したかを追跡し、招待数ランキングや招待の樹形図を可視化。コミュニティを成長させた貢献者を把握し、施策を打てます。",
                        flowSteps: [
                            .init("🔗", "招待リンクから新メンバーが参加"),
                            .init("📊", "誰の招待か自動で記録・集計",
                                  "参加・退出・偽招待まで細かく追跡"),
                            .init("🏆", "ランキングと樹形図でコミュニティの広がりを可視化"),
                            .init("🎯", "キャンペーンで招待を促進",
                                  "目標人数と期限を設定して招待コンテストを開催できる"),
                        ],
                        useCases: [
                            .init("🥇", "招待コンテストで爆発的な成長",
                                  "「今月一番招待した人に特典を！」というキャンペーンを開催することで、既存メンバーが積極的に友人を招待してくれます。"),
                            .init("🌱", "コミュニティの根幹を把握",
                                  "誰がどのメンバーを連れてきたかの樹形図から、サーバーの成長に最も貢献しているコアメンバーを特定できます。"),
                            .init("📉", "招待品質の改善",
                                  "退出率や偽招待率を指標として、コミュニティに合う層への効果的な招待方法を探れます。"),
                        ],
                        advancedTips: [
                            "「招待者ロール」を影響力スコア上位者に付与することで、コミュニティ貢献度を見える化したステータス設計ができます",
                            "樹形図を定期的にスクリーンショットしてシェアすることで、招待競争のモチベーションを高める効果があります",
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "person.badge.plus",
                    title: "招待トラッカー",
                    subtitle: "招待数・樹形図・キャンペーン管理",
                    accentColor: Color.accentPurple
                )
            }

            FeatureRow(icon: "chart.bar.fill", title: "レベリング", subtitle: "XP・リーダーボード・ロール報酬", isComingSoon: true).disabled(true)
            FeatureRow(icon: "checkmark.circle.fill", title: "投票", subtitle: "アンケートと投票", isComingSoon: true).disabled(true)
            FeatureRow(icon: "gift.fill", title: "ギブアウェイ", subtitle: "景品プレゼント抽選", accentColor: Color.accentPink, isComingSoon: true).disabled(true)
            FeatureRow(icon: "star.fill", title: "スターボード", subtitle: "殿堂入りメッセージ", isComingSoon: true).disabled(true)
        }
    }

    private var automationSection: some View {
        Section("自動化・通知") {
            NavigationLink {
                if appState.isPro {
                    ReactionRolesView()
                } else {
                    ProUpgradeView(
                        featureIcon: "heart.fill",
                        featureTitle: "リアクションロール",
                        description: "パネルの絵文字にリアクションするだけでロールを自動付与・解除。メンバーが自分で役割や通知を管理できます。",
                        flowSteps: [
                            .init("💬", "パネルメッセージに絵文字でリアクション"),
                            .init("⚡", "対応するロールが即座に付与",
                                  "リアクションを外すと自動でロールが解除される"),
                            .init("🔓", "ロールに紐付いたチャンネル・コンテンツが解禁"),
                        ],
                        useCases: [
                            .init("🎯", "興味カテゴリを自分で選択",
                                  "「マイクラ」「Apex」「料理」など、受け取りたい話題の通知チャンネルに絵文字1つでアクセス・退場できます。"),
                            .init("🔔", "通知を自分でコントロール",
                                  "「お知らせだけ受け取る」「全通知受け取る」など、受け取る通知の種類をメンバー自身がコントロールできる仕組みを作れます。"),
                            .init("🏷", "自己紹介ロールの設定",
                                  "「デザイナー」「学生」「社会人」など、自分の属性をロールで表明できる自己紹介パネルをチャンネルに設置できます。"),
                        ],
                        advancedTips: [
                            "「認証モード」を使うと一度付与したロールはリアクションを外しても残るため、プレミアム会員資格の管理などに活用できます",
                            "「ユニークモード」を使うと複数の選択肢から1つだけ選ばせる排他的な役職設定パネルが作れます",
                        ]
                    )
                }
            } label: {
                FeatureRow(icon: "heart.fill", title: "リアクションロール", subtitle: "リアクションでロールを自動付与")
            }

            NavigationLink { WelcomeMessageView() } label: {
                FeatureRow(icon: "hand.wave.fill", title: "入退室メッセージ", subtitle: "入室・退室時の自動メッセージ")
            }

            NavigationLink { VCNotificationSettingsView() } label: {
                FeatureRow(icon: "speaker.wave.2.circle.fill", title: "VC参加通知", subtitle: "VCの入退室をチャンネルに通知")
            }

            FeatureRow(icon: "bubble.left.and.text.bubble.right.fill", title: "自動応答", subtitle: "キーワード → 返信の自動化", isComingSoon: true).disabled(true)
            FeatureRow(icon: "person.badge.plus.fill", title: "自動ロール", subtitle: "入室時にロールを自動付与", isComingSoon: true).disabled(true)
            FeatureRow(icon: "star.fill", title: "ブースト通知", subtitle: "サーバーブーストをお祝い", isComingSoon: true).disabled(true)
            FeatureRow(icon: "antenna.radiowaves.left.and.right", title: "SNS通知", subtitle: "YouTube・Twitch・Xの新着通知", isComingSoon: true).disabled(true)
        }
    }

    private var moderationSection: some View {
        Section("モデレーション") {
            NavigationLink { ModerationCenterView() } label: {
                FeatureRow(
                    icon: "shield.lefthalf.filled",
                    title: "モデレーション",
                    subtitle: "BAN・タイムアウト・警告・AutoMod を一括管理",
                    accentColor: Theme.Color.statusBad
                )
            }
            FeatureRow(icon: "shield.fill", title: "自動モデレーション", subtitle: "スパム・大文字・メンション制限", accentColor: Theme.Color.statusBad, isComingSoon: true).disabled(true)
            FeatureRow(icon: "xmark.seal.fill", title: "スパムフィルター", subtitle: "メッセージレート制限", isComingSoon: true).disabled(true)
            FeatureRow(icon: "nosign", title: "ワードフィルター", subtitle: "特定ワードをブロック", accentColor: Theme.Color.statusBad, isComingSoon: true).disabled(true)
        }
    }

    private var toolsSection: some View {
        Section("ツール") {
            NavigationLink {
                if appState.isPro {
                    ShopsListView(guildId: appState.selectedGuildId, shopType: .shop)
                } else {
                    ProUpgradeView(
                        featureIcon: "cart.fill",
                        featureTitle: "ショップ",
                        description: "Discordサーバー内に商品ページを設置し、チケット経由で交渉・販売できます。DM管理の手間なく、注文を一元管理。",
                        flowSteps: [
                            .init("🛍", "商品ページとパネルを作成してチャンネルに設置"),
                            .init("💬", "購入希望者がチケットで問い合わせ",
                                  "専用チャンネルが自動作成され、1対1でやり取りが始まる"),
                            .init("💰", "交渉・詳細確認・決済"),
                            .init("📦", "納品・取引完了",
                                  "やり取りはすべてログとして保存される"),
                        ],
                        useCases: [
                            .init("🎨", "クリエイターのコミッション受付",
                                  "イラスト・動画・音楽などの依頼をDiscordで完結させられます。DMを使わず、注文情報が散らばらずに管理できます。"),
                            .init("🎮", "ゲームアカウント・アイテム取引",
                                  "ゲームのアカウントやアイテムを安全に取引。チケットログが証拠になるため、トラブル時にも対応しやすくなります。"),
                            .init("🤝", "代行・スキルサービスの受注",
                                  "設定代行・翻訳・データ入力など、スキルを活かしたサービスの受注に。条件確認から納品まで1つのチケットで完結します。"),
                        ],
                        advancedTips: [
                            "「実績ギャラリー」チャンネルに過去の制作物を掲載し、ショップパネルへ誘導することで購入転換率を高められます",
                            "自販機機能と組み合わせることで「即時購入（定額）」と「交渉あり購入（変動）」を用途に応じて使い分けられます",
                        ]
                    )
                }
            } label: {
                FeatureRow(icon: "cart.fill", title: "ショップ", subtitle: "商品販売・チケット交渉")
            }

            NavigationLink {
                if appState.isPro {
                    ShopsListView(guildId: appState.selectedGuildId, shopType: .vendingMachine)
                } else {
                    ProUpgradeView(
                        featureIcon: "storefront.fill",
                        featureTitle: "自販機",
                        description: "支払い情報を送るだけで取引が完了。価格交渉不要な商品の即時販売に特化した、完全自動の販売機能です。",
                        flowSteps: [
                            .init("🏪", "購入ボタン付きのパネルをチャンネルに設置"),
                            .init("⚡", "購入者が支払い情報を送信",
                                  "購入ボタンを押して情報を入力するだけ。スタッフへの連絡は不要"),
                            .init("✅", "内容が自動で記録・管理"),
                            .init("🎁", "商品・情報が即座に届く",
                                  "スタッフが手動で対応しなくても取引が成立する"),
                        ],
                        useCases: [
                            .init("📋", "定額デジタルコンテンツの即時販売",
                                  "PDF・テンプレート・素材集など、価格が固定でやり取り不要な商品に最適。注文が届いたら届けるだけです。"),
                            .init("🎮", "ゲームアカウント・チートの販売",
                                  "価格が決まっているゲームアカウントやアイテムを、24時間無人で受け付け・管理できます。"),
                            .init("🎪", "イベント参加費・チケット販売",
                                  "オンラインイベントの参加費を無人で受け付け。支払い完了メンバーへのロール自動付与と組み合わせることも可能です。"),
                        ],
                        advancedTips: [
                            "複数の自販機パネルを「カテゴリ別」にチャンネルへ並べることで、ショッピングモールのような分かりやすい売り場を作れます",
                            "ショップ機能（交渉あり）と自販機（即時・定額）を使い分けることで、あらゆるタイプの商品・サービスに対応できます",
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "storefront.fill",
                    title: "自販機",
                    subtitle: "即時購入・スムーズな取引",
                    accentColor: Theme.Color.statusOK
                )
            }

            NavigationLink {
                if appState.isPro {
                    StatChannelsView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "chart.bar.xaxis",
                        featureTitle: "ステータスチャンネル",
                        description: "メンバー数やBoost数をVCチャンネル名にリアルタイム表示。サーバーの今の状態をひと目で伝えられます。",
                        flowSteps: [
                            .init("⚙️", "表示したい指標とフォーマットを設定",
                                  "「👥 メンバー: {count}人」のように好きな書式で設定できる"),
                            .init("🔄", "Noxy BotがDiscordと自動で同期",
                                  "設定後は完全自動。更新や操作は一切不要"),
                            .init("📊", "VCチャンネル名にリアルタイム表示",
                                  "サーバーの誰でも、どのデバイスからでも確認できる"),
                        ],
                        useCases: [
                            .init("👥", "メンバー数でサーバーの活気をアピール",
                                  "「👥 メンバー: 1,234人」と常時表示することで、新規訪問者に信頼感と賑わいをひと目で伝えられます。"),
                            .init("🚀", "Boost状況をリアルタイムで可視化",
                                  "現在のBoost数やレベルを表示し、「あと○人でLv.3！」のような動機付け効果が生まれます。"),
                            .init("📈", "オンライン人数で参加タイミングを誘導",
                                  "「今38人がオンライン」と表示することで、「今なら盛り上がってる！」という参加意欲を引き出せます。"),
                        ],
                        advancedTips: [
                            "「📊 {count}人のメンバー」「🚀 Boost Lv.{level}」などを複数並べてダッシュボード風のチャンネルリストを作れます",
                            "カスタムフォーマットで「${count}人の仲間たちと」のように、サーバーのキャラクターや雰囲気に合わせた表現にできます",
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "chart.bar.xaxis",
                    title: "ステータスチャンネル",
                    subtitle: "メンバー数・Boost数などをVC名に表示",
                    accentColor: .accentPurple
                )
            }
        }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var accentColor: Color = Theme.Color.accent
    var isComingSoon: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Theme.Color.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    }
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)

                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isComingSoon {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.vertical, 2)
        .opacity(isComingSoon ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    FeaturesTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}

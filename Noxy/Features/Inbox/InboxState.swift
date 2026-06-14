import Foundation
import SwiftUI

extension Notification.Name {
    static let openInboxTab = Notification.Name("com.noxy.openInboxTab")
}

@Observable
final class InboxState {
    static let shared = InboxState()

    var unreadCount: Int = 0

    private init() {}

    /// 未読通知数から更新（MainTabView の scenePhase フックから呼ばれる）
    @MainActor
    func refresh(using service: any NotificationServiceProtocol) async {
        let items = (try? await service.fetchAll()) ?? []
        unreadCount = items.filter { !$0.read }.count
    }

    /// InboxView がロード完了後に直接件数をセットする
    @MainActor
    func update(unreadCount: Int) {
        self.unreadCount = unreadCount
    }
}

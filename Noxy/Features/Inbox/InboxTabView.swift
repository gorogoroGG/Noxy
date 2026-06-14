import SwiftUI

struct InboxTabView: View {
    var body: some View {
        InboxView()
    }
}

#Preview {
    InboxTabView()
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .environment(AuthManager(services: ServiceContainer.mock()))
}

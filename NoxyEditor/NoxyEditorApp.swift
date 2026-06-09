import SwiftUI
import AppKit

// MARK: - AppDelegate: ウィンドウが閉じられた後も再表示できるように

class AppDelegate: NSObject, NSApplicationDelegate {
    /// SwiftUI の openWindow アクションへの参照 (App.body で設定される)
    static var requestOpenWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI がウィンドウを生成するのを少し待ち、存在しなければ強制オープン
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let hasVisibleWindow = NSApplication.shared.windows.contains { $0.isVisible }
            if !hasVisibleWindow {
                AppDelegate.requestOpenWindow?()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Dock アイコンクリック時にウィンドウがなければ開く
            AppDelegate.requestOpenWindow?()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // ウィンドウを閉じてもアプリはDockに残す
    }
}

// MARK: - App Entry Point

@main
struct NoxyEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // AppDelegate が呼び出せるように openWindow アクションを登録
        // (body は起動時に同期的に評価されるため、asyncAfter より先に設定される)
        let _ = { AppDelegate.requestOpenWindow = { openWindow(id: "editor") } }()

        WindowGroup(id: "editor") {
            EditorMainWindow()
                .preferredColorScheme(.dark)
                .onAppear {
                    EditorState.shared.takeSnapshot([
                        "welcome_title":       "Welcome back!",
                        "welcome_subtitle":    "My Server",
                        "quick_actions_title": "クイックアクション",
                        "quick_actions_max":   "8",
                        "notifications_title": "お知らせ",
                        "notifications_max":   "5",
                    ])
                }
        }
        .defaultSize(width: 1280, height: 820)
    }
}

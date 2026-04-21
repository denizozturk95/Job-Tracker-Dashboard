import UIKit

/// #5 — Home Screen long-press quick actions.
/// iOS surfaces these when the user long-presses the app icon.
final class AppDelegate: NSObject, UIApplicationDelegate {

    enum ShortcutType: String {
        case newApplication = "com.deniz.jobtracker.shortcut.new"
        case quickAdd       = "com.deniz.jobtracker.shortcut.quickadd"
        case openBoard      = "com.deniz.jobtracker.shortcut.board"
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: ShortcutType.newApplication.rawValue,
                localizedTitle: "New Application",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: ShortcutType.quickAdd.rawValue,
                localizedTitle: "Quick Add",
                localizedSubtitle: "Parse a sentence or URL",
                icon: UIApplicationShortcutIcon(systemImageName: "sparkles"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: ShortcutType.openBoard.rawValue,
                localizedTitle: "Open Board",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "rectangle.split.3x1"),
                userInfo: nil
            )
        ]
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if let type = ShortcutType(rawValue: shortcutItem.type) {
            ShortcutRouter.shared.pending = type
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    /// Scene-based launch handler — catches shortcut taps that open the app fresh.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem, let type = ShortcutType(rawValue: shortcut.type) {
            ShortcutRouter.shared.pending = type
        }
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}

/// Observable bridge from AppDelegate → SwiftUI.
final class ShortcutRouter: ObservableObject {
    static let shared = ShortcutRouter()
    @Published var pending: AppDelegate.ShortcutType?
}

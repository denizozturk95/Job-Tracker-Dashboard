import SwiftUI
import SwiftData
import UserNotifications

@main
struct JobTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer = AppSchema.makeContainer()

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded: Bool = false

    init() {
        BackgroundTasksService.registerHandlers(container: container)
        TipKitSetup.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .task {
                    _ = await NotificationService.shared.requestAuthorizationIfNeeded()
                    NotificationService.shared.scheduleWeeklyDigest(
                        title: "Your week in applications",
                        body: "Open JobTracker for your Sunday digest."
                    )
                    BackgroundTasksService.scheduleGhostingScan()
                    BackgroundTasksService.scheduleWeeklyDigest()
                    await drainShareQueue()
                }
                .onOpenURL { url in
                    DeepLinkHandler.shared.handle(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await drainShareQueue() }
                    }
                }
                .sheet(isPresented: .constant(!hasOnboarded)) {
                    OnboardingView(isPresented: Binding(
                        get: { !hasOnboarded },
                        set: { hasOnboarded = !$0 }
                    ))
                    .interactiveDismissDisabled()
                }
        }
    }

    @MainActor
    private func drainShareQueue() async {
        let context = container.mainContext
        let n = await ShareQueueService.drain(into: context)
        if n > 0 {
            // Small toast-less signal via notification — users usually see the app anyway.
        }
    }
}

/// Routes `jobtracker://...` deeplinks from notifications / share extension / widgets.
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    @Published var pendingApplicationID: UUID?
    @Published var pendingInterviewID: UUID?
    @Published var pendingQuickAddText: String?

    func handle(_ url: URL) {
        guard url.scheme == "jobtracker" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "application":
            if let first = parts.first, let id = UUID(uuidString: first) {
                pendingApplicationID = id
            }
        case "interview":
            if let first = parts.first, let id = UUID(uuidString: first) {
                pendingInterviewID = id
            }
        case "quickadd":
            pendingQuickAddText = url.query?.removingPercentEncoding
        default:
            break
        }
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var deepLink = DeepLinkHandler.shared
    @StateObject private var shortcutRouter = ShortcutRouter.shared
    @State private var selection: Tab = .applications
    @State private var applicationsPath = NavigationPath()
    @State private var interviewsPath = NavigationPath()
    @State private var showingNewFromShortcut = false
    @State private var showingQuickAddFromShortcut = false

    enum Tab: Hashable { case applications, board, interviews, dashboard, settings }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $applicationsPath) {
                ApplicationsListInner()
            }
            .tabItem { Label("Applications", systemImage: "tray.full") }
            .tag(Tab.applications)

            NavigationStack {
                KanbanTabView()
            }
            .tabItem { Label("Board", systemImage: "rectangle.split.3x1") }
            .tag(Tab.board)

            NavigationStack(path: $interviewsPath) {
                InterviewsListView()
            }
            .tabItem { Label("Interviews", systemImage: "calendar") }
            .tag(Tab.interviews)

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                .tag(Tab.dashboard)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .onChange(of: deepLink.pendingApplicationID) { _, id in
            guard let id else { return }
            selection = .applications
            Task { @MainActor in
                let desc = FetchDescriptor<Application>(predicate: #Predicate { $0.id == id })
                if let app = (try? context.fetch(desc))?.first {
                    applicationsPath.append(app)
                }
                deepLink.pendingApplicationID = nil
            }
        }
        .onChange(of: deepLink.pendingInterviewID) { _, id in
            guard let id else { return }
            selection = .interviews
            Task { @MainActor in
                let desc = FetchDescriptor<Interview>(predicate: #Predicate { $0.id == id })
                if let iv = (try? context.fetch(desc))?.first {
                    interviewsPath.append(iv)
                }
                deepLink.pendingInterviewID = nil
            }
        }
        .onChange(of: shortcutRouter.pending) { _, pending in
            guard let pending else { return }
            switch pending {
            case .newApplication:
                selection = .applications
                showingNewFromShortcut = true
            case .quickAdd:
                selection = .applications
                showingQuickAddFromShortcut = true
            case .openBoard:
                selection = .board
            }
            shortcutRouter.pending = nil
        }
        .sheet(isPresented: $showingNewFromShortcut) {
            NavigationStack { ApplicationEditView(application: nil) }
        }
        .sheet(isPresented: $showingQuickAddFromShortcut) {
            NavigationStack { QuickAddView() }
        }
    }
}

/// Wraps ApplicationsListView with its own showingQuickAdd binding.
struct ApplicationsListInner: View {
    @State private var showingQuickAdd = false
    var body: some View {
        ApplicationsListView(showingQuickAdd: $showingQuickAdd)
    }
}

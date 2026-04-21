import SwiftUI
import SwiftData
import TipKit

/// Dedicated Kanban tab — board view over all active applications, with search + filter.
struct KanbanTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Application.lastStatusChange, order: .reverse)])
    private var applications: [Application]

    @State private var searchText: String = ""
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    private let dragTip = KanbanDragTip()

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "rectangle.split.3x1",
                    title: "Nothing on the board",
                    message: "Add applications and drag them across stages."
                )
            } else {
                VStack(spacing: 0) {
                    TipView(dragTip).padding(.horizontal)
                    KanbanBoardView(applications: filtered)
                }
            }
        }
        .navigationTitle("Board")
        .searchable(text: $searchText, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                FilterBar(selected: $selectedStatuses)
            }
        }
        .navigationDestination(for: Application.self) { ApplicationDetailView(application: $0) }
    }

    private var filtered: [Application] {
        let lower = searchText.lowercased()
        return applications.filter { app in
            if app.archived { return false }
            if !selectedStatuses.isEmpty && !selectedStatuses.contains(app.status) { return false }
            guard !lower.isEmpty else { return true }
            if app.role.lowercased().contains(lower) { return true }
            if let name = app.company?.name.lowercased(), name.contains(lower) { return true }
            if app.tags.contains(where: { $0.name.lowercased().contains(lower) }) { return true }
            return false
        }
    }
}

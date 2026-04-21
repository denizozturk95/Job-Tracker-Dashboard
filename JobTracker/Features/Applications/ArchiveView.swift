import SwiftUI
import SwiftData

/// #9 — view + restore archived applications.
struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Application> { $0.archived },
        sort: [SortDescriptor(\Application.lastStatusChange, order: .reverse)]
    )
    private var archived: [Application]

    var body: some View {
        Group {
            if archived.isEmpty {
                EmptyStateView(
                    systemImage: "archivebox",
                    title: "Nothing archived",
                    message: "Archived applications show up here."
                )
            } else {
                List {
                    ForEach(archived) { app in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.company?.name ?? "—").font(.headline)
                            Text(app.role).font(.subheadline).foregroundStyle(.secondary)
                            StatusBadge(status: app.status)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(app)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                app.archived = false
                                try? context.save()
                            } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Archive")
    }
}

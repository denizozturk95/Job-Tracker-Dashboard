import SwiftUI
import SwiftData
import TipKit

struct ApplicationsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Application.lastStatusChange, order: .reverse)])
    private var applications: [Application]

    @Binding var showingQuickAdd: Bool
    @State private var searchText: String = ""
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    @State private var showingNew = false
    @State private var undoTarget: Application?
    @State private var undoDismissTask: Task<Void, Never>?
    private let swipeTip = SwipeToPromoteTip()
    private let quickAddTip = QuickAddTip()

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "No applications yet",
                    message: "Track your first role. Tap + or use Quick Add.",
                    actionTitle: "Add Application",
                    action: { showingNew = true }
                )
            } else {
                listBody
            }
        }
        .overlay(alignment: .bottom) {
            if let target = undoTarget {
                UndoToast(
                    message: "Archived \(target.company?.name ?? "application")",
                    onUndo: { undoArchive() }
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: undoTarget?.id)
        .navigationTitle("Applications")
        .searchable(text: $searchText, prompt: "Search company, role, notes, tags…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingNew = true } label: { Label("New Application", systemImage: "plus") }
                    Button { showingQuickAdd = true } label: { Label("Quick Add", systemImage: "sparkles") }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                FilterBar(selected: $selectedStatuses)
            }
        }
        .sheet(isPresented: $showingNew) {
            NavigationStack { ApplicationEditView(application: nil) }
        }
        .sheet(isPresented: $showingQuickAdd) {
            NavigationStack { QuickAddView() }
        }
    }

    private var filtered: [Application] {
        let lower = searchText.lowercased()
        return applications.filter { app in
            if !selectedStatuses.isEmpty && !selectedStatuses.contains(app.status) { return false }
            if app.archived { return false }
            guard !lower.isEmpty else { return true }
            if app.role.lowercased().contains(lower) { return true }
            if let name = app.company?.name.lowercased(), name.contains(lower) { return true }
            if app.location.lowercased().contains(lower) { return true }
            if app.notes.lowercased().contains(lower) { return true }
            if app.tags.contains(where: { $0.name.lowercased().contains(lower) }) { return true }
            if app.source.lowercased().contains(lower) { return true }
            return false
        }
    }

    private var listBody: some View {
        List {
            TipView(swipeTip)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            TipView(quickAddTip)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            ForEach(filtered) { app in
                NavigationLink(value: app) {
                    ApplicationRowView(application: app)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        archive(app)
                    } label: { Label("Archive", systemImage: "archivebox") }
                }
                .swipeActions(edge: .leading) {
                    ForEach(ApplicationStatus.pipeline, id: \.self) { s in
                        if s != app.status {
                            Button {
                                app.updateStatus(s, in: context)
                                try? context.save()
                            } label: { Text(s.label) }.tint(s.color)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Application.self) { ApplicationDetailView(application: $0) }
    }

    private func archive(_ app: Application) {
        app.archived = true
        try? context.save()
        undoTarget = app
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { undoTarget = nil }
            }
        }
    }

    private func undoArchive() {
        guard let target = undoTarget else { return }
        target.archived = false
        try? context.save()
        undoTarget = nil
        undoDismissTask?.cancel()
    }
}

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill").foregroundStyle(.secondary)
            Text(message).font(.subheadline)
            Spacer()
            Button("Undo", action: onUndo).bold()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}

struct FilterBar: View {
    @Binding var selected: Set<ApplicationStatus>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ApplicationStatus.allCases) { s in
                    Button {
                        if selected.contains(s) { selected.remove(s) } else { selected.insert(s) }
                    } label: {
                        Text(s.label)
                            .font(.caption.bold())
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(selected.contains(s) ? s.color.opacity(0.85) : Color.gray.opacity(0.15))
                            .foregroundStyle(selected.contains(s) ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

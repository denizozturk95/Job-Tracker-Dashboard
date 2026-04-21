import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Horizontal Kanban board — feature #1.
struct KanbanBoardView: View {
    @Environment(\.modelContext) private var context
    let applications: [Application]
    @State private var lastDropFlavor: HapticFlavor = .soft
    @State private var dropTick: Int = 0

    private let columns: [ApplicationStatus] = ApplicationStatus.pipeline

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(columns, id: \.self) { status in
                    KanbanColumn(
                        status: status,
                        items: applications.filter { $0.status == status },
                        onDrop: { id in move(id: id, to: status) }
                    )
                    .frame(width: 280)
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.06))
        .sensoryFeedback(trigger: dropTick) { _, _ in
            switch lastDropFlavor {
            case .success: return .success
            case .warning: return .warning
            case .soft:    return .impact(weight: .light)
            }
        }
    }

    private func move(id: String, to status: ApplicationStatus) {
        guard let uuid = UUID(uuidString: id),
              let app = applications.first(where: { $0.id == uuid }) else { return }
        app.updateStatus(status, in: context)
        try? context.save()
        lastDropFlavor = status.hapticFlavor
        dropTick &+= 1
    }
}

struct KanbanColumn: View {
    let status: ApplicationStatus
    let items: [Application]
    let onDrop: (String) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(status.color).frame(width: 10, height: 10)
                Text(status.label).font(.headline)
                Spacer()
                Text("\(items.count)").font(.caption.bold()).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items) { app in
                        NavigationLink(value: app) {
                            KanbanCard(application: app)
                        }
                        .buttonStyle(.plain)
                        .draggable(app.id.uuidString) {
                            KanbanCard(application: app).opacity(0.8)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(isTargeted ? status.color.opacity(0.12) : Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            onDrop(id)
            return true
        } isTargeted: { isTargeted = $0 }
    }
}

struct KanbanCard: View {
    let application: Application
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(application.status.color.gradient)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(application.company?.name ?? "—").font(.subheadline.bold())
                Text(application.role).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !application.location.isEmpty {
                    Text(application.location).font(.caption2).foregroundStyle(.secondary)
                }
                HStack {
                    if application.priority >= 3 {
                        Image(systemName: "flag.fill").foregroundStyle(.orange).font(.caption2)
                    }
                    Text(application.lastStatusChange.relativeShort)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

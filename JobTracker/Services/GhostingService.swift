import Foundation
import SwiftData

/// Flags stalled applications (#11).
struct GhostCandidate: Identifiable {
    let id: UUID
    let applicationID: UUID
    let company: String
    let role: String
    let daysSinceUpdate: Int
}

enum GhostingService {

    /// Thresholds in days.
    static let warnAfter = 14
    static let markAfter = 30

    @MainActor
    static func scan(context: ModelContext) -> [GhostCandidate] {
        let descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { !$0.archived }
        )
        guard let apps = try? context.fetch(descriptor) else { return [] }
        let now = Date.now
        let cal = Calendar.current
        return apps.compactMap { app -> GhostCandidate? in
            guard !app.status.isTerminal else { return nil }
            let days = cal.dateComponents([.day], from: app.lastStatusChange, to: now).day ?? 0
            guard days >= warnAfter else { return nil }
            return GhostCandidate(
                id: UUID(),
                applicationID: app.id,
                company: app.company?.name ?? "Unknown",
                role: app.role,
                daysSinceUpdate: days
            )
        }
    }

    @MainActor
    static func autoMarkGhosted(context: ModelContext) {
        let candidates = scan(context: context).filter { $0.daysSinceUpdate >= markAfter }
        guard !candidates.isEmpty else { return }
        for c in candidates {
            let targetID = c.applicationID
            let desc = FetchDescriptor<Application>(
                predicate: #Predicate { $0.id == targetID }
            )
            if let app = (try? context.fetch(desc))?.first {
                app.updateStatus(.ghosted, note: "Auto-marked after \(c.daysSinceUpdate) days", in: context)
            }
        }
        try? context.save()
    }
}

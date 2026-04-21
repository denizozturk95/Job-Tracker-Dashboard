import Foundation
import SwiftData

/// Drains pending URLs written by the Share Extension (#2 / #4).
/// Each entry becomes a Saved application, enriched asynchronously via URLIngestService.
enum ShareQueueService {

    @MainActor
    static func drain(into context: ModelContext) async -> Int {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return 0 }
        let pending = defaults.array(forKey: AppGroup.pendingIngestKey) as? [[String: String]] ?? []
        guard !pending.isEmpty else { return 0 }
        defaults.removeObject(forKey: AppGroup.pendingIngestKey)

        var count = 0
        for entry in pending {
            guard let urlString = entry["url"], let url = URL(string: urlString) else { continue }
            let ingested = await URLIngestService.ingest(url: url)
            let companyName = ingested.company ?? url.host?.replacingOccurrences(of: "www.", with: "") ?? "Unknown"
            let role = ingested.title ?? "Role TBD"

            let company = findOrCreateCompany(named: companyName, in: context)
            let app = Application(
                role: role,
                company: company,
                location: ingested.location ?? "",
                source: url.host ?? "",
                postingURL: urlString,
                status: .saved
            )
            if let comment = entry["comment"], !comment.isEmpty {
                app.notes = comment
            }
            context.insert(app)
            count += 1
        }
        try? context.save()
        return count
    }

    @MainActor
    private static func findOrCreateCompany(named raw: String, in context: ModelContext) -> Company {
        let name = raw.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return Company(name: "Unknown") }
        let desc = FetchDescriptor<Company>(predicate: #Predicate { $0.name == name })
        if let existing = (try? context.fetch(desc))?.first { return existing }
        let c = Company(name: name)
        context.insert(c)
        return c
    }
}

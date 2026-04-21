import Foundation
import SwiftData

/// CSV / JSON export + import for #16.
enum ExportService {

    @MainActor
    static func exportCSV(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Application>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let apps = (try? context.fetch(descriptor)) ?? []
        var rows = ["Company,Role,Status,Location,Remote,Source,AppliedDate,LastUpdated,URL,Notes"]
        let iso = ISO8601DateFormatter()
        for a in apps {
            let cols: [String] = [
                a.company?.name ?? "",
                a.role,
                a.status.label,
                a.location,
                a.remotePolicy.label,
                a.source,
                a.appliedDate.map { iso.string(from: $0) } ?? "",
                iso.string(from: a.lastStatusChange),
                a.postingURL ?? "",
                a.notes.replacingOccurrences(of: "\n", with: " ")
            ]
            rows.append(cols.map(csvEscape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    @MainActor
    static func exportJSON(context: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<Application>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let apps = (try? context.fetch(descriptor)) ?? []
        let payload = apps.map { a in
            ExportedApplication(
                company: a.company?.name ?? "",
                role: a.role,
                status: a.status.rawValue,
                location: a.location,
                remote: a.remotePolicy.rawValue,
                source: a.source,
                appliedDate: a.appliedDate,
                lastUpdated: a.lastStatusChange,
                url: a.postingURL,
                notes: a.notes,
                tags: a.tags.map(\.name)
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}

struct ExportedApplication: Codable {
    let company: String
    let role: String
    let status: String
    let location: String
    let remote: String
    let source: String
    let appliedDate: Date?
    let lastUpdated: Date
    let url: String?
    let notes: String
    let tags: [String]
}

enum ImportService {

    @MainActor
    static func importCSV(_ csv: String, into context: ModelContext) -> Int {
        let lines = csv.split(separator: "\n").map(String.init)
        guard lines.count > 1 else { return 0 }
        var imported = 0
        for line in lines.dropFirst() {
            let cols = parseCSVLine(line)
            guard cols.count >= 3 else { continue }
            let companyName = cols[0]
            let role = cols[1]
            let statusLabel = cols.count > 2 ? cols[2] : "Saved"
            let location = cols.count > 3 ? cols[3] : ""
            let source = cols.count > 5 ? cols[5] : ""
            let url = cols.count > 8 ? cols[8] : ""

            let company = findOrCreateCompany(named: companyName, in: context)
            let status = ApplicationStatus.allCases.first { $0.label.caseInsensitiveCompare(statusLabel) == .orderedSame } ?? .saved
            let app = Application(
                role: role,
                company: company,
                location: location,
                source: source,
                postingURL: url.isEmpty ? nil : url,
                status: status
            )
            context.insert(app)
            imported += 1
        }
        try? context.save()
        return imported
    }

    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let items = try decoder.decode([ExportedApplication].self, from: data)
        for item in items {
            let company = findOrCreateCompany(named: item.company, in: context)
            let status = ApplicationStatus(rawValue: item.status) ?? .saved
            let remote = RemotePolicy(rawValue: item.remote) ?? .onsite
            let app = Application(
                role: item.role,
                company: company,
                location: item.location,
                remotePolicy: remote,
                source: item.source,
                postingURL: item.url,
                status: status,
                appliedDate: item.appliedDate,
                notes: item.notes
            )
            context.insert(app)
        }
        try context.save()
        return items.count
    }

    @MainActor
    private static func findOrCreateCompany(named raw: String, in context: ModelContext) -> Company {
        let name = raw.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return Company(name: "Unknown") }
        let descriptor = FetchDescriptor<Company>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let created = Company(name: name)
        context.insert(created)
        return created
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                if inQuotes, line.index(after: i) < line.endIndex, line[line.index(after: i)] == "\"" {
                    current.append("\"")
                    i = line.index(after: i)
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }
}

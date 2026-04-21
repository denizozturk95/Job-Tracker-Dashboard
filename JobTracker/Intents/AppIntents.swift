import AppIntents
import SwiftData
import Foundation

/// #19 — Siri / Shortcuts. All intents open or mutate the shared store.

struct LogApplicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Job Application"
    static var description = IntentDescription("Quickly create a new application entry.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Company")
    var company: String

    @Parameter(title: "Role")
    var role: String

    @Parameter(title: "Status", default: "applied")
    var statusName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = await MainActor.run { AppSchema.makeContainer() }
        let status = ApplicationStatus.allCases.first {
            $0.rawValue == statusName.lowercased() || $0.label.caseInsensitiveCompare(statusName) == .orderedSame
        } ?? .applied

        await MainActor.run {
            let context = ModelContext(container)
            let companyObj = findOrCreateCompany(named: company, in: context)
            let app = Application(role: role, company: companyObj, status: status, appliedDate: status == .applied ? .now : nil)
            context.insert(app)
            try? context.save()
        }
        return .result(dialog: "Logged \(role) at \(company).")
    }

    @MainActor
    private func findOrCreateCompany(named raw: String, in context: ModelContext) -> Company {
        let name = raw.trimmingCharacters(in: .whitespaces)
        let desc = FetchDescriptor<Company>(predicate: #Predicate { $0.name == name })
        if let existing = (try? context.fetch(desc))?.first { return existing }
        let c = Company(name: name)
        context.insert(c)
        return c
    }
}

struct NextInterviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Interview"
    static var description = IntentDescription("Tells you when and with whom your next interview is.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = await MainActor.run { AppSchema.makeContainer() }
        let (company, when): (String?, Date?) = await MainActor.run {
            let context = ModelContext(container)
            let desc = FetchDescriptor<Interview>(
                sortBy: [SortDescriptor(\.datetime)]
            )
            let all = (try? context.fetch(desc)) ?? []
            if let next = all.first(where: { $0.datetime > .now }) {
                return (next.application?.company?.name, next.datetime)
            }
            return (nil, nil)
        }

        guard let company, let when else {
            return .result(dialog: "No upcoming interviews.")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: when, relativeTo: .now)
        return .result(dialog: "Your next interview is with \(company) \(relative).")
    }
}

struct JobTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogApplicationIntent(),
            phrases: [
                "Log an application in \(.applicationName)",
                "Add a job to \(.applicationName)"
            ],
            shortTitle: "Log Application",
            systemImageName: "tray.and.arrow.down"
        )
        AppShortcut(
            intent: NextInterviewIntent(),
            phrases: [
                "When is my next interview in \(.applicationName)",
                "Next interview in \(.applicationName)"
            ],
            shortTitle: "Next Interview",
            systemImageName: "calendar.badge.clock"
        )
    }
}

import AppIntents
import SwiftData
import Foundation

/// One-tap "Log today" intent exposed to the widget (#8 interactive button).
struct LogApplicationQuickIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Today's Application"
    static var description = IntentDescription("Log an application stub for today; fill details later.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let container = AppSchema.makeContainer()
            let context = ModelContext(container)
            let company = Company(name: "New Application")
            context.insert(company)
            let app = Application(
                role: "Role TBD",
                company: company,
                status: .applied,
                appliedDate: .now
            )
            context.insert(app)
            try? context.save()
        }
        return .result()
    }
}

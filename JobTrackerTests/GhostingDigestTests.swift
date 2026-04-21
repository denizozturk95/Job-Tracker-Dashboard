import Testing
import Foundation
import SwiftData
@testable import JobTracker

@Suite("Ghosting & Digest")
@MainActor
struct GhostingDigestTests {

    private func makeContext() -> ModelContext {
        let container = AppSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test func ghostingFlagsStaleApplication() {
        let context = makeContext()
        let company = Company(name: "AcmeCo")
        context.insert(company)
        let app = Application(role: "Engineer", company: company, status: .applied)
        context.insert(app)

        // Backdate the status change 21 days.
        app.lastStatusChange = Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now
        try? context.save()

        let candidates = GhostingService.scan(context: context)
        #expect(candidates.count == 1)
        #expect(candidates.first?.company == "AcmeCo")
        #expect((candidates.first?.daysSinceUpdate ?? 0) >= 14)
    }

    @Test func ghostingIgnoresFreshAndTerminal() {
        let context = makeContext()
        let fresh = Application(role: "Fresh", company: Company(name: "X"), status: .applied)
        let offer = Application(role: "Got offer", company: Company(name: "Y"), status: .offer)
        offer.lastStatusChange = Calendar.current.date(byAdding: .day, value: -40, to: .now) ?? .now
        context.insert(fresh)
        context.insert(offer)
        try? context.save()

        let candidates = GhostingService.scan(context: context)
        #expect(candidates.isEmpty)
    }

    @Test func digestCountsAppliedThisWeek() {
        let context = makeContext()
        let company = Company(name: "Z")
        context.insert(company)
        let a1 = Application(role: "R1", company: company, status: .applied, appliedDate: .now)
        let a2 = Application(role: "R2", company: company, status: .applied,
                             appliedDate: Calendar.current.date(byAdding: .day, value: -2, to: .now))
        let a3 = Application(role: "R3", company: company, status: .applied,
                             appliedDate: Calendar.current.date(byAdding: .day, value: -30, to: .now))
        [a1, a2, a3].forEach { context.insert($0) }
        try? context.save()

        let digest = DigestService.buildDigest(context: context)
        #expect(digest.applicationsSent == 2)
    }
}

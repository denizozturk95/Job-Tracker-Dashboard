import Testing
import Foundation
import SwiftData
@testable import JobTracker

@Suite("Export / Import CSV round-trip")
@MainActor
struct ExportImportTests {

    @Test func csvRoundTrip() throws {
        let c1 = AppSchema.makeContainer(inMemory: true)
        let ctx1 = ModelContext(c1)
        let company = Company(name: "Apple")
        ctx1.insert(company)
        let app = Application(
            role: "iOS Engineer",
            company: company,
            location: "Munich",
            remotePolicy: .hybrid,
            source: "LinkedIn",
            postingURL: "https://example.com/1",
            status: .applied,
            notes: "cool, with commas, and \"quotes\""
        )
        ctx1.insert(app)
        try ctx1.save()

        let csv = ExportService.exportCSV(context: ctx1)
        #expect(csv.contains("Apple"))
        #expect(csv.contains("iOS Engineer"))

        let c2 = AppSchema.makeContainer(inMemory: true)
        let ctx2 = ModelContext(c2)
        let imported = ImportService.importCSV(csv, into: ctx2)
        #expect(imported == 1)

        let descriptor = FetchDescriptor<Application>()
        let apps = (try? ctx2.fetch(descriptor)) ?? []
        #expect(apps.count == 1)
        #expect(apps.first?.role == "iOS Engineer")
        #expect(apps.first?.company?.name == "Apple")
    }

    @Test func jsonRoundTrip() throws {
        let c1 = AppSchema.makeContainer(inMemory: true)
        let ctx1 = ModelContext(c1)
        let company = Company(name: "Stripe")
        ctx1.insert(company)
        ctx1.insert(Application(role: "Swift", company: company, status: .interview))
        try ctx1.save()

        let data = try ExportService.exportJSON(context: ctx1)
        let c2 = AppSchema.makeContainer(inMemory: true)
        let ctx2 = ModelContext(c2)
        let imported = try ImportService.importJSON(data, into: ctx2)
        #expect(imported == 1)
    }
}

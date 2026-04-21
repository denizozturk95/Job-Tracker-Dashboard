import Testing
import Foundation
@testable import JobTracker

@Suite("QuickAddParser")
struct QuickAddParserTests {

    @Test func detectsAppliedStatus() {
        let r = QuickAddParser.parse("Apple iOS Engineer Munich applied today")
        #expect(r.status == .applied)
    }

    @Test func detectsURL() {
        let r = QuickAddParser.parse("https://jobs.example.com/role/123 applied")
        #expect(r.url?.host == "jobs.example.com")
    }

    @Test func parserDoesNotCrashOnShortInput() {
        // NLTagger's NER is unreliable for short strings; the parser is best-effort.
        // This test just ensures graceful behavior.
        let r = QuickAddParser.parse("x")
        #expect(r.status == .saved)
    }

    @Test func todayResolvesToNow() {
        let r = QuickAddParser.parse("applied today")
        #expect(r.date != nil)
        if let date = r.date {
            let diff = abs(date.timeIntervalSinceNow)
            #expect(diff < 86_400)
        }
    }

    @Test func rejectionKeyword() {
        let r = QuickAddParser.parse("rejection from Meta yesterday")
        #expect(r.status == .rejected)
    }

    @Test func defaultStatusIsSaved() {
        let r = QuickAddParser.parse("Interesting posting about AI")
        #expect(r.status == .saved)
    }
}

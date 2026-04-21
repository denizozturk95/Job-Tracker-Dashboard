import Foundation
import SwiftData

/// Weekly summary for #14.
struct WeeklyDigest {
    var applicationsSent: Int
    var interviewsHeld: Int
    var interviewsUpcoming: Int
    var statusChanges: Int
    var stalledCount: Int
    var generatedAt: Date

    var headline: String {
        "\(applicationsSent) applied · \(interviewsHeld) interviews · \(stalledCount) stalled"
    }
}

enum DigestService {

    @MainActor
    static func buildDigest(context: ModelContext, weekEnding: Date = .now) -> WeeklyDigest {
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -7, to: weekEnding) ?? weekEnding

        let appDescriptor = FetchDescriptor<Application>()
        let apps = (try? context.fetch(appDescriptor)) ?? []

        let applicationsSent = apps.filter {
            guard let d = $0.appliedDate else { return false }
            return d >= weekStart && d <= weekEnding
        }.count

        let eventDescriptor = FetchDescriptor<StatusEvent>()
        let events = (try? context.fetch(eventDescriptor)) ?? []
        let statusChanges = events.filter { $0.at >= weekStart && $0.at <= weekEnding }.count

        let interviewDescriptor = FetchDescriptor<Interview>()
        let interviews = (try? context.fetch(interviewDescriptor)) ?? []
        let interviewsHeld = interviews.filter { $0.datetime >= weekStart && $0.datetime <= weekEnding }.count
        let interviewsUpcoming = interviews.filter { $0.datetime > weekEnding && $0.datetime <= cal.date(byAdding: .day, value: 7, to: weekEnding)! }.count

        let stalled = GhostingService.scan(context: context).count

        return WeeklyDigest(
            applicationsSent: applicationsSent,
            interviewsHeld: interviewsHeld,
            interviewsUpcoming: interviewsUpcoming,
            statusChanges: statusChanges,
            stalledCount: stalled,
            generatedAt: .now
        )
    }
}

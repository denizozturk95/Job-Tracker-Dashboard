import Foundation
import ActivityKit

/// Shared between the main app (starts/updates) and the widget extension (renders).
struct InterviewActivityAttributes: ActivityAttributes {
    public typealias ContentState = InterviewActivityState

    public struct InterviewActivityState: Codable, Hashable {
        var secondsRemaining: Int
        var joinURL: String?
    }

    var company: String
    var role: String
    var type: String
    var startDate: Date
}

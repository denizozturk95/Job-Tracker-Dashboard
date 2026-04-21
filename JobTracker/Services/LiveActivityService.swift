import Foundation
import ActivityKit

@available(iOS 16.2, *)
enum LiveActivityService {

    /// Start a Live Activity only if the interview is close enough to make sense
    /// (within 2 hours) and Activities are authorized.
    @discardableResult
    static func startIfSoon(company: String, role: String, type: String, start: Date, joinURL: String?) -> String? {
        guard start.timeIntervalSinceNow > 0,
              start.timeIntervalSinceNow <= 2 * 3600,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attrs = InterviewActivityAttributes(company: company, role: role, type: type, startDate: start)
        let state = InterviewActivityAttributes.InterviewActivityState(
            secondsRemaining: Int(start.timeIntervalSinceNow),
            joinURL: joinURL
        )
        let content = ActivityContent(state: state, staleDate: start.addingTimeInterval(3600))
        return try? Activity.request(attributes: attrs, content: content, pushType: nil).id
    }

    static func endAll() async {
        for activity in Activity<InterviewActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func end(activityID: String) async {
        for activity in Activity<InterviewActivityAttributes>.activities where activity.id == activityID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

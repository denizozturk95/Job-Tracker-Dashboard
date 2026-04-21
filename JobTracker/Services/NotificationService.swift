import Foundation
import UserNotifications

/// Schedules local reminders (#3 smart reminders, #11 ghosting, #14 weekly digest).
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        if settings.authorizationStatus == .denied { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Follow-ups

    func scheduleFollowUp(applicationID: UUID, company: String, role: String, daysFromNow: Int = 7) {
        let content = UNMutableNotificationContent()
        content.title = "Follow up on \(company)"
        content.body = "It's been \(daysFromNow) days since you applied for \(role). Nudge them?"
        content.sound = .default
        content.userInfo = ["deeplink": "jobtracker://application/\(applicationID.uuidString)"]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, Double(daysFromNow) * 86_400),
            repeats: false
        )
        let id = "followup.\(applicationID.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleThankYou(interviewID: UUID, company: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Send thank-you to \(company)"
        content.body = "24 hours since your interview — a short note makes a real difference."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, date.timeIntervalSinceNow),
            repeats: false
        )
        let id = "thankyou.\(interviewID.uuidString)"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func scheduleInterviewReminder(interviewID: UUID, company: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Interview with \(company) in 1 hour"
        content.body = "Open prep mode for your questions and STAR stories."
        content.sound = .default
        content.userInfo = ["deeplink": "jobtracker://interview/\(interviewID.uuidString)"]

        let fireDate = date.addingTimeInterval(-3600)
        guard fireDate > .now else { return }
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow,
            repeats: false
        )
        let id = "interview.\(interviewID.uuidString)"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Ghosting

    func scheduleGhostingAlert(applicationID: UUID, company: String, daysSinceUpdate: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(company) may have gone quiet"
        content.body = "\(daysSinceUpdate) days since the last update. Mark as ghosted or reach out?"
        content.sound = .default

        let id = "ghost.\(applicationID.uuidString)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Offer deadline (#11)

    /// Schedules "3 days left" and "1 day left" reminders before an offer deadline.
    func scheduleOfferDeadline(offerID: UUID, company: String, deadline: Date) {
        cancelOfferDeadline(offerID: offerID)
        let offsets: [(Int, String)] = [(3, "3 days"), (1, "1 day")]
        for (days, label) in offsets {
            let fire = Calendar.current.date(byAdding: .day, value: -days, to: deadline) ?? deadline
            guard fire > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Offer from \(company) — \(label) left"
            content.body = "Decide before \(deadline.formatted(date: .abbreviated, time: .shortened))."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: fire.timeIntervalSinceNow, repeats: false
            )
            let id = offerNotificationID(offerID, days: days)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    func cancelOfferDeadline(offerID: UUID) {
        let ids = [3, 1].map { offerNotificationID(offerID, days: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func offerNotificationID(_ offerID: UUID, days: Int) -> String {
        "offer.\(offerID.uuidString).\(days)d"
    }

    // MARK: Weekly digest

    func scheduleWeeklyDigest(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly.digest", content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

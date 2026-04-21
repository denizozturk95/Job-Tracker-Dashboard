import Foundation
import BackgroundTasks
import SwiftData
import UserNotifications

/// Registers + schedules background work (#4 ghosting scan, #5 weekly digest).
enum BackgroundTasksService {

    @MainActor
    static func registerHandlers(container: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskID.ghostingScan,
            using: nil
        ) { task in
            handleGhostingScan(task: task as? BGAppRefreshTask, container: container)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskID.weeklyDigest,
            using: nil
        ) { task in
            handleWeeklyDigest(task: task as? BGProcessingTask, container: container)
        }
    }

    static func scheduleGhostingScan() {
        let request = BGAppRefreshTaskRequest(identifier: BGTaskID.ghostingScan)
        request.earliestBeginDate = Date().addingTimeInterval(24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func scheduleWeeklyDigest() {
        let request = BGProcessingTaskRequest(identifier: BGTaskID.weeklyDigest)
        request.earliestBeginDate = nextSunday9am()
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handlers

    private static func handleGhostingScan(task: BGAppRefreshTask?, container: ModelContainer) {
        scheduleGhostingScan()  // reschedule next run

        Task { @MainActor in
            let context = ModelContext(container)
            let candidates = GhostingService.scan(context: context)

            // Notify about warn-tier candidates, auto-mark the terminal ones.
            for c in candidates where c.daysSinceUpdate >= GhostingService.warnAfter
                                  && c.daysSinceUpdate < GhostingService.markAfter {
                NotificationService.shared.scheduleGhostingAlert(
                    applicationID: c.applicationID,
                    company: c.company,
                    daysSinceUpdate: c.daysSinceUpdate
                )
            }
            GhostingService.autoMarkGhosted(context: context)

            task?.setTaskCompleted(success: true)
        }
    }

    private static func handleWeeklyDigest(task: BGProcessingTask?, container: ModelContainer) {
        scheduleWeeklyDigest()  // reschedule

        Task { @MainActor in
            let context = ModelContext(container)
            let digest = DigestService.buildDigest(context: context)
            postDigestNotification(digest)
            task?.setTaskCompleted(success: true)
        }
    }

    private static func postDigestNotification(_ digest: WeeklyDigest) {
        let content = UNMutableNotificationContent()
        content.title = "Your week in applications"
        content.body = "\(digest.applicationsSent) applied · \(digest.interviewsHeld) interviewed · \(digest.stalledCount) stalled"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "weekly.digest.now", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func nextSunday9am() -> Date {
        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 9
        components.minute = 0
        let cal = Calendar.current
        return cal.nextDate(after: .now, matching: components, matchingPolicy: .nextTime) ?? Date().addingTimeInterval(7 * 86400)
    }
}

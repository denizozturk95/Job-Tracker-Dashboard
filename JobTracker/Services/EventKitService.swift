import Foundation
import EventKit

/// EventKit bridge for #12 — write interviews to the user's calendar.
final class EventKitService {
    static let shared = EventKitService()
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }

    @discardableResult
    func upsertInterviewEvent(
        existingID: String?,
        title: String,
        notes: String,
        location: String,
        joinURL: String?,
        start: Date,
        durationMin: Int
    ) -> String? {
        let event: EKEvent
        if let existingID, let existing = store.event(withIdentifier: existingID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
        }
        event.title = title
        event.location = location
        event.notes = {
            var lines = [notes]
            if let joinURL { lines.append("Join: \(joinURL)") }
            return lines.joined(separator: "\n")
        }()
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(durationMin) * 60)
        if event.hasAlarms == false {
            event.addAlarm(EKAlarm(relativeOffset: -3600))
        }
        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func deleteEvent(identifier: String) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent)
    }
}

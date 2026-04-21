import WidgetKit
import SwiftUI
import SwiftData
import ActivityKit
import AppIntents

// MARK: - Widget bundle

@main
struct JobTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextInterviewWidget()
        StreakWidget()
        if #available(iOS 16.2, *) {
            NextInterviewLiveActivity()
        }
    }
}

// MARK: - Shared read helpers

@MainActor
enum WidgetStore {
    static func snapshot() -> (nextInterview: (company: String, role: String, start: Date)?,
                               streak: Int,
                               weekCount: Int) {
        let container = AppSchema.makeContainer()
        let context = ModelContext(container)

        let ivDesc = FetchDescriptor<Interview>(sortBy: [SortDescriptor(\.datetime)])
        let interviews = (try? context.fetch(ivDesc)) ?? []
        let next = interviews.first { $0.datetime > .now }
        let nextTuple: (String, String, Date)? = next.map {
            ($0.application?.company?.name ?? "—", $0.application?.role ?? "—", $0.datetime)
        }

        let eventDesc = FetchDescriptor<StatusEvent>()
        let events = (try? context.fetch(eventDesc)) ?? []

        let cal = Calendar.current
        var daysWithActivity = Set<Date>()
        for e in events {
            daysWithActivity.insert(cal.startOfDay(for: e.at))
        }

        var streak = 0
        var day = cal.startOfDay(for: .now)
        while daysWithActivity.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }

        let weekStart = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekCount = events.filter { $0.at >= weekStart }.count

        return (nextTuple, streak, weekCount)
    }
}

// MARK: - Next Interview widget (#2)

struct NextInterviewEntry: TimelineEntry {
    let date: Date
    let company: String
    let role: String
    let interviewStart: Date?
}

struct NextInterviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextInterviewEntry {
        NextInterviewEntry(
            date: .now, company: "Apple", role: "iOS Engineer",
            interviewStart: Date().addingTimeInterval(7200)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextInterviewEntry) -> Void) {
        Task { @MainActor in
            let snap = WidgetStore.snapshot()
            let entry: NextInterviewEntry
            if let next = snap.nextInterview {
                entry = NextInterviewEntry(date: .now, company: next.company, role: next.role, interviewStart: next.start)
            } else {
                entry = NextInterviewEntry(date: .now, company: "No upcoming", role: "", interviewStart: nil)
            }
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextInterviewEntry>) -> Void) {
        Task { @MainActor in
            let snap = WidgetStore.snapshot()
            let entry: NextInterviewEntry
            if let next = snap.nextInterview {
                entry = NextInterviewEntry(date: .now, company: next.company, role: next.role, interviewStart: next.start)
            } else {
                entry = NextInterviewEntry(date: .now, company: "No upcoming", role: "", interviewStart: nil)
            }
            let refresh = snap.nextInterview?.start ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(min(refresh, Date().addingTimeInterval(900)))))
        }
    }
}

struct NextInterviewWidget: Widget {
    let kind = "NextInterviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextInterviewProvider()) { entry in
            NextInterviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Interview")
        .description("See your next interview on the Home or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct NextInterviewWidgetView: View {
    let entry: NextInterviewEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next interview").font(.caption).foregroundStyle(.secondary)
            Text(entry.company).font(.headline).lineLimit(1)
            if family != .accessoryRectangular && !entry.role.isEmpty {
                Text(entry.role).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if let start = entry.interviewStart {
                Text(start, style: .relative).font(.caption2.monospacedDigit())
            } else {
                Text("Nothing scheduled").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Streak widget (#17 + #8 interactive)

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let weekCount: Int
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 3, weekCount: 7)
    }
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        Task { @MainActor in
            let s = WidgetStore.snapshot()
            completion(StreakEntry(date: .now, streak: s.streak, weekCount: s.weekCount))
        }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        Task { @MainActor in
            let s = WidgetStore.snapshot()
            let entry = StreakEntry(date: .now, streak: s.streak, weekCount: s.weekCount)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
        }
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Application Streak")
        .description("How many days in a row you've been active.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .accessoryCircular {
            VStack {
                Image(systemName: "flame.fill")
                Text("\(entry.streak)").font(.headline)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("\(entry.streak) day streak", systemImage: "flame.fill").font(.caption.bold())
                Text("\(entry.weekCount) this week").font(.caption2).foregroundStyle(.secondary)
                Button(intent: LogApplicationQuickIntent()) {
                    Label("Log today", systemImage: "plus.circle.fill").font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
    }
}

// MARK: - Live Activity (#2 Dynamic Island)

@available(iOS 16.2, *)
struct NextInterviewLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InterviewActivityAttributes.self) { context in
            VStack(alignment: .leading) {
                Text("Interview: \(context.attributes.company)").font(.headline)
                Text(context.attributes.type).font(.caption).foregroundStyle(.secondary)
                Text(context.attributes.startDate, style: .relative)
            }
            .padding()
            .activityBackgroundTint(.purple.opacity(0.2))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.company, systemImage: "calendar").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startDate, style: .relative)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.role).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer).monospacedDigit()
            } minimal: {
                Image(systemName: "calendar")
            }
        }
    }
}

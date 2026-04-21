import SwiftUI

/// #17 — GitHub-style activity heatmap over the last ~12 weeks.
struct HeatmapView: View {
    let events: [StatusEvent]
    private let weeks = 12

    private var counts: [Date: Int] {
        let cal = Calendar.current
        var map: [Date: Int] = [:]
        for e in events {
            let day = cal.startOfDay(for: e.at)
            map[day, default: 0] += 1
        }
        return map
    }

    private var cells: [[Date]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let totalDays = weeks * 7
        let start = cal.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today
        var days: [Date] = []
        for i in 0..<totalDays {
            if let d = cal.date(byAdding: .day, value: i, to: start) { days.append(d) }
        }
        // Group into weeks (columns)
        var grid: [[Date]] = []
        for w in 0..<weeks {
            let slice = Array(days[w*7..<min(w*7 + 7, days.count)])
            grid.append(slice)
        }
        return grid
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = cal.startOfDay(for: .now)
        while let c = counts[day], c > 0 {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return .gray.opacity(0.15)
        case 1: return .green.opacity(0.3)
        case 2: return .green.opacity(0.55)
        case 3: return .green.opacity(0.75)
        default: return .green
        }
    }

    var body: some View {
        SectionCard {
            HStack {
                Text("Activity").font(.headline)
                Spacer()
                Label("\(currentStreak) day streak", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(week, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: counts[day] ?? 0))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Last \(weeks) weeks").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

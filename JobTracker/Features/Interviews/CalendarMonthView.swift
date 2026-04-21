import SwiftUI

/// Simple month view (#12 visual half) — taps an interview to open detail.
struct CalendarMonthView: View {
    let interviews: [Interview]
    @State private var anchorDate: Date = .now

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            grid
            upcomingForDay
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Button { anchorDate = cal.date(byAdding: .month, value: -1, to: anchorDate) ?? anchorDate } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(anchorDate.formatted(.dateTime.year().month(.wide))).font(.headline)
            Spacer()
            Button { anchorDate = cal.date(byAdding: .month, value: 1, to: anchorDate) ?? anchorDate } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(cal.veryShortWeekdaySymbols, id: \.self) { d in
                Text(d).font(.caption.bold()).frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var grid: some View {
        let days = monthDays(for: anchorDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let count = interviews.filter { cal.isDate($0.datetime, inSameDayAs: date) }.count
        let isToday = cal.isDateInToday(date)
        return VStack(spacing: 2) {
            Text("\(cal.component(.day, from: date))")
                .font(.caption)
                .bold(isToday)
            if count > 0 {
                Circle().fill(.purple).frame(width: 5, height: 5)
            } else {
                Color.clear.frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(isToday ? Color.accentColor.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var upcomingForDay: some View {
        let todays = interviews.filter { cal.isDateInToday($0.datetime) }.sorted { $0.datetime < $1.datetime }
        return Group {
            if !todays.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today").font(.headline)
                    ForEach(todays) { iv in
                        NavigationLink(value: iv) {
                            HStack {
                                Text(iv.datetime.formatted(date: .omitted, time: .shortened)).font(.caption.bold())
                                Text(iv.application?.company?.name ?? "—")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func monthDays(for date: Date) -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: date),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: date))
        else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: first)
        let leading = weekdayOfFirst - cal.firstWeekday
        let padding: Int = leading < 0 ? leading + 7 : leading
        var cells: [Date?] = Array(repeating: nil, count: padding)
        for d in range {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

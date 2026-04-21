import SwiftUI
import Charts

struct ApplicationRowView: View {
    let application: Application

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(application.status.color.gradient)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(application.company?.name ?? "—").font(.headline)
                Text(application.role).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    StatusBadge(status: application.status)
                    if !application.location.isEmpty {
                        Text(application.location).font(.caption2).foregroundStyle(.secondary)
                    }
                    if daysSinceUpdate >= GhostingService.warnAfter {
                        Label("\(daysSinceUpdate)d stalled", systemImage: "clock.arrow.circlepath")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            StatusSparkline(application: application)
                .frame(width: 56, height: 22)
            if application.priority >= 3 {
                Image(systemName: "flag.fill").foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var daysSinceUpdate: Int {
        Calendar.current.dateComponents([.day], from: application.lastStatusChange, to: .now).day ?? 0
    }
}

/// Tiny status-progression sparkline — Y axis is pipeline index, X is event time.
struct StatusSparkline: View {
    let application: Application

    private var points: [(Date, Int)] {
        let sorted = application.events.sorted { $0.at < $1.at }
        guard !sorted.isEmpty else {
            let idx = ApplicationStatus.pipeline.firstIndex(of: application.status) ?? 0
            return [(application.createdAt, idx), (application.lastStatusChange, idx)]
        }
        return sorted.compactMap { event in
            if let idx = ApplicationStatus.pipeline.firstIndex(of: event.to) {
                return (event.at, idx)
            }
            return nil
        }
    }

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                LineMark(
                    x: .value("At", pt.0),
                    y: .value("Stage", pt.1)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(application.status.color.gradient)
            }
            if let last = points.last {
                PointMark(
                    x: .value("At", last.0),
                    y: .value("Stage", last.1)
                )
                .foregroundStyle(application.status.color)
                .symbolSize(20)
            }
        }
        .chartYScale(domain: 0...(ApplicationStatus.pipeline.count - 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}

struct StatusBadge: View {
    let status: ApplicationStatus
    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

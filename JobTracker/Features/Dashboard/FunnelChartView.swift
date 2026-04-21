import SwiftUI
import Charts

/// #6 conversion funnel across pipeline stages.
struct FunnelChartView: View {
    let applications: [Application]
    let events: [StatusEvent]

    private var buckets: [(status: ApplicationStatus, count: Int)] {
        let pipeline = ApplicationStatus.pipeline
        return pipeline.map { s in
            let reached = applications.filter { hasReached($0, stage: s) }.count
            return (s, reached)
        }
    }

    private var avgDaysBetween: [(label: String, days: Double)] {
        let pipeline = ApplicationStatus.pipeline
        var results: [(String, Double)] = []
        for i in 0..<(pipeline.count - 1) {
            let from = pipeline[i]
            let to = pipeline[i+1]
            let deltas: [TimeInterval] = applications.compactMap { app in
                let fromEvent = app.events.first(where: { $0.to == from })
                let toEvent = app.events.first(where: { $0.to == to })
                guard let f = fromEvent, let t = toEvent, t.at > f.at else { return nil }
                return t.at.timeIntervalSince(f.at)
            }
            guard !deltas.isEmpty else { continue }
            let avg = deltas.reduce(0, +) / Double(deltas.count) / 86_400
            results.append(("\(from.label) → \(to.label)", avg))
        }
        return results
    }

    private func hasReached(_ app: Application, stage: ApplicationStatus) -> Bool {
        if app.status == stage { return true }
        let idxCurrent = ApplicationStatus.pipeline.firstIndex(of: app.status) ?? 0
        let idxStage = ApplicationStatus.pipeline.firstIndex(of: stage) ?? 0
        if idxCurrent >= idxStage { return true }
        return app.events.contains { $0.to == stage }
    }

    var body: some View {
        SectionCard {
            Text("Funnel").font(.headline)
            if applications.isEmpty {
                Text("Add a few applications to see your conversion.").foregroundStyle(.secondary)
            } else {
                Chart(buckets, id: \.status) { bucket in
                    BarMark(
                        x: .value("Count", bucket.count),
                        y: .value("Stage", bucket.status.label)
                    )
                    .foregroundStyle(bucket.status.color)
                    .annotation(position: .trailing) {
                        Text("\(bucket.count)").font(.caption.bold())
                    }
                }
                .frame(height: CGFloat(buckets.count) * 28 + 20)

                if !avgDaysBetween.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text("Avg. days between stages").font(.caption.bold())
                    ForEach(avgDaysBetween, id: \.label) { row in
                        HStack {
                            Text(row.label).font(.caption)
                            Spacer()
                            Text(String(format: "%.1fd", row.days)).font(.caption.bold())
                        }
                    }
                }
            }
        }
    }
}

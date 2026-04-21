import SwiftUI
import SwiftData

/// #9 — conversion rate per source (LinkedIn, referral, direct, etc.).
struct SourceConversionView: View {
    @Query private var applications: [Application]

    private struct Row: Identifiable {
        let id = UUID()
        let source: String
        let total: Int
        let reached: Int  // reached Screen or beyond
        var rate: Double { total == 0 ? 0 : Double(reached) / Double(total) }
    }

    private var rows: [Row] {
        let buckets = Dictionary(grouping: applications.filter { !$0.archived }) { app in
            let trimmed = app.source.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unknown" : trimmed
        }
        return buckets.map { key, apps in
            let reached = apps.filter { reachedScreenOrBeyond($0) }.count
            return Row(source: key, total: apps.count, reached: reached)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    private func reachedScreenOrBeyond(_ app: Application) -> Bool {
        let beyond: Set<ApplicationStatus> = [.screen, .interview, .offer, .rejected]
        if beyond.contains(app.status) { return true }
        return app.events.contains { beyond.contains($0.to) }
    }

    var body: some View {
        SectionCard {
            Text("Response rate by source").font(.headline)
            if rows.isEmpty {
                Text("Add a source when logging applications to see your conversion.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.source).bold()
                            Spacer()
                            Text("\(Int(row.rate * 100))%")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(rateColor(row.rate))
                            Text("(\(row.reached)/\(row.total))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.15))
                                Capsule()
                                    .fill(rateColor(row.rate).gradient)
                                    .frame(width: geo.size.width * row.rate)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private func rateColor(_ r: Double) -> Color {
        switch r {
        case 0..<0.15: return .red
        case 0.15..<0.35: return .orange
        case 0.35..<0.6: return .blue
        default: return .green
        }
    }
}

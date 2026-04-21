import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var applications: [Application]
    @Query private var events: [StatusEvent]
    @Query private var interviews: [Interview]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WeeklyDigestCard()
                    FunnelChartView(applications: applications, events: events)
                    SourceConversionView()
                    HeatmapView(events: events)
                    SalaryCompareView()
                    StalledCard()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct WeeklyDigestCard: View {
    @Environment(\.modelContext) private var context
    @State private var digest: WeeklyDigest?

    var body: some View {
        SectionCard {
            Text("This week").font(.headline)
            if let d = digest {
                HStack(spacing: 16) {
                    stat(value: d.applicationsSent, label: "Applied")
                    stat(value: d.interviewsHeld, label: "Interviews")
                    stat(value: d.interviewsUpcoming, label: "Upcoming")
                    stat(value: d.stalledCount, label: "Stalled")
                }
            } else {
                Text("Computing…").foregroundStyle(.secondary)
            }
        }
        .onAppear {
            digest = DigestService.buildDigest(context: context)
        }
    }

    @ViewBuilder
    private func stat(value: Int, label: String) -> some View {
        VStack {
            Text("\(value)").font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StalledCard: View {
    @Environment(\.modelContext) private var context
    @State private var candidates: [GhostCandidate] = []

    var body: some View {
        SectionCard {
            HStack {
                Text("Stalled (ghosting?)").font(.headline)
                Spacer()
                Text("\(candidates.count)").foregroundStyle(.secondary)
            }
            if candidates.isEmpty {
                Text("Everything fresh.").foregroundStyle(.secondary)
            } else {
                ForEach(candidates.prefix(5)) { c in
                    HStack {
                        Text(c.company).bold()
                        Text(c.role).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(c.daysSinceUpdate)d").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .onAppear {
            candidates = GhostingService.scan(context: context)
        }
    }
}

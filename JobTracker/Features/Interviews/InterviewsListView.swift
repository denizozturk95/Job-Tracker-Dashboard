import SwiftUI
import SwiftData

struct InterviewsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Interview.datetime)])
    private var interviews: [Interview]
    @State private var viewMode: ViewMode = .upcoming

    enum ViewMode: String, CaseIterable { case upcoming, calendar, past }

    var body: some View {
        Group {
            switch viewMode {
            case .upcoming: upcomingList
            case .calendar: CalendarMonthView(interviews: interviews)
            case .past: pastList
            }
        }
        .navigationTitle("Interviews")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationDestination(for: Interview.self) { InterviewDetailView(interview: $0) }
    }

    private var upcoming: [Interview] {
        interviews.filter { $0.datetime >= Date.now }.sorted { $0.datetime < $1.datetime }
    }

    private var past: [Interview] {
        interviews.filter { $0.datetime < Date.now }.sorted { $0.datetime > $1.datetime }
    }

    private var upcomingList: some View {
        Group {
            if upcoming.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "No upcoming interviews",
                    message: "Add an interview from an application to see it here."
                )
            } else {
                List {
                    ForEach(upcoming) { iv in
                        NavigationLink(value: iv) {
                            InterviewRow(interview: iv)
                        }
                    }
                }
            }
        }
    }

    private var pastList: some View {
        List {
            ForEach(past) { iv in
                NavigationLink(value: iv) {
                    InterviewRow(interview: iv)
                }
            }
        }
    }
}

struct InterviewRow: View {
    let interview: Interview
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(interview.application?.company?.name ?? "—").font(.headline)
                Text("\(interview.type.label) · Round \(interview.round)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(interview.datetime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch interview.outcome {
            case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .cancelled: Image(systemName: "minus.circle.fill").foregroundStyle(.orange)
            case .pending: EmptyView()
            }
        }
    }
}

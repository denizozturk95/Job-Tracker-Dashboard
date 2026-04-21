import SwiftUI
import SwiftData

struct InterviewDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var interview: Interview
    @State private var showingEdit = false
    @State private var showingPrep = false

    var body: some View {
        List {
            Section {
                Label(interview.application?.company?.name ?? "—", systemImage: "building.2")
                    .font(.headline)
                Text("\(interview.type.label) · Round \(interview.round)").foregroundStyle(.secondary)
                Text(interview.datetime.formatted(date: .complete, time: .shortened))
                Text("\(interview.durationMin) min")
                if !interview.location.isEmpty {
                    Label(interview.location, systemImage: "mappin.and.ellipse")
                }
                if let url = interview.joinURL, let parsed = URL(string: url) {
                    Link(destination: parsed) { Label("Join", systemImage: "video") }
                }
            }

            Section("Outcome") {
                Picker("Outcome", selection: Binding(
                    get: { interview.outcome },
                    set: {
                        interview.outcome = $0
                        handleOutcome($0)
                        try? context.save()
                    }
                )) {
                    ForEach(InterviewOutcome.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Prep") {
                Button { showingPrep = true } label: {
                    Label("Open Prep Mode", systemImage: "book.closed")
                }
                if !interview.questionsToAsk.isEmpty {
                    ForEach(interview.questionsToAsk, id: \.self) { q in
                        Label(q, systemImage: "questionmark.bubble").font(.subheadline)
                    }
                }
            }

            if !interview.interviewerNames.isEmpty {
                Section("People") {
                    Text(interview.interviewerNames)
                }
            }

            Section("Post-interview notes") {
                TextEditor(text: Binding(
                    get: { interview.postNotes },
                    set: { interview.postNotes = $0; try? context.save() }
                )).frame(minHeight: 100)
            }
        }
        .navigationTitle("Interview")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let app = interview.application {
                NavigationStack { InterviewEditView(application: app, interview: interview) }
            }
        }
        .sheet(isPresented: $showingPrep) {
            NavigationStack { PrepModeView(interview: interview) }
        }
    }

    private func handleOutcome(_ o: InterviewOutcome) {
        guard let app = interview.application else { return }
        switch o {
        case .passed:
            // No status change — usually more rounds follow.
            break
        case .failed:
            app.updateStatus(.rejected, note: "Failed \(interview.type.label) round", in: context)
        default: break
        }
    }
}

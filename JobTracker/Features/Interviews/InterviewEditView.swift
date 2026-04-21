import SwiftUI
import SwiftData

struct InterviewEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let application: Application
    let interview: Interview?

    @State private var round: Int = 1
    @State private var type: InterviewType = .phone
    @State private var datetime: Date = Date().addingTimeInterval(86400)
    @State private var durationMin: Int = 45
    @State private var location: String = ""
    @State private var joinURL: String = ""
    @State private var interviewerNames: String = ""
    @State private var questionsText: String = ""
    @State private var syncToCalendar: Bool = true

    var body: some View {
        Form {
            Section {
                Stepper("Round \(round)", value: $round, in: 1...10)
                Picker("Type", selection: $type) {
                    ForEach(InterviewType.allCases) { Text($0.label).tag($0) }
                }
                DatePicker("When", selection: $datetime)
                Stepper("Duration: \(durationMin) min", value: $durationMin, in: 15...240, step: 15)
            }
            Section("Location") {
                TextField("Place or 'Zoom' / 'Phone'", text: $location)
                TextField("Join URL", text: $joinURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("People") {
                TextField("Interviewer names", text: $interviewerNames)
            }
            Section("Questions to ask (one per line)") {
                TextEditor(text: $questionsText).frame(minHeight: 80)
            }
            Section("Calendar") {
                Toggle("Add to Calendar", isOn: $syncToCalendar)
            }
        }
        .navigationTitle(interview == nil ? "New Interview" : "Edit Interview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let iv = interview else {
            // sensible default for new
            round = (application.interviews.map(\.round).max() ?? 0) + 1
            return
        }
        round = iv.round
        type = iv.type
        datetime = iv.datetime
        durationMin = iv.durationMin
        location = iv.location
        joinURL = iv.joinURL ?? ""
        interviewerNames = iv.interviewerNames
        questionsText = iv.questionsToAsk.joined(separator: "\n")
    }

    private func save() {
        let questions = questionsText.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let iv: Interview
        if let existing = interview {
            existing.round = round
            existing.type = type
            existing.datetime = datetime
            existing.durationMin = durationMin
            existing.location = location
            existing.joinURL = joinURL.isEmpty ? nil : joinURL
            existing.interviewerNames = interviewerNames
            existing.questionsToAsk = questions
            iv = existing
        } else {
            let new = Interview(
                round: round, type: type, datetime: datetime,
                durationMin: durationMin, location: location,
                joinURL: joinURL.isEmpty ? nil : joinURL,
                interviewerNames: interviewerNames,
                questionsToAsk: questions
            )
            new.application = application
            context.insert(new)
            // auto-advance status
            if application.status.rawValue < ApplicationStatus.interview.rawValue {
                application.updateStatus(.interview, in: context)
            }
            iv = new
        }

        if syncToCalendar {
            Task { @MainActor in
                let granted = await EventKitService.shared.requestAccess()
                if granted {
                    let id = EventKitService.shared.upsertInterviewEvent(
                        existingID: iv.eventKitIdentifier,
                        title: "\(type.label) · \(application.company?.name ?? "Interview")",
                        notes: "Role: \(application.role)",
                        location: location,
                        joinURL: joinURL.isEmpty ? nil : joinURL,
                        start: datetime,
                        durationMin: durationMin
                    )
                    iv.eventKitIdentifier = id
                    try? context.save()
                }
            }
        }

        NotificationService.shared.scheduleInterviewReminder(
            interviewID: iv.id,
            company: application.company?.name ?? "the company",
            at: datetime
        )
        NotificationService.shared.scheduleThankYou(
            interviewID: iv.id,
            company: application.company?.name ?? "the company",
            at: datetime.addingTimeInterval(86400)
        )

        if #available(iOS 16.2, *) {
            LiveActivityService.startIfSoon(
                company: application.company?.name ?? "Interview",
                role: application.role,
                type: type.label,
                start: datetime,
                joinURL: joinURL.isEmpty ? nil : joinURL
            )
        }

        try? context.save()
        dismiss()
    }
}

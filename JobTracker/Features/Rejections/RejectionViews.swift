import SwiftUI
import SwiftData

/// #18 — rejection journaling + patterns.
struct RejectionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let application: Application

    @State private var reason: String = ""
    @State private var stage: ApplicationStatus = .interview
    @State private var feedback: String = ""
    @State private var lessons: String = ""

    var body: some View {
        Form {
            Section("Where") {
                Picker("Stage", selection: $stage) {
                    ForEach(ApplicationStatus.pipeline) { Text($0.label).tag($0) }
                }
            }
            Section("Reason (recruiter-stated)") { TextField("Reason", text: $reason, axis: .vertical) }
            Section("Feedback received") { TextEditor(text: $feedback).frame(minHeight: 80) }
            Section("Lessons learned") { TextEditor(text: $lessons).frame(minHeight: 80) }
        }
        .navigationTitle("Rejection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .onAppear {
            if let r = application.rejection {
                reason = r.reason
                stage = r.stage
                feedback = r.feedback
                lessons = r.lessonsLearned
            }
        }
    }

    private func save() {
        if let existing = application.rejection {
            existing.reason = reason
            existing.stage = stage
            existing.feedback = feedback
            existing.lessonsLearned = lessons
        } else {
            let r = Rejection(reason: reason, stage: stage, feedback: feedback, lessonsLearned: lessons)
            r.application = application
            application.rejection = r
            context.insert(r)
        }
        application.updateStatus(.rejected, in: context)
        try? context.save()
        dismiss()
    }
}

struct RejectionPatternsView: View {
    @Query(sort: [SortDescriptor(\Rejection.createdAt, order: .reverse)])
    private var rejections: [Rejection]

    private var byStage: [(ApplicationStatus, Int)] {
        Dictionary(grouping: rejections, by: { $0.stage })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        List {
            Section("By stage") {
                if byStage.isEmpty {
                    Text("No rejections logged.").foregroundStyle(.secondary)
                }
                ForEach(byStage, id: \.0) { stage, count in
                    HStack {
                        StatusBadge(status: stage)
                        Spacer()
                        Text("\(count)").bold()
                    }
                }
            }
            Section("Log") {
                ForEach(rejections) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.application?.company?.name ?? "—").font(.headline)
                        if !r.reason.isEmpty { Text(r.reason).font(.subheadline) }
                        if !r.lessonsLearned.isEmpty {
                            Text("Lesson: \(r.lessonsLearned)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rejections")
    }
}

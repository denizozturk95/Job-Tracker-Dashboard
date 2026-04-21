import SwiftUI
import SwiftData

struct ApplicationEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let application: Application?

    @State private var companyName: String = ""
    @State private var role: String = ""
    @State private var location: String = ""
    @State private var remote: RemotePolicy = .onsite
    @State private var source: String = ""
    @State private var url: String = ""
    @State private var salaryMin: String = ""
    @State private var salaryMax: String = ""
    @State private var notes: String = ""
    @State private var status: ApplicationStatus = .saved
    @State private var priority: Int = 1
    @State private var appliedDate: Date = .now
    @State private var hasAppliedDate: Bool = false
    @State private var selectedTags: Set<String> = []
    @State private var newTagName: String = ""

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query private var allApplications: [Application]

    @State private var showingDuplicateAlert = false
    @State private var duplicateCandidate: Application?

    var body: some View {
        Form {
            Section("Company & Role") {
                TextField("Company", text: $companyName)
                TextField("Role", text: $role)
                TextField("Location", text: $location)
                Picker("Remote", selection: $remote) {
                    ForEach(RemotePolicy.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("Tracking") {
                Picker("Status", selection: $status) {
                    ForEach(ApplicationStatus.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Has applied date", isOn: $hasAppliedDate)
                if hasAppliedDate {
                    DatePicker("Applied on", selection: $appliedDate, displayedComponents: .date)
                }
                TextField("Source (LinkedIn, referral…)", text: $source)
                TextField("Posting URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Stepper("Priority: \(priority)", value: $priority, in: 0...3)
            }

            Section("Salary (EUR)") {
                HStack {
                    TextField("Min", text: $salaryMin).keyboardType(.decimalPad)
                    TextField("Max", text: $salaryMax).keyboardType(.decimalPad)
                }
            }

            Section("Tags") {
                ForEach(allTags) { tag in
                    Toggle(isOn: Binding(
                        get: { selectedTags.contains(tag.name) },
                        set: { isOn in
                            if isOn { selectedTags.insert(tag.name) } else { selectedTags.remove(tag.name) }
                        }
                    )) { Text(tag.name) }
                }
                HStack {
                    TextField("New tag", text: $newTagName)
                    Button("Add") {
                        let name = newTagName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let t = Tag(name: name)
                        context.insert(t)
                        selectedTags.insert(name)
                        newTagName = ""
                    }.disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes).frame(minHeight: 100)
            }
        }
        .navigationTitle(application == nil ? "New Application" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { attemptSave() }.disabled(role.isEmpty || companyName.isEmpty)
            }
        }
        .onAppear(perform: load)
        .alert("Possible duplicate", isPresented: $showingDuplicateAlert, presenting: duplicateCandidate) { _ in
            Button("Save anyway") { save() }
            Button("Cancel", role: .cancel) { }
        } message: { candidate in
            Text("You already have a \(candidate.role) application at \(candidate.company?.name ?? "?") from \(candidate.createdAt.formatted(date: .abbreviated, time: .omitted)). Save a second one?")
        }
    }

    /// Called by Save button. Runs duplicate check on NEW applications only.
    private func attemptSave() {
        if application == nil, let match = findDuplicate() {
            duplicateCandidate = match
            showingDuplicateAlert = true
            return
        }
        save()
    }

    private func findDuplicate() -> Application? {
        let targetCompany = companyName.trimmingCharacters(in: .whitespaces).lowercased()
        let targetRole = role.trimmingCharacters(in: .whitespaces).lowercased()
        guard !targetCompany.isEmpty, !targetRole.isEmpty else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        return allApplications.first { app in
            guard let name = app.company?.name.lowercased(), name == targetCompany else { return false }
            let roleLower = app.role.lowercased()
            guard roleLower == targetRole || roleLower.contains(targetRole) || targetRole.contains(roleLower) else {
                return false
            }
            return app.createdAt >= cutoff
        }
    }

    private func load() {
        guard let a = application else { return }
        companyName = a.company?.name ?? ""
        role = a.role
        location = a.location
        remote = a.remotePolicy
        source = a.source
        url = a.postingURL ?? ""
        salaryMin = a.salaryMin.map { String($0) } ?? ""
        salaryMax = a.salaryMax.map { String($0) } ?? ""
        notes = a.notes
        status = a.status
        priority = a.priority
        hasAppliedDate = a.appliedDate != nil
        appliedDate = a.appliedDate ?? .now
        selectedTags = Set(a.tags.map(\.name))
    }

    private func save() {
        let company = findOrCreateCompany(named: companyName)
        let tagObjects = resolveTags()

        if let a = application {
            a.company = company
            a.role = role
            a.location = location
            a.remotePolicy = remote
            a.source = source
            a.postingURL = url.isEmpty ? nil : url
            a.salaryMin = Double(salaryMin)
            a.salaryMax = Double(salaryMax)
            a.currency = "EUR"
            a.notes = notes
            a.priority = priority
            a.appliedDate = hasAppliedDate ? appliedDate : nil
            a.tags = tagObjects
            if a.status != status {
                a.updateStatus(status, in: context)
            }
        } else {
            let a = Application(
                role: role,
                company: company,
                location: location,
                remotePolicy: remote,
                source: source,
                postingURL: url.isEmpty ? nil : url,
                status: status,
                currency: "EUR",
                priority: priority,
                appliedDate: hasAppliedDate ? appliedDate : nil,
                notes: notes
            )
            a.salaryMin = Double(salaryMin)
            a.salaryMax = Double(salaryMax)
            a.tags = tagObjects
            context.insert(a)
            if status == .applied {
                NotificationService.shared.scheduleFollowUp(
                    applicationID: a.id,
                    company: company.name,
                    role: role
                )
            }
        }
        try? context.save()
        dismiss()
    }

    private func findOrCreateCompany(named raw: String) -> Company {
        let name = raw.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Company>(predicate: #Predicate { $0.name == name })
        if let existing = (try? context.fetch(descriptor))?.first { return existing }
        let c = Company(name: name)
        context.insert(c)
        return c
    }

    private func resolveTags() -> [Tag] {
        selectedTags.compactMap { name in
            if let existing = allTags.first(where: { $0.name == name }) { return existing }
            let new = Tag(name: name)
            context.insert(new)
            return new
        }
    }
}

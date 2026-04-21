import SwiftUI
import SwiftData

/// #13 — natural-language quick add.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var parsed: QuickAddParseResult = QuickAddParseResult()
    @State private var isIngesting = false

    var body: some View {
        Form {
            Section("Natural language") {
                TextEditor(text: $text).frame(minHeight: 80)
                    .onChange(of: text) { _, new in
                        parsed = QuickAddParser.parse(new)
                    }
                Text("Try: \"Apple iOS Engineer Munich applied today\" or paste a job URL.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Parsed") {
                row("Company", parsed.company)
                row("Role", parsed.role)
                row("Location", parsed.location)
                row("Date", parsed.date.map { $0.formatted(date: .abbreviated, time: .omitted) })
                row("Status", parsed.status.label)
                row("URL", parsed.url?.absoluteString)
            }
            if parsed.url != nil {
                Section {
                    Button {
                        Task { await ingestURL() }
                    } label: {
                        if isIngesting { ProgressView() } else { Text("Enrich from URL") }
                    }
                }
            }
        }
        .navigationTitle("Quick Add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled((parsed.role ?? "").isEmpty || (parsed.company ?? "").isEmpty)
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—").foregroundStyle(value == nil ? .secondary : .primary)
        }
    }

    private func save() {
        let companyName = parsed.company ?? "Unknown"
        let role = parsed.role ?? "Role"
        let company = findOrCreateCompany(named: companyName)
        let app = Application(
            role: role,
            company: company,
            location: parsed.location ?? "",
            source: parsed.url?.host ?? "",
            postingURL: parsed.url?.absoluteString,
            status: parsed.status,
            appliedDate: parsed.status == .applied ? (parsed.date ?? .now) : nil
        )
        context.insert(app)
        try? context.save()
        dismiss()
    }

    private func ingestURL() async {
        guard let url = parsed.url else { return }
        isIngesting = true
        let result = await URLIngestService.ingest(url: url)
        await MainActor.run {
            if parsed.company == nil { parsed.company = result.company }
            if parsed.role == nil { parsed.role = result.title }
            if parsed.location == nil { parsed.location = result.location }
            isIngesting = false
        }
    }

    private func findOrCreateCompany(named raw: String) -> Company {
        let name = raw.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Company>(predicate: #Predicate { $0.name == name })
        if let existing = (try? context.fetch(descriptor))?.first { return existing }
        let c = Company(name: name)
        context.insert(c)
        return c
    }
}

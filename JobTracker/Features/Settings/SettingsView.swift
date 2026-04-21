import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Library") {
                    NavigationLink { DocumentsListView() } label: { Label("Documents", systemImage: "doc.richtext") }
                    NavigationLink { ContactsListView() } label: { Label("Contacts", systemImage: "person.2") }
                    NavigationLink { RejectionPatternsView() } label: { Label("Rejections", systemImage: "exclamationmark.bubble") }
                    NavigationLink { ArchiveView() } label: { Label("Archive", systemImage: "archivebox") }
                }
                Section("Data") {
                    NavigationLink { ExportImportView() } label: { Label("Export / Import", systemImage: "square.and.arrow.up") }
                }
                Section("Automation") {
                    NavigationLink { ShortcutsHelpView() } label: { Label("Siri & Shortcuts", systemImage: "sparkle") }
                    NavigationLink { NotificationSettingsView() } label: { Label("Reminders", systemImage: "bell.badge") }
                }
                Section("About") {
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "hand.raised") }
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy").font(.largeTitle.bold())
                Text("JobTracker is built to be private by default.")
                    .font(.title3).foregroundStyle(.secondary)
                Group {
                    bullet("No account, no login — your iCloud account is the only identity.")
                    bullet("No analytics, no trackers, no ads. Ever.")
                    bullet("All data stays on your devices and in your private iCloud container.")
                    bullet("Network calls only happen when you explicitly ingest a URL.")
                    bullet("Delete the app and all local data is gone; remove it from iCloud and the sync copy is gone.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
    }

    private func bullet(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark.shield") }
    }
}

struct NotificationSettingsView: View {
    @State private var authorized = false

    var body: some View {
        Form {
            Section("Status") {
                Text(authorized ? "Notifications enabled" : "Notifications not authorized")
                    .foregroundStyle(authorized ? .green : .orange)
                Button("Request / Re-check") {
                    Task { authorized = await NotificationService.shared.requestAuthorizationIfNeeded() }
                }
            }
            Section("What we send") {
                Label("Follow-ups 7 days after applying", systemImage: "envelope.badge")
                Label("Thank-yous 1 day after interviews", systemImage: "heart.text.square")
                Label("1-hour interview reminders", systemImage: "clock")
                Label("Stalled / ghosting alerts", systemImage: "clock.arrow.circlepath")
                Label("Weekly Sunday digest", systemImage: "calendar.badge.clock")
            }
        }
        .navigationTitle("Reminders")
        .task {
            authorized = await NotificationService.shared.requestAuthorizationIfNeeded()
        }
    }
}

struct ShortcutsHelpView: View {
    var body: some View {
        List {
            Section("Try saying") {
                Text("\"Log an application in JobTracker\"").font(.body)
                Text("\"Next interview\"").font(.body)
                Text("\"Open JobTracker dashboard\"").font(.body)
            }
            Section("Quick Add URL scheme") {
                Text("jobtracker://quickadd?Apple%20iOS%20Engineer%20Munich%20applied%20today")
                    .font(.caption.monospaced())
            }
        }
        .navigationTitle("Siri & Shortcuts")
    }
}

struct ExportImportView: View {
    @Environment(\.modelContext) private var context
    @State private var csvOutput: String = ""
    @State private var showingShare = false
    @State private var showingImporter = false
    @State private var lastImportCount: Int?

    var body: some View {
        Form {
            Section("Export") {
                Button {
                    csvOutput = ExportService.exportCSV(context: context)
                    showingShare = true
                } label: { Label("Export CSV", systemImage: "doc.text") }

                Button {
                    if let data = try? ExportService.exportJSON(context: context),
                       let str = String(data: data, encoding: .utf8) {
                        csvOutput = str
                        showingShare = true
                    }
                } label: { Label("Export JSON", systemImage: "curlybraces") }
            }
            Section("Import") {
                Button {
                    showingImporter = true
                } label: { Label("Import CSV / JSON", systemImage: "square.and.arrow.down") }
                if let n = lastImportCount {
                    Text("Imported \(n) applications.").foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Export / Import")
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [csvOutput])
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            if url.pathExtension.lowercased() == "json" {
                lastImportCount = (try? ImportService.importJSON(data, into: context)) ?? 0
            } else {
                let csv = String(data: data, encoding: .utf8) ?? ""
                lastImportCount = ImportService.importCSV(csv, into: context)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

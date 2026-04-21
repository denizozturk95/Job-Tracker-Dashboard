import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CryptoKit
import QuickLook

/// #8 — resume / cover letter library.
struct DocumentsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Document.createdAt, order: .reverse)])
    private var documents: [Document]

    @State private var showingPicker = false
    @State private var pendingKind: DocumentKind = .resume
    @State private var versionName: String = "v1"
    @State private var previewingURL: URL?

    var body: some View {
        Group {
            if documents.isEmpty {
                EmptyStateView(
                    systemImage: "doc.richtext",
                    title: "No documents",
                    message: "Attach the resume and cover letter versions you send to companies.",
                    actionTitle: "Add Document",
                    action: { showingPicker = true }
                )
            } else {
                List {
                    ForEach(DocumentKind.allCases) { kind in
                        let items = documents.filter { $0.kind == kind }
                        if !items.isEmpty {
                            Section(kind.label) {
                                ForEach(items) { doc in
                                    Button {
                                        openPreview(doc)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(doc.filename).font(.headline).foregroundStyle(.primary)
                                                Text("Version: \(doc.version) · \(doc.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "eye").foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { indexSet in
                                    for i in indexSet { context.delete(items[i]) }
                                    try? context.save()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(DocumentKind.allCases) { k in
                        Button(k.label) { pendingKind = k; showingPicker = true }
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.pdf, .plainText, .rtf, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            ingest(url: url)
        }
        .sheet(item: Binding(
            get: { previewingURL.map { PreviewItem(url: $0) } },
            set: { previewingURL = $0?.url }
        )) { item in
            QuickLookPreview(url: item.url)
        }
    }

    private func openPreview(_ doc: Document) {
        guard let bookmark = doc.bookmarkData else { return }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
            previewingURL = url
        }
    }

    private struct PreviewItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func ingest(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try? url.bookmarkData()
        var sha = ""
        if let data = try? Data(contentsOf: url) {
            sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        let doc = Document(
            kind: pendingKind,
            version: versionName,
            filename: url.lastPathComponent,
            bookmarkData: bookmark,
            sha256: sha
        )
        context.insert(doc)
        try? context.save()
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

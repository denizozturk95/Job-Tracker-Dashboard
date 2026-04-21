import SwiftUI
import SwiftData

/// #5 — offline-first prep checklist for an interview.
struct PrepModeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var interview: Interview

    @State private var newItem: String = ""
    @State private var newKind: PrepItemKind = .research

    var body: some View {
        List {
            if interview.prepChecklist.isEmpty {
                Section {
                    Button("Insert starter checklist") { seedDefaults() }
                }
            }
            ForEach(PrepItemKind.allCases) { kind in
                let items = interview.prepChecklist.filter { $0.kind == kind }.sorted { $0.order < $1.order }
                if !items.isEmpty {
                    Section(kind.label) {
                        ForEach(items) { item in
                            Button {
                                item.done.toggle()
                                try? context.save()
                            } label: {
                                HStack {
                                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.done ? .green : .secondary)
                                    Text(item.title).strikethrough(item.done)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            Section("Add item") {
                Picker("Kind", selection: $newKind) {
                    ForEach(PrepItemKind.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    TextField("Title", text: $newItem)
                    Button("Add", action: addItem)
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Prep Mode")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    private func addItem() {
        let title = newItem.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let order = (interview.prepChecklist.filter { $0.kind == newKind }.map(\.order).max() ?? 0) + 1
        let item = PrepItem(title: title, kind: newKind, order: order)
        item.interview = interview
        context.insert(item)
        newItem = ""
        try? context.save()
    }

    private func seedDefaults() {
        let defaults: [(String, PrepItemKind)] = [
            ("Review the company's recent news", .research),
            ("Read the job description end-to-end", .research),
            ("Prepare a STAR story: biggest impact", .star),
            ("Prepare a STAR story: hardest bug", .star),
            ("Prepare a STAR story: conflict", .star),
            ("What does success look like in 6 months?", .question),
            ("How is the team structured?", .question),
            ("Confirm timezone and meeting link", .logistics),
            ("Charge headphones, quiet space", .logistics)
        ]
        for (i, pair) in defaults.enumerated() {
            let item = PrepItem(title: pair.0, kind: pair.1, order: i)
            item.interview = interview
            context.insert(item)
        }
        try? context.save()
    }
}

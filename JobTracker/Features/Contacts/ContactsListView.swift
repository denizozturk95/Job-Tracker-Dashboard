import SwiftUI
import SwiftData

struct ContactsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var showingNew = false

    var body: some View {
        Group {
            if contacts.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "No contacts",
                    message: "Keep recruiters and referrers close.",
                    actionTitle: "Add Contact",
                    action: { showingNew = true }
                )
            } else {
                List {
                    ForEach(contacts) { c in
                        NavigationLink(value: c) {
                            VStack(alignment: .leading) {
                                Text(c.name).font(.headline)
                                HStack {
                                    Text(c.contactRole.label).font(.caption).foregroundStyle(.secondary)
                                    if !c.companyName.isEmpty {
                                        Text("· \(c.companyName)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { context.delete(contacts[i]) }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingNew) {
            NavigationStack { ContactEditView(contact: nil) }
        }
        .navigationDestination(for: Contact.self) { ContactDetailView(contact: $0) }
    }
}

struct ContactDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var contact: Contact
    @State private var showingEdit = false

    var body: some View {
        List {
            Section(contact.name) {
                Label(contact.contactRole.label, systemImage: "person.text.rectangle")
                if !contact.companyName.isEmpty {
                    Label(contact.companyName, systemImage: "building.2")
                }
            }
            Section("Reach out") {
                if !contact.email.isEmpty, let url = URL(string: "mailto:\(contact.email)") {
                    Link(destination: url) { Label(contact.email, systemImage: "envelope") }
                }
                if !contact.phone.isEmpty, let url = URL(string: "tel://\(contact.phone.replacingOccurrences(of: " ", with: ""))") {
                    Link(destination: url) { Label(contact.phone, systemImage: "phone") }
                }
                if !contact.linkedIn.isEmpty, let url = URL(string: contact.linkedIn) {
                    Link(destination: url) { Label("LinkedIn", systemImage: "link") }
                }
            }
            Section("Last contacted") {
                if let date = contact.lastContactedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("Never").foregroundStyle(.secondary)
                }
                Button("Mark as contacted now") {
                    contact.lastContactedAt = .now
                    try? context.save()
                }
            }
            if !contact.notes.isEmpty {
                Section("Notes") { Text(contact.notes) }
            }
        }
        .navigationTitle(contact.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { ContactEditView(contact: contact) }
        }
    }
}

struct ContactEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let contact: Contact?

    @State private var name = ""
    @State private var role: ContactRole = .recruiter
    @State private var companyName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var linkedIn = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Role", selection: $role) {
                    ForEach(ContactRole.allCases) { Text($0.label).tag($0) }
                }
                TextField("Company", text: $companyName)
            }
            Section("Reach") {
                TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                TextField("LinkedIn URL", text: $linkedIn).textInputAutocapitalization(.never)
            }
            Section("Notes") { TextEditor(text: $notes).frame(minHeight: 80) }
        }
        .navigationTitle(contact == nil ? "New Contact" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.isEmpty) }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let c = contact else { return }
        name = c.name
        role = c.contactRole
        companyName = c.companyName
        email = c.email
        phone = c.phone
        linkedIn = c.linkedIn
        notes = c.notes
    }

    private func save() {
        if let c = contact {
            c.name = name
            c.contactRole = role
            c.companyName = companyName
            c.email = email
            c.phone = phone
            c.linkedIn = linkedIn
            c.notes = notes
        } else {
            let c = Contact(name: name, contactRole: role, companyName: companyName, email: email, phone: phone, linkedIn: linkedIn, notes: notes)
            context.insert(c)
        }
        try? context.save()
        dismiss()
    }
}

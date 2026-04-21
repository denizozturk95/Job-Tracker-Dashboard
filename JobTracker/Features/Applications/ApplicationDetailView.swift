import SwiftUI
import SwiftData

struct ApplicationDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var application: Application
    @State private var showingEdit = false
    @State private var showingNewInterview = false
    @State private var showingOfferSheet = false
    @State private var showingRejectionSheet = false

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(application.company?.name ?? "—").font(.title2.bold())
                        Text(application.role).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: application.status)
                }

                if !application.location.isEmpty || application.remotePolicy != .onsite {
                    Label("\(application.location) · \(application.remotePolicy.label)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
                if let url = application.postingURL, let parsed = URL(string: url) {
                    Link(destination: parsed) {
                        Label(url, systemImage: "link").lineLimit(1)
                    }
                }
            }

            Section("Status") {
                StatusPicker(current: application.status) { new in
                    application.updateStatus(new, in: context)
                    try? context.save()
                }
                .statusHaptics(trigger: application.status)
            }

            Section("Interviews") {
                if application.interviews.isEmpty {
                    Text("No interviews yet").foregroundStyle(.secondary)
                }
                ForEach(application.interviews.sorted(by: { $0.datetime < $1.datetime })) { iv in
                    NavigationLink(value: iv) {
                        VStack(alignment: .leading) {
                            Text("\(iv.type.label) · Round \(iv.round)").font(.headline)
                            Text(iv.datetime.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    showingNewInterview = true
                } label: {
                    Label("Add Interview", systemImage: "plus.circle")
                }
            }

            Section("Tags") {
                if application.tags.isEmpty {
                    Text("No tags").foregroundStyle(.secondary)
                } else {
                    HStack {
                        ForEach(application.tags) { tag in
                            Text(tag.name)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color(hex: tag.colorHex).opacity(0.2))
                                .foregroundStyle(Color(hex: tag.colorHex))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Section("Timeline") {
                ForEach(application.events.sorted(by: { $0.at > $1.at })) { event in
                    HStack {
                        Circle().fill(event.to.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text("\(event.from.label) → \(event.to.label)").font(.subheadline)
                            Text(event.at.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !application.notes.isEmpty {
                Section("Notes") { Text(application.notes) }
            }

            if let offer = application.offer {
                Section("Offer") {
                    Text("Base: € \(offer.base.formatted())")
                    if offer.bonus > 0 { Text("Bonus: € \(offer.bonus.formatted())") }
                    if offer.equity > 0 { Text("Equity: € \(offer.equity.formatted())") }
                    Text("Total: € \(offer.totalAnnual.formatted())").bold()
                }
            } else if application.status == .offer {
                Button("Record Offer") { showingOfferSheet = true }
            }

            if let rejection = application.rejection {
                Section("Rejection") {
                    if !rejection.reason.isEmpty { Text("Reason: \(rejection.reason)") }
                    if !rejection.feedback.isEmpty { Text("Feedback: \(rejection.feedback)") }
                    if !rejection.lessonsLearned.isEmpty { Text("Lessons: \(rejection.lessonsLearned)") }
                }
            } else if application.status == .rejected {
                Button("Log Rejection") { showingRejectionSheet = true }
            }

            Section {
                Button(role: .destructive) {
                    application.archived = true
                    try? context.save()
                } label: { Label("Archive", systemImage: "archivebox") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(application.company?.name ?? "Application")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { ApplicationEditView(application: application) }
        }
        .sheet(isPresented: $showingNewInterview) {
            NavigationStack { InterviewEditView(application: application, interview: nil) }
        }
        .sheet(isPresented: $showingOfferSheet) {
            NavigationStack { OfferEditView(application: application) }
        }
        .sheet(isPresented: $showingRejectionSheet) {
            NavigationStack { RejectionEditView(application: application) }
        }
        .navigationDestination(for: Interview.self) { InterviewDetailView(interview: $0) }
    }
}

struct StatusPicker: View {
    let current: ApplicationStatus
    let onChange: (ApplicationStatus) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(ApplicationStatus.allCases) { s in
                    Button { onChange(s) } label: {
                        Text(s.label)
                            .font(.caption.bold())
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(s == current ? s.color : Color.gray.opacity(0.15))
                            .foregroundStyle(s == current ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

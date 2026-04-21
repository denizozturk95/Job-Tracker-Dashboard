import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case saved, applied, screen, interview, offer, rejected, withdrawn, ghosted
    var id: String { rawValue }

    var label: String {
        switch self {
        case .saved: return "Saved"
        case .applied: return "Applied"
        case .screen: return "Screen"
        case .interview: return "Interview"
        case .offer: return "Offer"
        case .rejected: return "Rejected"
        case .withdrawn: return "Withdrawn"
        case .ghosted: return "Ghosted"
        }
    }

    var color: Color {
        switch self {
        case .saved: return .gray
        case .applied: return .blue
        case .screen: return .indigo
        case .interview: return .purple
        case .offer: return .green
        case .rejected: return .red
        case .withdrawn: return .orange
        case .ghosted: return .brown
        }
    }

    /// Ordering used by Kanban and the funnel.
    static let pipeline: [ApplicationStatus] = [.saved, .applied, .screen, .interview, .offer, .rejected]

    var isTerminal: Bool {
        self == .offer || self == .rejected || self == .withdrawn || self == .ghosted
    }

    /// Which haptic should fire when this status becomes current.
    var hapticFlavor: HapticFlavor {
        switch self {
        case .offer: return .success
        case .rejected: return .warning
        default: return .soft
        }
    }
}

enum HapticFlavor { case success, warning, soft }

enum InterviewType: String, Codable, CaseIterable, Identifiable {
    case phone, technical, onsite, behavioral, system, take_home, final
    var id: String { rawValue }
    var label: String {
        switch self {
        case .phone: return "Phone"
        case .technical: return "Technical"
        case .onsite: return "Onsite"
        case .behavioral: return "Behavioral"
        case .system: return "System Design"
        case .take_home: return "Take-home"
        case .final: return "Final"
        }
    }
}

enum InterviewOutcome: String, Codable, CaseIterable, Identifiable {
    case pending, passed, failed, cancelled
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum RemotePolicy: String, Codable, CaseIterable, Identifiable {
    case onsite, hybrid, remote
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case resume, coverLetter, portfolio, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .resume: return "Resume"
        case .coverLetter: return "Cover Letter"
        case .portfolio: return "Portfolio"
        case .other: return "Other"
        }
    }
}

enum PrepItemKind: String, Codable, CaseIterable, Identifiable {
    case star, research, question, logistics
    var id: String { rawValue }
    var label: String {
        switch self {
        case .star: return "STAR Story"
        case .research: return "Research"
        case .question: return "Question to Ask"
        case .logistics: return "Logistics"
        }
    }
}

enum ContactRole: String, Codable, CaseIterable, Identifiable {
    case recruiter, referrer, interviewer, hiringManager, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recruiter: return "Recruiter"
        case .referrer: return "Referrer"
        case .interviewer: return "Interviewer"
        case .hiringManager: return "Hiring Manager"
        case .other: return "Other"
        }
    }
}

// MARK: - Models

@Model
final class Company {
    @Attribute(.unique) var name: String
    var domain: String?
    var logoURL: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Application.company)
    var applications: [Application] = []

    init(name: String, domain: String? = nil, logoURL: String? = nil) {
        self.name = name
        self.domain = domain
        self.logoURL = logoURL
        self.createdAt = .now
    }
}

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String

    init(name: String, colorHex: String = "#3366FF") {
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class Application {
    var id: UUID
    var role: String
    var location: String
    var remotePolicy: RemotePolicy
    var source: String
    var postingURL: String?
    var salaryMin: Double?
    var salaryMax: Double?
    var currency: String
    var priority: Int   // 0..3
    var appliedDate: Date?
    var lastStatusChange: Date
    var notes: String
    var statusRaw: String
    var archived: Bool
    var createdAt: Date

    var company: Company?

    @Relationship(deleteRule: .cascade, inverse: \Interview.application)
    var interviews: [Interview] = []

    @Relationship(deleteRule: .cascade, inverse: \StatusEvent.application)
    var events: [StatusEvent] = []

    @Relationship(deleteRule: .nullify, inverse: \Contact.applications)
    var contacts: [Contact] = []

    @Relationship(deleteRule: .nullify, inverse: \Document.applications)
    var documents: [Document] = []

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \Offer.application)
    var offer: Offer?

    @Relationship(deleteRule: .cascade, inverse: \Rejection.application)
    var rejection: Rejection?

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }

    init(
        role: String,
        company: Company? = nil,
        location: String = "",
        remotePolicy: RemotePolicy = .onsite,
        source: String = "",
        postingURL: String? = nil,
        status: ApplicationStatus = .saved,
        currency: String = "EUR",
        priority: Int = 1,
        appliedDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.role = role
        self.company = company
        self.location = location
        self.remotePolicy = remotePolicy
        self.source = source
        self.postingURL = postingURL
        self.statusRaw = status.rawValue
        self.currency = currency
        self.priority = priority
        self.appliedDate = appliedDate
        self.notes = notes
        self.archived = false
        self.createdAt = .now
        self.lastStatusChange = .now
    }

    /// Single chokepoint for status changes. Writes audit event.
    func updateStatus(_ new: ApplicationStatus, note: String = "", in context: ModelContext) {
        guard new != status else { return }
        let event = StatusEvent(from: status, to: new, note: note)
        event.application = self
        context.insert(event)
        statusRaw = new.rawValue
        lastStatusChange = .now
        if new == .applied && appliedDate == nil { appliedDate = .now }
    }
}

@Model
final class StatusEvent {
    var id: UUID
    var fromRaw: String
    var toRaw: String
    var at: Date
    var note: String
    var application: Application?

    var from: ApplicationStatus { ApplicationStatus(rawValue: fromRaw) ?? .saved }
    var to: ApplicationStatus { ApplicationStatus(rawValue: toRaw) ?? .saved }

    init(from: ApplicationStatus, to: ApplicationStatus, note: String = "") {
        self.id = UUID()
        self.fromRaw = from.rawValue
        self.toRaw = to.rawValue
        self.at = .now
        self.note = note
    }
}

@Model
final class Interview {
    var id: UUID
    var round: Int
    var typeRaw: String
    var datetime: Date
    var durationMin: Int
    var location: String
    var joinURL: String?
    var interviewerNames: String
    var outcomeRaw: String
    var postNotes: String
    var eventKitIdentifier: String?
    var questionsToAsk: [String]
    var createdAt: Date

    var application: Application?

    @Relationship(deleteRule: .cascade, inverse: \PrepItem.interview)
    var prepChecklist: [PrepItem] = []

    var type: InterviewType {
        get { InterviewType(rawValue: typeRaw) ?? .phone }
        set { typeRaw = newValue.rawValue }
    }

    var outcome: InterviewOutcome {
        get { InterviewOutcome(rawValue: outcomeRaw) ?? .pending }
        set { outcomeRaw = newValue.rawValue }
    }

    init(
        round: Int = 1,
        type: InterviewType = .phone,
        datetime: Date,
        durationMin: Int = 45,
        location: String = "",
        joinURL: String? = nil,
        interviewerNames: String = "",
        outcome: InterviewOutcome = .pending,
        postNotes: String = "",
        questionsToAsk: [String] = []
    ) {
        self.id = UUID()
        self.round = round
        self.typeRaw = type.rawValue
        self.datetime = datetime
        self.durationMin = durationMin
        self.location = location
        self.joinURL = joinURL
        self.interviewerNames = interviewerNames
        self.outcomeRaw = outcome.rawValue
        self.postNotes = postNotes
        self.questionsToAsk = questionsToAsk
        self.createdAt = .now
    }
}

@Model
final class PrepItem {
    var id: UUID
    var title: String
    var done: Bool
    var kindRaw: String
    var order: Int
    var interview: Interview?

    var kind: PrepItemKind {
        get { PrepItemKind(rawValue: kindRaw) ?? .research }
        set { kindRaw = newValue.rawValue }
    }

    init(title: String, kind: PrepItemKind = .research, done: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.done = done
        self.kindRaw = kind.rawValue
        self.order = order
    }
}

@Model
final class Contact {
    var id: UUID
    var name: String
    var roleRaw: String
    var companyName: String
    var email: String
    var phone: String
    var linkedIn: String
    var lastContactedAt: Date?
    var notes: String
    var createdAt: Date

    var applications: [Application] = []

    var contactRole: ContactRole {
        get { ContactRole(rawValue: roleRaw) ?? .other }
        set { roleRaw = newValue.rawValue }
    }

    init(
        name: String,
        contactRole: ContactRole = .other,
        companyName: String = "",
        email: String = "",
        phone: String = "",
        linkedIn: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.roleRaw = contactRole.rawValue
        self.companyName = companyName
        self.email = email
        self.phone = phone
        self.linkedIn = linkedIn
        self.notes = notes
        self.createdAt = .now
    }
}

@Model
final class Document {
    var id: UUID
    var kindRaw: String
    var version: String
    var filename: String
    var bookmarkData: Data?
    var sha256: String
    var createdAt: Date

    var applications: [Application] = []

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: DocumentKind, version: String, filename: String, bookmarkData: Data? = nil, sha256: String = "") {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.version = version
        self.filename = filename
        self.bookmarkData = bookmarkData
        self.sha256 = sha256
        self.createdAt = .now
    }
}

@Model
final class Offer {
    var id: UUID
    var base: Double
    var bonus: Double
    var equity: Double
    var currency: String
    var benefits: String
    var deadline: Date?
    var createdAt: Date
    var application: Application?

    init(base: Double, bonus: Double = 0, equity: Double = 0, currency: String = "EUR", benefits: String = "", deadline: Date? = nil) {
        self.id = UUID()
        self.base = base
        self.bonus = bonus
        self.equity = equity
        self.currency = currency
        self.benefits = benefits
        self.deadline = deadline
        self.createdAt = .now
    }

    var totalAnnual: Double { base + bonus + equity }
}

@Model
final class Rejection {
    var id: UUID
    var reason: String
    var stageRaw: String
    var feedback: String
    var lessonsLearned: String
    var createdAt: Date
    var application: Application?

    var stage: ApplicationStatus {
        get { ApplicationStatus(rawValue: stageRaw) ?? .applied }
        set { stageRaw = newValue.rawValue }
    }

    init(reason: String = "", stage: ApplicationStatus = .applied, feedback: String = "", lessonsLearned: String = "") {
        self.id = UUID()
        self.reason = reason
        self.stageRaw = stage.rawValue
        self.feedback = feedback
        self.lessonsLearned = lessonsLearned
        self.createdAt = .now
    }
}

@Model
final class SavedFilter {
    @Attribute(.unique) var name: String
    var statusesRaw: [String]
    var tagNames: [String]
    var remoteOnly: Bool
    var createdAt: Date

    init(name: String, statuses: [ApplicationStatus] = [], tagNames: [String] = [], remoteOnly: Bool = false) {
        self.name = name
        self.statusesRaw = statuses.map(\.rawValue)
        self.tagNames = tagNames
        self.remoteOnly = remoteOnly
        self.createdAt = .now
    }

    var statuses: [ApplicationStatus] {
        statusesRaw.compactMap { ApplicationStatus(rawValue: $0) }
    }
}

// MARK: - Schema

enum AppSchema {
    static let all: [any PersistentModel.Type] = [
        Application.self,
        Company.self,
        Tag.self,
        Interview.self,
        PrepItem.self,
        StatusEvent.self,
        Contact.self,
        Document.self,
        Offer.self,
        Rejection.self,
        SavedFilter.self
    ]

    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(all)

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration("JobTrackerMemory", schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(
                schema: schema,
                url: sharedStoreURL(),
                cloudKitDatabase: .automatic
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration("JobTrackerFallback", schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// SwiftData store in the App Group container so widgets & the main app share it.
    private static func sharedStoreURL() -> URL {
        let fileName = "JobTracker.sqlite"
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            return group.appendingPathComponent(fileName)
        }
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return (appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent(fileName)
    }
}

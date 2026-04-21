import Foundation
import NaturalLanguage

/// NL-driven parser for #13 "Apple iOS Engineer Munich applied today".
struct QuickAddParseResult {
    var company: String?
    var role: String?
    var location: String?
    var date: Date?
    var status: ApplicationStatus = .saved
    var url: URL?
}

enum QuickAddParser {

    private static let statusKeywords: [(String, ApplicationStatus)] = [
        ("applied", .applied),
        ("saved", .saved),
        ("screen", .screen),
        ("phone screen", .screen),
        ("interview", .interview),
        ("onsite", .interview),
        ("offer", .offer),
        ("rejected", .rejected),
        ("rejection", .rejected),
        ("withdrew", .withdrawn),
        ("withdrawn", .withdrawn),
        ("ghosted", .ghosted)
    ]

    private static let roleKeywords = [
        "engineer", "developer", "designer", "manager", "scientist",
        "analyst", "architect", "researcher", "lead", "director",
        "intern", "consultant", "specialist", "pm"
    ]

    static func parse(_ raw: String) -> QuickAddParseResult {
        var result = QuickAddParseResult()
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return result }

        // URL detection
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = detector.firstMatch(in: text, range: range), let url = match.url {
                result.url = url
            }
        }

        // Status
        let lower = text.lowercased()
        for (keyword, status) in statusKeywords where lower.contains(keyword) {
            result.status = status
            break
        }

        // Date heuristics
        if let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = dataDetector.firstMatch(in: text, range: range), let date = match.date {
                result.date = date
            }
        }
        if result.date == nil {
            if lower.contains("today") { result.date = .now }
            else if lower.contains("yesterday") { result.date = Calendar.current.date(byAdding: .day, value: -1, to: .now) }
        }

        // Names & places via NLTagger
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var orgs: [String] = []
        var places: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag else { return true }
            let token = String(text[range])
            switch tag {
            case .organizationName: orgs.append(token)
            case .placeName: places.append(token)
            default: break
            }
            return true
        }
        result.company = orgs.first
        result.location = places.first

        // Role = first token whose lowercase matches a known role keyword
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if let idx = words.firstIndex(where: { roleKeywords.contains($0.lowercased()) }) {
            // Gather up to 3 surrounding tokens for the role phrase
            let start = max(0, idx - 2)
            let end = min(words.count, idx + 1)
            let phrase = words[start..<end].joined(separator: " ")
            result.role = phrase
        }

        return result
    }
}

import Foundation

/// OpenGraph scraper for #4 share-sheet ingestion.
/// Light, best-effort — returns whatever it can and leaves the rest to the user.
struct IngestedPosting {
    var title: String?
    var company: String?
    var location: String?
    var url: URL
}

enum URLIngestService {

    static func ingest(url: URL) async -> IngestedPosting {
        var result = IngestedPosting(url: url)
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return result }

        result.title = metaContent(in: html, property: "og:title")
                    ?? metaContent(in: html, name: "twitter:title")
                    ?? titleTag(in: html)

        result.company = metaContent(in: html, property: "og:site_name")
                      ?? inferCompanyFromHost(url)

        // Domain-specific hints
        if url.host?.contains("linkedin") == true {
            result.company = result.company ?? firstMatch(#"\"companyName\":\"([^\"]+)\""#, in: html)
            result.location = firstMatch(#"\"formattedLocation\":\"([^\"]+)\""#, in: html)
        }

        return result
    }

    private static func metaContent(in html: String, property: String) -> String? {
        firstMatch(#"<meta[^>]+property=["']"# + property + #"["'][^>]+content=["']([^"']+)["']"#, in: html)
    }

    private static func metaContent(in html: String, name: String) -> String? {
        firstMatch(#"<meta[^>]+name=["']"# + name + #"["'][^>]+content=["']([^"']+)["']"#, in: html)
    }

    private static func titleTag(in html: String) -> String? {
        firstMatch(#"<title>([^<]+)</title>"#, in: html)
    }

    private static func inferCompanyFromHost(_ url: URL) -> String? {
        guard let host = url.host else { return nil }
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        let candidate = parts[parts.count - 2]
        if ["linkedin", "indeed", "glassdoor", "lever", "greenhouse", "workday", "jobs"].contains(candidate.lowercased()) {
            return nil
        }
        return candidate.capitalized
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).decodingHTMLEntities
    }
}

private extension String {
    var decodingHTMLEntities: String {
        self.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

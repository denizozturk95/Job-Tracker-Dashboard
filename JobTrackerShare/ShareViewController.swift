import UIKit
import Social
import UniformTypeIdentifiers

/// #4 — Save to JobTracker from Safari / LinkedIn / any app that offers URL.
/// Stores a pending URL in UserDefaults; the main app consumes it on launch.
@objc(ShareViewController)
class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completeRequest()
            return
        }

        let urlType = UTType.url.identifier as String
        for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] (urlItem, _) in
                if let url = urlItem as? URL {
                    self?.persist(url: url, comment: self?.contentText ?? "")
                }
                self?.completeRequest()
            }
            return
        }

        completeRequest()
    }

    override func configurationItems() -> [Any]! { [] }

    private func persist(url: URL, comment: String) {
        // Group identifier hardcoded here to keep the share extension self-contained
        // (so it doesn't need to pull in Shared/ sources).
        let groupID = "group.com.deniz.jobtracker"
        let key = "pendingIngestURLs"
        let defaults = UserDefaults(suiteName: groupID) ?? .standard
        var pending = defaults.array(forKey: key) as? [[String: String]] ?? []
        pending.append([
            "url": url.absoluteString,
            "comment": comment,
            "timestamp": ISO8601DateFormatter().string(from: .now)
        ])
        defaults.set(pending, forKey: key)
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

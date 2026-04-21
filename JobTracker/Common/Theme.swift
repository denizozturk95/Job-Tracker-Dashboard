import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b: Double
        switch s.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.2; g = 0.4; b = 1.0
        }
        self.init(red: r, green: g, blue: b)
    }
}

struct Theme {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 14
}

struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(Theme.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).bold()
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Apply tiered feedback based on the status' hapticFlavor.
extension View {
    func statusHaptics(trigger status: ApplicationStatus) -> some View {
        self
            .sensoryFeedback(trigger: status) { _, new in
                switch new.hapticFlavor {
                case .success: return .success
                case .warning: return .warning
                case .soft:    return .impact(weight: .light)
                }
            }
    }
}

extension Date {
    var relativeShort: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: self, relativeTo: .now)
    }

    func startOfDay(in cal: Calendar = .current) -> Date { cal.startOfDay(for: self) }
}

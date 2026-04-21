import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool
    @State private var page = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if page == 2 {
                        Button("Get started") {
                            isPresented = false
                        }.bold()
                    } else {
                        Button("Skip") { isPresented = false }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if page > 0 {
                        Button("Back") { page -= 1 }
                    }
                }
            }
        }
    }

    private var page1: some View {
        OnboardingPage(
            systemImage: "tray.full",
            title: "Track every application",
            description: "Log jobs as you apply, watch each one move from Saved to Offer. Everything stays on your device."
        )
    }

    private var page2: some View {
        OnboardingPage(
            systemImage: "calendar.badge.clock",
            title: "Never miss an interview",
            description: "Interviews sync to your calendar, show up in widgets, and get you prep reminders an hour ahead."
        )
    }

    private var page3: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.purple)
            Text("Want sample data?").font(.title2.bold())
            Text("Try the app with a few fake applications. You can delete them any time from the list.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                SampleData.seed(into: context)
                isPresented = false
            } label: {
                Label("Load sample data", systemImage: "wand.and.stars")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            Button("No thanks") { isPresented = false }
            Spacer()
        }.padding()
    }
}

struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(.blue.gradient)
            Text(title).font(.largeTitle.bold())
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Spacer()
        }
    }
}

/// Seed data so the dashboard isn't empty on first run.
enum SampleData {
    @MainActor
    static func seed(into context: ModelContext) {
        let apple = Company(name: "Apple")
        let stripe = Company(name: "Stripe")
        let vercel = Company(name: "Vercel")
        [apple, stripe, vercel].forEach { context.insert($0) }

        let now = Date.now
        let cal = Calendar.current

        let a1 = Application(
            role: "iOS Engineer", company: apple, location: "Munich",
            remotePolicy: .hybrid, source: "LinkedIn",
            status: .interview,
            appliedDate: cal.date(byAdding: .day, value: -18, to: now)
        )
        a1.priority = 3

        let a2 = Application(
            role: "Senior Swift Engineer", company: stripe, location: "Remote",
            remotePolicy: .remote, source: "Referral",
            status: .applied,
            appliedDate: cal.date(byAdding: .day, value: -5, to: now)
        )

        let a3 = Application(
            role: "Frontend Engineer", company: vercel, location: "Berlin",
            remotePolicy: .remote, source: "Direct",
            status: .saved
        )

        [a1, a2, a3].forEach { context.insert($0) }

        // Fake status history for the funnel chart
        for (app, sequence) in [
            (a1, [ApplicationStatus.saved, .applied, .screen, .interview]),
            (a2, [ApplicationStatus.saved, .applied])
        ] {
            var day = -25
            for status in sequence.dropFirst() {
                let event = StatusEvent(from: .saved, to: status)
                event.at = cal.date(byAdding: .day, value: day, to: now) ?? now
                event.application = app
                context.insert(event)
                day += 5
            }
        }

        // Upcoming interview with Apple tomorrow at 10:00
        let ivStart = cal.date(
            bySettingHour: 10, minute: 0, second: 0,
            of: cal.date(byAdding: .day, value: 1, to: now) ?? now
        ) ?? now
        let iv = Interview(
            round: 2, type: .technical, datetime: ivStart,
            durationMin: 60, location: "Zoom",
            joinURL: "https://zoom.us/j/example",
            interviewerNames: "Jane Doe"
        )
        iv.application = a1
        context.insert(iv)

        try? context.save()
    }
}

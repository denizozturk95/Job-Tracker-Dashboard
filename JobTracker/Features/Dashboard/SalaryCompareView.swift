import SwiftUI
import SwiftData
import Charts

/// #10 — compare logged offers side by side.
struct SalaryCompareView: View {
    @Query(sort: [SortDescriptor(\Offer.createdAt, order: .reverse)])
    private var offers: [Offer]

    var body: some View {
        SectionCard {
            Text("Offers").font(.headline)
            if offers.isEmpty {
                Text("No offers logged yet.").foregroundStyle(.secondary)
            } else {
                Chart(offers) { offer in
                    BarMark(
                        x: .value("Company", offer.application?.company?.name ?? "?"),
                        y: .value("Base", offer.base)
                    )
                    .foregroundStyle(by: .value("Type", "Base"))
                    BarMark(
                        x: .value("Company", offer.application?.company?.name ?? "?"),
                        y: .value("Bonus", offer.bonus)
                    )
                    .foregroundStyle(by: .value("Type", "Bonus"))
                    BarMark(
                        x: .value("Company", offer.application?.company?.name ?? "?"),
                        y: .value("Equity", offer.equity)
                    )
                    .foregroundStyle(by: .value("Type", "Equity"))
                }
                .frame(height: 200)

                ForEach(offers) { offer in
                    HStack {
                        Text(offer.application?.company?.name ?? "—").bold()
                        Spacer()
                        Text("€ \(offer.totalAnnual.formatted())")
                            .font(.caption.bold())
                    }
                }
            }
        }
    }
}

struct OfferEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let application: Application

    @State private var base: String = ""
    @State private var bonus: String = ""
    @State private var equity: String = ""
    @State private var benefits: String = ""
    @State private var hasDeadline = false
    @State private var deadline: Date = .now.addingTimeInterval(7 * 86_400)

    var body: some View {
        Form {
            Section("Compensation (EUR)") {
                TextField("Base", text: $base).keyboardType(.decimalPad)
                TextField("Bonus", text: $bonus).keyboardType(.decimalPad)
                TextField("Equity (annualized)", text: $equity).keyboardType(.decimalPad)
            }
            Section("Benefits") {
                TextEditor(text: $benefits).frame(minHeight: 80)
            }
            Section {
                Toggle("Has deadline", isOn: $hasDeadline)
                if hasDeadline { DatePicker("Deadline", selection: $deadline, displayedComponents: .date) }
            }
        }
        .navigationTitle("Offer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .onAppear {
            if let o = application.offer {
                base = String(o.base)
                bonus = String(o.bonus)
                equity = String(o.equity)
                benefits = o.benefits
                hasDeadline = o.deadline != nil
                deadline = o.deadline ?? .now
            }
        }
    }

    private func save() {
        let b = Double(base) ?? 0
        let bn = Double(bonus) ?? 0
        let eq = Double(equity) ?? 0
        let resolvedDeadline: Date? = hasDeadline ? deadline : nil
        let companyName = application.company?.name ?? "the company"

        let offer: Offer
        if let existing = application.offer {
            existing.base = b
            existing.bonus = bn
            existing.equity = eq
            existing.currency = "EUR"
            existing.benefits = benefits
            existing.deadline = resolvedDeadline
            offer = existing
        } else {
            let new = Offer(base: b, bonus: bn, equity: eq, currency: "EUR", benefits: benefits, deadline: resolvedDeadline)
            new.application = application
            application.offer = new
            context.insert(new)
            offer = new
        }

        // Countdown reminders — clears old ones first, so changing the deadline re-schedules.
        NotificationService.shared.cancelOfferDeadline(offerID: offer.id)
        if let due = resolvedDeadline, due > .now {
            NotificationService.shared.scheduleOfferDeadline(
                offerID: offer.id, company: companyName, deadline: due
            )
        }

        application.updateStatus(.offer, in: context)
        try? context.save()
        dismiss()
    }
}

import SwiftUI
import Charts

// The charger's own energy counter against what this server logged, month by
// month. The charger counts everything it ever delivered, so a month where
// the two disagree is a month the logger missed something.
struct LifetimeHistoryView: View {
    let api: any WCLApi

    @State private var months: [MonthComparison] = []
    @State private var error: String?
    @State private var loaded = false

    struct MonthComparison: Identifiable {
        let month: Date
        let charger: Double?
        let logged: Double
        var id: Date { month }
        var gap: Double? { charger.map { $0 - logged } }
        var title: String { month.formatted(.dateTime.month(.abbreviated).year()) }
        // The chart squeezes twelve of these side by side; the table has room for the year.
        var short: String { month.formatted(.dateTime.month(.abbreviated)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !months.isEmpty {
                    Card(title: "Delivered vs logged") {
                        Chart {
                            ForEach(months) { m in
                                if let charger = m.charger {
                                    BarMark(x: .value("Month" as String, m.short),
                                            y: .value("kWh" as String, charger / 1000))
                                        .foregroundStyle(by: .value("Source" as String, "Charger"))
                                        .position(by: .value("Source" as String, "Charger"))
                                }
                                BarMark(x: .value("Month" as String, m.short),
                                        y: .value("kWh" as String, m.logged / 1000))
                                    .foregroundStyle(by: .value("Source" as String, "Logged here"))
                                    .position(by: .value("Source" as String, "Logged here"))
                            }
                        }
                        .chartForegroundStyleScale(["Charger": Color.orange, "Logged here": Color.green])
                        .chartYAxisLabel("kWh")
                        .chartLegend(position: .bottom, spacing: 8)
                        .frame(height: 180)
                    }
                    Card(title: "By month") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Month").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Charger").frame(width: 76, alignment: .trailing)
                                Text("Logged").frame(width: 76, alignment: .trailing)
                                Text("Gap").frame(width: 70, alignment: .trailing)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            ForEach(months.reversed()) { m in
                                HStack {
                                    Text(verbatim: m.title).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(verbatim: m.charger.map { Fmt.kwh($0) } ?? "–").frame(width: 76, alignment: .trailing)
                                    Text(verbatim: Fmt.kwh(m.logged)).frame(width: 76, alignment: .trailing)
                                    Text(verbatim: m.gap.map { Fmt.kwh($0) } ?? "–")
                                        .frame(width: 70, alignment: .trailing)
                                        .foregroundStyle((m.gap ?? 0) > 1000 ? .orange : .secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    Text("The charger's counter is read once a day, so a month needs a reading at its end and at the end of the month before to be compared. A gap is energy the charger delivered while the logger was not running.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let error {
                    ErrorCard(message: error) { Task { await load() } }
                } else if loaded {
                    ContentUnavailableView("Not enough readings yet", systemImage: "chart.bar",
                                           description: Text("The comparison needs the charger's counter from at least two months."))
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lifetime")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            async let rows = api.lifetime(days: 366)
            async let sessions = api.sessions()
            months = Self.compare(rows: try await rows, sessions: try await sessions)
            error = nil
        } catch {
            if months.isEmpty { self.error = error.localizedDescription }
        }
        loaded = true
    }

    // The last reading of each month is the counter at month end; a month's
    // delivery is that minus the previous month's. Logged energy is the sum
    // of the sessions that started in the month. The server takes its daily
    // reading at the end of the UTC day, so months are UTC months here for
    // both sides: what matters is that the two sums cover the same span.
    static func compare(rows: [LifetimeRow], sessions: [ChargeSession]) -> [MonthComparison] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        func monthOf(_ date: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: date))! }
        var counterAtEnd: [Date: Double] = [:]
        for row in rows.sorted(by: { $0.ts < $1.ts }) {
            if let wh = row.energyWh { counterAtEnd[monthOf(row.date)] = wh }
        }
        var logged: [Date: Double] = [:]
        for s in sessions where !s.open {
            logged[monthOf(s.started), default: 0] += s.energyWh ?? 0
        }
        let months = Set(counterAtEnd.keys).union(logged.keys).sorted()
        return months.compactMap { month in
            let previous = cal.date(byAdding: .month, value: -1, to: month)!
            let charger: Double? = {
                guard let end = counterAtEnd[month], let start = counterAtEnd[previous] else { return nil }
                return max(0, end - start)
            }()
            let sum = logged[month] ?? 0
            guard charger != nil || sum > 0 else { return nil }
            return MonthComparison(month: month, charger: charger, logged: sum)
        }
    }
}

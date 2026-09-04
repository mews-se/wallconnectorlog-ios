import SwiftUI
import Charts

struct StatsView: View {
    let api: any WCLApi

    @AppStorage("pricePerKwh") private var pricePerKwh = 0.0
    @AppStorage("statsPeriod") private var periodRaw = SessionStats.Period.month.rawValue
    @State private var sessions: [ChargeSession] = []
    @State private var error: String?
    @State private var loaded = false

    private var period: SessionStats.Period { SessionStats.Period(rawValue: periodRaw) ?? .month }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !sessions.isEmpty {
                    let stats = SessionStats(sessions: sessions, now: Date())
                    VStack(spacing: 12) {
                        Picker("Period", selection: $periodRaw) {
                            ForEach(SessionStats.Period.allCases) { p in
                                Text(verbatim: p.label).tag(p.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        totals(stats.totals(period))
                        Card(title: "Energy per day, last 30 days") {
                            EnergyBars(points: stats.perDay(days: 30).map { ($0.day, $0.energyWh) }, unit: .day)
                                .frame(height: 150)
                        }
                        Card(title: "Energy per month, last 12 months") {
                            EnergyBars(points: stats.perMonth(months: 12).map { ($0.month, $0.energyWh) }, unit: .month)
                                .frame(height: 150)
                        }
                        records(stats)
                    }
                    .padding(.horizontal)
                } else if let error {
                    ErrorCard(message: error) { Task { await load() } }
                } else if loaded {
                    ContentUnavailableView("No sessions yet", systemImage: "chart.bar",
                                           description: Text("Statistics appear after the first charge with the logger running."))
                } else {
                    ProgressView().padding(.top, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func totals(_ t: SessionStats.Totals) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "bolt.fill", title: "Energy", value: Fmt.kwh(t.energyWh), tint: .green, valueTint: .green,
                     detail: pricePerKwh > 0 ? Fmt.money(t.energyWh / 1000 * pricePerKwh) : nil)
            StatTile(icon: "list.number", title: "Sessions", value: Fmt.count(t.count), tint: .secondary)
            StatTile(icon: "bolt.badge.clock", title: "Charging time", value: Fmt.wholeHours(t.chargingS), tint: .green)
            StatTile(icon: "gauge.with.dots.needle.67percent", title: "Average power",
                     value: Fmt.kw(t.averagePowerW), tint: .orange)
        }
    }

    private func records(_ stats: SessionStats) -> some View {
        let all = stats.totals(.all)
        return Card(title: "Records and averages") {
            VStack(spacing: 8) {
                if let s = stats.largest {
                    CardRow(title: "Largest session", value: "\(Fmt.kwh(s.energyWh)) · \(Fmt.day(s.started))")
                }
                if let s = stats.longestCharge {
                    CardRow(title: "Longest charge", value: "\(Fmt.duration(s.chargeS)) · \(Fmt.day(s.started))")
                }
                if let s = stats.strongest {
                    CardRow(title: "Highest power", value: "\(Fmt.kw(s.peakPowerW)) · \(Fmt.day(s.started))")
                }
                CardRow(title: "Average charging power", value: Fmt.kw(all.averagePowerW))
                CardRow(title: "Plugged in but idle",
                        value: all.idleShare.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–")
                CardRow(title: "All time", value: "\(Fmt.kwh(all.energyWh)) · \(Fmt.count(all.count)) sessions")
            }
        }
    }

    private func load() async {
        do {
            sessions = try await api.sessions()
            error = nil
        } catch {
            if sessions.isEmpty { self.error = error.localizedDescription }
        }
        loaded = true
    }
}

private struct EnergyBars: View {
    let points: [(Date, Double)]
    let unit: Calendar.Component

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            BarMark(
                x: .value("When" as String, point.0, unit: unit),
                y: .value("kWh" as String, point.1 / 1000)
            )
            .foregroundStyle(.green)
        }
        .chartYAxisLabel("kWh")
    }
}

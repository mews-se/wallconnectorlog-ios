import SwiftUI
import Charts

struct SessionsView: View {
    let api: any WCLApi

    @State private var sessions: [ChargeSession] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !sessions.isEmpty {
                    List {
                        ForEach(grouped) { group in
                            Section {
                                ForEach(group.rows) { session in
                                    NavigationLink(value: session) {
                                        SessionRow(session: session)
                                    }
                                }
                            } header: {
                                // The month's total sits in the header, so the
                                // list doubles as a monthly summary.
                                HStack {
                                    Text(verbatim: group.title)
                                    Spacer()
                                    if let total = group.totalWh {
                                        Text(verbatim: Fmt.kwh(total))
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: ChargeSession.self) { session in
                        SessionDetailView(api: api, session: session)
                    }
                } else if let error {
                    ErrorCard(message: error) { Task { await load() } }
                } else if loaded {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "bolt.slash",
                        description: Text("Sessions appear after the first charge with the logger running.")
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: SessionsCSV(sessions: sessions), preview: sharePreview) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(sessions.isEmpty)
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private var sharePreview: SharePreview<Image, Never> {
        let icon = AppIcon.image.map(Image.init(uiImage:)) ?? Image(systemName: "bolt.fill")
        return SharePreview("WallConnectorLog sessions", image: icon)
    }

    struct MonthGroup: Identifiable {
        let title: String
        let rows: [ChargeSession]
        // nil for the open session's own group - its energy is still growing
        var totalWh: Double? {
            rows.contains(where: \.open) ? nil : rows.reduce(0) { $0 + ($1.energyWh ?? 0) }
        }
        var id: String { title }
    }

    // Newest first from the server; group into month sections for scanning.
    private var grouped: [MonthGroup] {
        var order: [String] = []
        var buckets: [String: [ChargeSession]] = [:]
        for session in sessions {
            let key = session.open
                ? "In progress"
                : session.started.formatted(.dateTime.month(.wide).year())
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(session)
        }
        return order.map { MonthGroup(title: $0, rows: buckets[$0] ?? []) }
    }

    private func load() async {
        do {
            sessions = try await api.sessions()
            error = nil
        } catch {
            if sessions.isEmpty {
                self.error = "Could not reach the server.\n\(error.localizedDescription)"
            }
        }
        loaded = true
    }
}

private struct SessionRow: View {
    let session: ChargeSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if session.open {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Text(verbatim: Fmt.day(session.started))
                }
                Text(verbatim: Fmt.timeRange(session.started, session.ended))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: Fmt.kwh(session.energyWh))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                Text(verbatim: Fmt.duration(session.durationS))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SessionDetailView: View {
    let api: any WCLApi
    let session: ChargeSession

    @AppStorage("pricePerKwh") private var pricePerKwh = 0.0
    @State private var curve: [HistoryPoint] = []

    // Plugged in without drawing current: what is left of the plugged-in time
    // once the charging time is taken out, and how big a part of it that is.
    private var idleS: Int? {
        guard let plugged = session.durationS, let charging = session.chargeS else { return nil }
        return max(0, plugged - charging)
    }

    private var idleShare: String {
        guard let idle = idleS, let plugged = session.durationS, plugged > 0 else { return "–" }
        return (Double(idle) / Double(plugged)).formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    StatTile(icon: "bolt.fill", title: "Energy",
                             value: Fmt.kwh(session.energyWh), tint: .green, valueTint: .green,
                             detail: pricePerKwh > 0 ? Fmt.money((session.energyWh ?? 0) / 1000 * pricePerKwh) : nil)
                    StatTile(icon: "clock", title: "Plugged in",
                             value: Fmt.duration(session.durationS), tint: .secondary)
                    StatTile(icon: "bolt.badge.clock", title: "Charging",
                             value: Fmt.duration(session.chargeS), tint: .green)
                    StatTile(icon: "clock.badge.xmark", title: "Idle",
                             value: Fmt.duration(idleS), tint: .secondary)
                    StatTile(icon: "chart.pie", title: "Idle share",
                             value: idleShare, tint: .secondary)
                    StatTile(icon: "gauge.with.dots.needle.67percent", title: "Peak power",
                             value: Fmt.kw(session.peakPowerW), tint: .orange)
                    StatTile(icon: "thermometer.medium", title: "Peak handle",
                             value: Fmt.temp(session.peakHandleC), tint: .teal)
                    StatTile(icon: "bolt.horizontal.fill", title: "Grid average",
                             value: Fmt.volts(session.avgGridV), tint: .indigo)
                }
                if curve.count > 1 {
                    Card(title: "Power") {
                        PowerChart(points: curve)
                            .frame(height: 150)
                    }
                    Card(title: "Temperature") {
                        TemperatureChart(points: curve)
                            .frame(height: 150)
                    }
                    if curve.contains(where: { $0.ampA != nil }) {
                        Card(title: "Phase currents") {
                            PhaseChart(points: curve)
                                .frame(height: 150)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Fmt.day(session.started))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCurve() }
    }

    // Server 1.2 serves every stored sample of a session, phases included. An
    // older server has only the rolling history, which reaches back from now,
    // so there the curve is limited to recent sessions instead of pulling
    // weeks of samples.
    private func loadCurve() async {
        if let points = try? await api.sessionSamples(id: session.id) {
            curve = points
            return
        }
        let age = Int(Date().timeIntervalSince1970) - session.startedAt
        let hours = age / 3600 + 1
        guard hours <= 48 else { return }
        guard let points = try? await api.history(hours: hours) else { return }
        let end = session.endedAt ?? Int(Date().timeIntervalSince1970)
        curve = points.filter { $0.ts >= session.startedAt - 60 && $0.ts <= end + 60 }
    }
}

// The three sensors the charger reports, on the same time axis as the power
// curve so a warm handle can be read against the load that caused it.
struct TemperatureChart: View {
    let points: [HistoryPoint]

    private static let sensors: [(name: String, key: KeyPath<HistoryPoint, Double?>, color: Color)] = [
        ("Handle", \.handleC, .teal),
        ("PCBA", \.pcbaC, .orange),
        ("MCU", \.mcuC, .pink),
    ]

    var body: some View {
        let slim = points.decimated(to: 500)
        Chart {
            ForEach(Self.sensors, id: \.name) { sensor in
                ForEach(slim, id: \.ts) { point in
                    if let value = point[keyPath: sensor.key] {
                        LineMark(
                            x: .value("Time" as String, point.date),
                            y: .value("°C" as String, value),
                            series: .value("Sensor" as String, sensor.name)
                        )
                        .foregroundStyle(by: .value("Sensor" as String, sensor.name))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: Self.sensors.map(\.name), range: Self.sensors.map(\.color))
        // Temperatures move within a narrow band; anchoring the axis at zero
        // would flatten every curve into a line.
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel("°C")
        .chartLegend(position: .bottom, spacing: 8)
    }
}

// The current on each phase, so a single-phase charge is told apart from a
// three-phase one at a glance.
struct PhaseChart: View {
    let points: [HistoryPoint]

    private static let phases: [(name: String, key: KeyPath<HistoryPoint, Double?>, color: Color)] = [
        ("Phase A", \.ampA, .cyan),
        ("Phase B", \.ampB, .orange),
        ("Phase C", \.ampC, .purple),
    ]

    var body: some View {
        let slim = points.decimated(to: 500)
        Chart {
            ForEach(Self.phases, id: \.name) { phase in
                ForEach(slim, id: \.ts) { point in
                    if let value = point[keyPath: phase.key] {
                        LineMark(
                            x: .value("Time" as String, point.date),
                            y: .value("A" as String, value),
                            series: .value("Phase" as String, phase.name)
                        )
                        .foregroundStyle(by: .value("Phase" as String, phase.name))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: Self.phases.map(\.name), range: Self.phases.map(\.color))
        .chartYAxisLabel("A")
        .chartLegend(position: .bottom, spacing: 8)
    }
}

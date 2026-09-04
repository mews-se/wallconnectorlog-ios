import SwiftUI
import Charts

struct OverviewView: View {
    let api: any WCLApi

    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("grafanaURL") private var grafanaURL = ""
    // The power chart's window, remembered between launches.
    @AppStorage("chartHours") private var chartHours = ChartRange.day.rawValue
    @State private var live: Live?
    @State private var history: [HistoryPoint] = []
    @State private var error: String?
    // whether the last refresh reached the server - the cards keep the last
    // answer either way, so this is the only place a lost connection shows
    @State private var reachable = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if let live {
                    VStack(spacing: 12) {
                        FlowCard(live: live)
                        if !reachable {
                            Label("Server unreachable — showing the last answer", systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } else if live.ok == false {
                            Label("The server cannot reach the charger right now", systemImage: "antenna.radiowaves.left.and.right.slash")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } else if let ts = live.ts, Int(Date().timeIntervalSince1970) - ts > 180 {
                            Label("Last reading \(Fmt.age(Int(Date().timeIntervalSince1970) - ts)) old — has the logger stopped?", systemImage: "clock.badge.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        tiles(live)
                        PowerChartCard(points: history, hours: $chartHours)
                            .onChange(of: chartHours) { Task { await loadHistory() } }
                        GridQualityCard(points: history)
                        if let lt = live.lifetime {
                            LifetimeCard(lifetime: lt, api: api)
                        }
                        if !api.isDemo,
                           let grafana = Server.grafanaURL(setting: grafanaURL, server: serverURL, live: live) {
                            Link(destination: grafana) {
                                Label("Graphs in Grafana", systemImage: "chart.xyaxis.line")
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.top, 4)
                        }
                        chargerFooter(live)
                    }
                    .padding(.horizontal)
                } else if let error {
                    ErrorCard(message: error) { Task { await load() } }
                } else {
                    ProgressView().padding(.top, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .refreshable { await load() }
            .task {
                while !Task.isCancelled {
                    await load()
                    let interval: Double = live?.charging == true ? 5 : 15
                    try? await Task.sleep(for: .seconds(interval))
                }
            }
        }
    }

    private func tiles(_ live: Live) -> some View {
        let v = live.vitals
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(
                icon: "waveform.path.ecg",
                title: "Phase current",
                value: phaseTriple(v?.currentA, v?.currentB, v?.currentC, suffix: "A"),
                tint: live.charging ? .green : .secondary
            )
            StatTile(
                icon: "bolt.horizontal.fill",
                title: "Phase voltage",
                value: phaseTriple(v?.voltageA, v?.voltageB, v?.voltageC, suffix: "V", decimals: 0),
                tint: .blue
            )
            StatTile(
                icon: "thermometer.medium",
                title: "Handle",
                value: Fmt.temp(v?.handleTempC),
                tint: .teal
            )
            StatTile(
                icon: "cpu",
                title: "PCBA / MCU",
                value: "\(Fmt.temp(v?.pcbaTempC)) / \(Fmt.temp(v?.mcuTempC))",
                tint: .teal
            )
            NavigationLink {
                WifiHistoryView(api: api)
            } label: {
                StatTile(
                    icon: "wifi",
                    title: live.deviceText("wifi_ssid") ?? "Wi-Fi",
                    value: live.deviceNumber("wifi_rssi").map { "\(Int($0)) dBm" } ?? "–",
                    tint: wifiTint(live.deviceNumber("wifi_rssi"))
                )
            }
            .buttonStyle(.plain)
            StatTile(
                icon: "powerplug.fill",
                title: "Grid",
                value: "\(Fmt.volts(v?.gridV)) · \(Fmt.hz(v?.gridHz))",
                tint: .indigo
            )
        }
    }

    private func phaseTriple(_ a: Double?, _ b: Double?, _ c: Double?, suffix: String, decimals: Int = 1) -> String {
        let parts = [a, b, c].map { value in
            value.map { $0.formatted(.number.precision(.fractionLength(decimals))) } ?? "–"
        }
        return parts.joined(separator: " / ") + " " + suffix
    }

    private func wifiTint(_ rssi: Double?) -> Color {
        guard let rssi else { return .secondary }
        if rssi > -67 { return .green }
        if rssi > -75 { return .orange }
        return .red
    }

    private func chargerFooter(_ live: Live) -> some View {
        let parts = [
            live.deviceText("firmware_version").map { "Firmware \($0)" },
            live.deviceText("part_number"),
            live.deviceText("serial_number"),
        ].compactMap(\.self)
        return Text(verbatim: parts.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }

    private func load() async {
        do {
            let fresh = try await api.live()
            async let points = api.history(hours: chartHours)
            live = fresh
            history = (try? await points) ?? history
            reachable = true
            error = nil
        } catch {
            reachable = false
            if live == nil {
                self.error = "Could not reach the server.\n\(error.localizedDescription)"
            }
        }
    }

    // Only the chart window changed; the live card keeps its own cadence.
    private func loadHistory() async {
        if let points = try? await api.history(hours: chartHours) {
            history = points
        }
    }
}

// The Wall Monitor-style flow: grid, charger and car in a vertical line that
// lights up green where energy is moving.
private struct FlowCard: View {
    let live: Live

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label {
                    Text(verbatim: "\(Fmt.volts(live.vitals?.gridV)) · \(Fmt.hz(live.vitals?.gridHz))")
                } icon: {
                    Image(systemName: "bolt.horizontal.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                Spacer()
                stateChip
            }
            VStack(spacing: 0) {
                FlowLine(active: true, height: 20)
                ChargerGlyph(charging: live.charging)
                FlowLine(active: live.charging, height: 26)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(carColor)
            }
            if live.charging {
                Text(verbatim: Fmt.kw(live.powerW))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                if let phases = phaseSummary {
                    Text(verbatim: phases)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: live.evseStateText ?? "–")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let session = live.openSession {
                Text(verbatim: "Session · \(Fmt.kwh(session.energyWh)) · \(Fmt.duration(session.durationS))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var stateChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(live.charging ? Color.green : live.connected ? .yellow : Color(.systemGray3))
                .frame(width: 8, height: 8)
            Text(verbatim: live.evseStateText ?? "Unknown")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
    }

    // How many phases carry current and how much: "3 phases · 16 A" during a
    // three-phase charge, "1 phase · 15 A" when the car pulls single-phase.
    // Idle phases read a few tenths of an amp of noise, hence the 1 A floor.
    private var phaseSummary: String? {
        guard let v = live.vitals else { return nil }
        let amps = [v.currentA, v.currentB, v.currentC].compactMap { $0 }.filter { $0 >= 1 }
        guard let peak = amps.max() else { return nil }
        return "\(amps.count) \(amps.count == 1 ? "phase" : "phases") · \(Fmt.amps(peak, decimals: 0))"
    }

    private var carColor: Color {
        if live.charging { return .green }
        if live.connected { return .primary }
        return Color(.systemGray3)
    }
}

private struct FlowLine: View {
    let active: Bool
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(active ? Color.green : Color(.systemGray4))
            .frame(width: 3, height: height)
    }
}

// A schematic Gen 3 unit: rounded body with the thin status slot.
private struct ChargerGlyph: View {
    let charging: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(LinearGradient(colors: [Color(.systemGray5), Color(.systemGray3)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(charging ? Color.green : Color(.systemGray)).opacity(0.9)
                    .frame(width: 3, height: 20)
                    .padding(.bottom, 10)
            }
            .frame(width: 50, height: 72)
    }
}

// Grid voltage and frequency over the same window as the power chart: the
// spread as numbers, the voltage as a curve. The charger reports the grid even
// while idle, so this card always has something to say.
private struct GridQualityCard: View {
    let points: [HistoryPoint]

    var body: some View {
        let volts = points.compactMap(\.gridV).filter { $0 > 0 }
        let hertz = points.compactMap(\.gridHz).filter { $0 > 0 }
        Card(title: "Grid quality") {
            if volts.count > 1, let vLow = volts.min(), let vHigh = volts.max() {
                HStack(alignment: .top) {
                    GridStat(title: "Voltage", value: "\(Int(vLow.rounded())) – \(Int(vHigh.rounded())) V")
                    Spacer()
                    if let hLow = hertz.min(), let hHigh = hertz.max() {
                        GridStat(title: "Frequency",
                                 value: hLow.formatted(.number.precision(.fractionLength(2))) + " – "
                                     + hHigh.formatted(.number.precision(.fractionLength(2))) + " Hz")
                    }
                }
                GridVoltageChart(points: points)
                    .frame(height: 110)
            } else {
                Text("No samples yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GridStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.callout.weight(.semibold))
        }
    }
}

private struct GridVoltageChart: View {
    let points: [HistoryPoint]

    var body: some View {
        let slim = points.decimated(to: 500).filter { ($0.gridV ?? 0) > 0 }
        Chart(slim, id: \.ts) { point in
            LineMark(
                x: .value("Time" as String, point.date),
                y: .value("V" as String, point.gridV ?? 0)
            )
            .foregroundStyle(.indigo)
            .lineStyle(StrokeStyle(lineWidth: 1.2))
        }
        // Mains voltage lives within a few volts; a zero-based axis would hide that.
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel("V")
    }
}

// The windows the power chart can show. The server keeps 720 hours at most.
enum ChartRange: Int, CaseIterable, Identifiable {
    case day = 24
    case week = 168
    case month = 720

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .day: "24 h"
        case .week: "7 d"
        case .month: "30 d"
        }
    }
}

private struct PowerChartCard: View {
    let points: [HistoryPoint]
    @Binding var hours: Int

    var body: some View {
        Card {
            HStack {
                Text("Power")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $hours) {
                    ForEach(ChartRange.allCases) { range in
                        Text(verbatim: range.label).tag(range.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }
            if points.count > 1 {
                PowerChart(points: points)
                    .frame(height: 150)
            } else {
                Text("No samples yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PowerChart: View {
    let points: [HistoryPoint]

    var body: some View {
        // A day of 5 s samples is far more than one chart needs.
        let slim = points.decimated(to: 500)
        Chart(slim, id: \.ts) { point in
            AreaMark(
                x: .value("Time" as String, point.date),
                y: .value("kW" as String, (point.powerW ?? 0) / 1000)
            )
            .foregroundStyle(.linearGradient(colors: [.green.opacity(0.35), .green.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
            LineMark(
                x: .value("Time" as String, point.date),
                y: .value("kW" as String, (point.powerW ?? 0) / 1000)
            )
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartYAxisLabel("kW")
    }
}

extension Array {
    func decimated(to budget: Int) -> [Element] {
        guard count > budget, budget > 0 else { return self }
        let step = Swift.max(count / budget, 1)
        return enumerated().compactMap { $0.offset % step == 0 ? $0.element : nil }
    }
}

private struct LifetimeCard: View {
    let lifetime: Lifetime
    let api: any WCLApi

    var body: some View {
        Card(title: "Lifetime") {
            VStack(spacing: 8) {
                CardRow(title: "Energy delivered", value: Fmt.kwh(lifetime.energyWh))
                CardRow(title: "Charging time", value: Fmt.wholeHours(lifetime.chargingTimeS))
                CardRow(title: "Charge starts", value: Fmt.count(lifetime.chargeStarts))
                CardRow(title: "Connector cycles", value: Fmt.count(lifetime.connectorCycles))
                CardRow(title: "Contactor cycles", value: Fmt.count(lifetime.contactorCycles))
                CardRow(title: "Cycles under load", value: Fmt.count(lifetime.cyclesLoaded))
                CardRow(title: "Thermal foldbacks", value: Fmt.count(lifetime.thermalFoldbacks))
                CardRow(title: "Alert counter", value: Fmt.count(lifetime.alertCount))
                CardRow(title: "Uptime", value: Fmt.days(lifetime.uptimeS))
                NavigationLink {
                    LifetimeHistoryView(api: api)
                } label: {
                    HStack {
                        Text("Charger counter vs logged energy")
                            .foregroundStyle(.tint)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

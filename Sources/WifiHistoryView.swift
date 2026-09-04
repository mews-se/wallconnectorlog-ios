import SwiftUI
import Charts

// The charger's Wi-Fi link over time. A weak or flapping link is the usual
// reason for gaps in the log, so the drops are counted, not just drawn.
struct WifiHistoryView: View {
    let api: any WCLApi

    @AppStorage("chartHours") private var chartHours = ChartRange.day.rawValue
    @State private var points: [WifiPoint] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Range", selection: $chartHours) {
                    ForEach(ChartRange.allCases) { range in
                        Text(verbatim: range.label).tag(range.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                if points.count > 1 {
                    summary
                    Card(title: "Signal") {
                        WifiChart(points: points, key: \.rssi, unit: "dBm", color: .orange)
                            .frame(height: 150)
                    }
                    Card(title: "Signal-to-noise") {
                        WifiChart(points: points, key: \.snr, unit: "dB", color: .teal)
                            .frame(height: 120)
                    }
                } else if let error {
                    ErrorCard(message: error) { Task { await load() } }
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wi-Fi")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: chartHours) { Task { await load() } }
    }

    private var summary: some View {
        let rssi = points.compactMap(\.rssi)
        let drops = points.filter { $0.connected == 0 || $0.internet == 0 }.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "wifi", title: "Signal",
                     value: rssi.isEmpty ? "–" : "\(rssi.min()!) to \(rssi.max()!) dBm", tint: .orange)
            StatTile(icon: "wifi.exclamationmark", title: "Readings without link",
                     value: Fmt.count(drops), tint: drops == 0 ? .secondary : .red)
        }
    }

    private func load() async {
        do {
            points = try await api.wifi(hours: chartHours)
            error = nil
        } catch {
            if points.isEmpty { self.error = error.localizedDescription }
        }
    }
}

private struct WifiChart: View {
    let points: [WifiPoint]
    let key: KeyPath<WifiPoint, Int?>
    let unit: String
    let color: Color

    var body: some View {
        let slim = points.decimated(to: 500).filter { $0[keyPath: key] != nil }
        Chart(slim, id: \.ts) { point in
            LineMark(
                x: .value("Time" as String, point.date),
                y: .value(unit, point[keyPath: key] ?? 0)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 1.2))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(unit)
    }
}

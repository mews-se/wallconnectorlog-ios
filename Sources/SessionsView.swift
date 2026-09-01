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
                        ForEach(grouped, id: \.0) { month, rows in
                            Section(month) {
                                ForEach(rows) { session in
                                    NavigationLink(value: session) {
                                        SessionRow(session: session)
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
            .refreshable { await load() }
            .task { await load() }
        }
    }

    // Newest first from the server; group into month sections for scanning.
    private var grouped: [(String, [ChargeSession])] {
        var order: [String] = []
        var buckets: [String: [ChargeSession]] = [:]
        for session in sessions {
            let key = session.open
                ? "In progress"
                : session.started.formatted(.dateTime.month(.wide).year())
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(session)
        }
        return order.map { ($0, buckets[$0] ?? []) }
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

    @State private var curve: [HistoryPoint] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    StatTile(icon: "bolt.fill", title: "Energy",
                             value: Fmt.kwh(session.energyWh), tint: .green, valueTint: .green)
                    StatTile(icon: "clock", title: "Plugged in",
                             value: Fmt.duration(session.durationS), tint: .secondary)
                    StatTile(icon: "bolt.badge.clock", title: "Charging",
                             value: Fmt.duration(session.chargeS), tint: .green)
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
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Fmt.day(session.started))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCurve() }
    }

    // The history endpoint only reaches back from now, so the curve is shown
    // for recent sessions and skipped for old ones instead of pulling weeks of
    // samples.
    private func loadCurve() async {
        let age = Int(Date().timeIntervalSince1970) - session.startedAt
        let hours = age / 3600 + 1
        guard hours <= 48 else { return }
        guard let points = try? await api.history(hours: hours) else { return }
        let end = session.endedAt ?? Int(Date().timeIntervalSince1970)
        curve = points.filter { $0.ts >= session.startedAt - 60 && $0.ts <= end + 60 }
    }
}

import WidgetKit
import SwiftUI

@main
struct WallConnectorLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        WallConnectorLogWidget()
    }
}

// What the charger is doing and how much the latest session has delivered,
// without opening the app. WidgetKit decides when the timeline reloads; the
// app asks for one whenever its own poll sees the state move.
struct WallConnectorLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("Charger")
        .description("What the Wall Connector is doing and the energy of its latest session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    enum State {
        case charging, connected, idle, noServer, unreachable
    }

    let date: Date
    var state: State
    var stateText = ""
    // when the server last read the charger
    var reading: Date?
    var powerW: Double?
    var sessionWh: Double?
    var sessionS: Int?
    var handleC: Double?
    var gridV: Double?
    var rssi: Double?

    init(date: Date = .now, state: State) {
        self.date = date
        self.state = state
    }

    init(_ live: Live) {
        date = .now
        state = live.charging ? .charging : live.connected ? .connected : .idle
        stateText = live.evseStateText ?? "–"
        reading = live.ts.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        powerW = live.powerW
        sessionWh = live.openSession?.energyWh ?? live.vitals?.sessionEnergyWh
        sessionS = live.openSession?.durationS ?? live.vitals?.sessionS
        handleC = live.vitals?.handleTempC
        gridV = live.vitals?.gridV
        rssi = live.deviceNumber("wifi_rssi")
    }

    // The gallery preview: a charge in progress, so every part of the layout shows.
    static var sample: Entry {
        var entry = Entry(state: .charging)
        entry.stateText = "Charging"
        entry.reading = .now
        entry.powerW = 11_040
        entry.sessionWh = 7_580
        entry.sessionS = 48 * 60
        entry.handleC = 24.6
        entry.gridV = 230.4
        entry.rssi = -61
        return entry
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { completion(await fetch()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let entry = await fetch()
            let minutes: Double = switch entry.state {
            case .charging: 10
            case .unreachable: 5
            default: 30
            }
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(minutes * 60))))
        }
    }

    private func fetch() async -> Entry {
        guard let api = Server.make(WidgetBridge.serverURL) else { return Entry(state: .noServer) }
        do {
            return Entry(try await api.live())
        } catch {
            return Entry(state: .unreachable)
        }
    }
}

struct WidgetView: View {
    let entry: Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .noServer:
            message("Set the server address in the app")
        case .unreachable:
            message("Server unreachable")
        default:
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 12) {
                    status
                    Divider()
                    details
                }
            } else {
                status
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "ev.charger.fill")
                    .foregroundStyle(tint)
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(verbatim: family == .systemSmall ? shortState : entry.stateText)
                    .lineLimit(family == .systemSmall ? 1 : 2)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if entry.state == .charging {
                Text(verbatim: Fmt.kw(entry.powerW))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(verbatim: "Session \(Fmt.kwh(entry.sessionWh))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: Fmt.kwh(entry.sessionWh))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Last session")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let reading = entry.reading {
                (Text("Read ") + Text(reading, style: .relative) + Text(" ago"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // Session time only means something while a session runs; idle, the
    // charger's Wi-Fi link is the number worth a glance.
    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.state == .charging {
                Detail(title: "Session time", value: Fmt.duration(entry.sessionS))
            } else {
                Detail(title: "Wi-Fi", value: entry.rssi.map { "\(Int($0)) dBm" } ?? "–")
            }
            Detail(title: "Handle", value: Fmt.temp(entry.handleC))
            Detail(title: "Grid", value: Fmt.volts(entry.gridV))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "ev.charger.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var tint: Color {
        switch entry.state {
        case .charging: .green
        case .connected: .yellow
        default: Color(.systemGray3)
        }
    }

    // The charger's own state text ("No vehicle connected") does not fit a
    // small widget's header; the medium one has room for it.
    private var shortState: String {
        switch entry.state {
        case .charging: "Charging"
        case .connected: "Plugged in"
        default: "Idle"
        }
    }
}

private struct Detail: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.callout.weight(.semibold))
        }
    }
}

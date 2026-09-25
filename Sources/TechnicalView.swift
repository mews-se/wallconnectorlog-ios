import SwiftUI

// Everything the charger reports, the way it reports it: the vitals block the
// server relays verbatim, the device block and the lifetime counters. The
// Overview picks the numbers that matter; this page keeps the rest in reach.
struct TechnicalView: View {
    let api: any WCLApi

    @State private var live: Live?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let live {
                VStack(spacing: 12) {
                    charger(live)
                    vehicle(live)
                    grid(live)
                    temperatures(live)
                    network(live)
                    if let lifetime = live.lifetime {
                        counters(lifetime)
                    }
                    other(live)
                    if let ts = live.ts {
                        Text(verbatim: "Last reading \(Fmt.age(Int(Date().timeIntervalSince1970) - ts)) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)
            } else if let error {
                ErrorCard(message: error) { Task { await load() } }
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Technical")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            while !Task.isCancelled {
                await load()
                let interval: Double = live?.charging == true ? 5 : 15
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func charger(_ live: Live) -> some View {
        let v = live.vitals
        return RowCard(title: "Charger", rows: [
            ("Part number", live.deviceText("part_number")),
            ("Serial number", live.deviceText("serial_number")),
            ("Firmware", live.deviceText("firmware_version")),
            ("Firmware branch", live.deviceText("git_branch")),
            ("Backend", live.deviceText("web_service")),
            ("Config status", v?.text("config_status")),
            ("Uptime", v?.number("uptime_s").map { daysHours(Int($0)) }),
            ("IEEE 1547 trip settings", live.deviceText("IEEE1547VfTripsCrc")),
            ("IEEE 1547 ride-through", live.deviceText("IEEE1547RideThruMomentaryCessationCrc")),
            ("IEEE 1547 combined", live.deviceText("IEEE1547CombinedComplianceCrc")),
        ])
    }

    private func vehicle(_ live: Live) -> some View {
        let v = live.vitals
        let state = v?.evseState.map { "\($0)" + (live.evseStateText.map { " · \($0)" } ?? "") }
        return RowCard(title: "Vehicle and pilot", rows: [
            ("Vehicle connected", yesNo(v?.vehicleConnected)),
            ("Contactor closed", yesNo(v?.contactorClosed)),
            ("EVSE state", state),
            ("Not ready because", list(v?.raw["evse_not_ready_reasons"])),
            ("Alerts", list(v?.raw["current_alerts"])),
            ("Vehicle current", Fmt.amps(v?.vehicleCurrentA)),
            ("Session energy", Fmt.kwh(v?.sessionEnergyWh)),
            ("Session time", Fmt.duration(v?.sessionS)),
            ("Pilot high", volts(v?.number("pilot_high_v"))),
            ("Pilot low", volts(v?.number("pilot_low_v"))),
            ("Proximity", volts(v?.number("prox_v"))),
        ])
    }

    private func grid(_ live: Live) -> some View {
        let v = live.vitals
        return RowCard(title: "Grid", rows: [
            ("Grid voltage", Fmt.volts(v?.gridV)),
            ("Grid frequency", Fmt.hz(v?.gridHz)),
            ("Voltage A", Fmt.volts(v?.voltageA)),
            ("Voltage B", Fmt.volts(v?.voltageB)),
            ("Voltage C", Fmt.volts(v?.voltageC)),
            ("Current A", Fmt.amps(v?.currentA)),
            ("Current B", Fmt.amps(v?.currentB)),
            ("Current C", Fmt.amps(v?.currentC)),
            ("Current N", Fmt.amps(v?.currentN)),
            ("Relay K1 coil", volts(v?.number("relay_k1_v"))),
            ("Relay K2 coil", volts(v?.number("relay_k2_v"))),
        ])
    }

    private func temperatures(_ live: Live) -> some View {
        let v = live.vitals
        return RowCard(title: "Temperatures", rows: [
            ("Handle", Fmt.temp(v?.handleTempC)),
            ("PCBA", Fmt.temp(v?.pcbaTempC)),
            ("MCU", Fmt.temp(v?.mcuTempC)),
            ("Input thermopile", v?.number("input_thermopile_uv").map { "\(Int($0)) µV" }),
        ])
    }

    private func network(_ live: Live) -> some View {
        RowCard(title: "Network", rows: [
            ("SSID", live.deviceText("wifi_ssid")),
            ("Signal", live.deviceNumber("wifi_rssi").map { "\(Int($0)) dBm" }),
            ("Signal-to-noise", live.deviceNumber("wifi_snr").map { "\(Int($0)) dB" }),
            ("Signal strength", live.deviceNumber("wifi_signal_strength").map { "\(Int($0)) %" }),
            ("Connected", live.deviceText("wifi_connected")),
            ("Internet", live.deviceText("internet")),
            ("IP address", live.deviceText("wifi_infra_ip")),
            ("MAC address", live.deviceText("wifi_mac")),
        ])
    }

    private func counters(_ lifetime: Lifetime) -> some View {
        RowCard(title: "Lifetime counters", rows: [
            ("Energy delivered", Fmt.kwh(lifetime.energyWh)),
            ("Charging time", Fmt.wholeHours(lifetime.chargingTimeS)),
            ("Charge starts", Fmt.count(lifetime.chargeStarts)),
            ("Connector cycles", Fmt.count(lifetime.connectorCycles)),
            ("Contactor cycles", Fmt.count(lifetime.contactorCycles)),
            ("Cycles under load", Fmt.count(lifetime.cyclesLoaded)),
            ("Thermal foldbacks", Fmt.count(lifetime.thermalFoldbacks)),
            ("Alert counter", Fmt.count(lifetime.alertCount)),
            ("Uptime", Fmt.days(lifetime.uptimeS)),
        ])
    }

    // Whatever a firmware adds that the cards above do not know, by its own name.
    private func other(_ live: Live) -> some View {
        var rows: [(String, String?)] = []
        for (key, value) in live.vitals?.raw ?? [:] where !Self.knownVitals.contains(key) {
            rows.append((key, value.text ?? list(value)))
        }
        for (key, value) in live.device ?? [:] where !Self.knownDevice.contains(key) {
            rows.append((key, value.text ?? list(value)))
        }
        return RowCard(title: "Other fields", rows: rows.sorted { $0.0 < $1.0 })
    }

    private static let knownVitals: Set<String> = [
        "contactor_closed", "vehicle_connected", "session_s", "session_energy_wh", "grid_v", "grid_hz",
        "vehicle_current_a", "voltageA_v", "voltageB_v", "voltageC_v", "currentA_a", "currentB_a",
        "currentC_a", "currentN_a", "handle_temp_c", "pcba_temp_c", "mcu_temp_c", "evse_state",
        "config_status", "uptime_s", "evse_not_ready_reasons", "current_alerts", "pilot_high_v",
        "pilot_low_v", "prox_v", "relay_k1_v", "relay_k2_v", "input_thermopile_uv",
    ]

    private static let knownDevice: Set<String> = [
        "part_number", "serial_number", "firmware_version", "git_branch", "web_service",
        "IEEE1547VfTripsCrc", "IEEE1547RideThruMomentaryCessationCrc", "IEEE1547CombinedComplianceCrc",
        "wifi_ssid", "wifi_rssi", "wifi_snr", "wifi_signal_strength", "wifi_connected", "internet",
        "wifi_infra_ip", "wifi_mac",
    ]

    private func yesNo(_ value: Bool?) -> String? {
        value.map { $0 ? "Yes" : "No" }
    }

    private func volts(_ value: Double?) -> String? {
        value.map { $0.formatted(.number.precision(.fractionLength(1))) + " V" }
    }

    // Charger uptime runs to months, where hours are the interesting part.
    private func daysHours(_ s: Int) -> String {
        "\(s / 86_400) d \(s % 86_400 / 3600) h"
    }

    // The charger's lists are numeric codes; an empty list is the good case.
    private func list(_ value: JSONValue?) -> String? {
        guard case .array(let items)? = value else { return nil }
        if items.isEmpty { return "None" }
        return items.compactMap(\.text).joined(separator: ", ")
    }

    private func load() async {
        do {
            live = try await api.live()
            error = nil
        } catch {
            if live == nil {
                self.error = "Could not reach the server.\n\(error.localizedDescription)"
            }
        }
    }
}

private struct RowCard: View {
    let title: String
    let rows: [(String, String?)]

    var body: some View {
        let present = rows.compactMap { row in row.1.map { (row.0, $0) } }
        if !present.isEmpty {
            Card(title: title) {
                VStack(spacing: 8) {
                    ForEach(present, id: \.0) { row in
                        CardRow(title: row.0, value: row.1)
                    }
                }
            }
        }
    }
}

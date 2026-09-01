import Foundation

// Sample data for looking around without a server. Everything derives from the
// current time so the demo always shows a charge in progress plus a few weeks
// of history, and the same minute always renders the same numbers.
struct DemoApi: WCLApi {
    var isDemo: Bool { true }

    private var now: Int { Int(Date().timeIntervalSince1970) }

    // Deterministic 0..<1 per seed, so sessions do not reshuffle between loads.
    private func noise(_ seed: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed)) &* 0x9E3779B97F4A7C15
        x ^= x >> 29
        x &*= 0xBF58476D1CE4E5B9
        x ^= x >> 32
        return Double(x % 10_000) / 10_000
    }

    func live() async throws -> Live {
        let sessionStart = now - 48 * 60
        var live = Live()
        live.ts = now
        live.ok = true
        live.powerW = 11_040
        live.evseStateText = "Charging"
        var v = Vitals()
        v.contactorClosed = true
        v.vehicleConnected = true
        v.sessionS = now - sessionStart
        v.sessionEnergyWh = 7_580
        v.gridV = 230.4
        v.gridHz = 49.93
        v.vehicleCurrentA = 15.9
        v.voltageA = 230.9
        v.voltageB = 229.8
        v.voltageC = 231.2
        v.currentA = 16.0
        v.currentB = 16.0
        v.currentC = 16.1
        v.currentN = 0.4
        v.handleTempC = 24.6
        v.pcbaTempC = 30.8
        v.mcuTempC = 33.5
        v.evseState = 11
        live.vitals = v
        var lt = Lifetime()
        lt.energyWh = 1_842_700
        lt.chargeStarts = 512
        lt.connectorCycles = 214
        lt.chargingTimeS = 361 * 3600
        lt.contactorCycles = 455
        lt.thermalFoldbacks = 0
        lt.alertCount = 4_211
        lt.cyclesLoaded = 28
        lt.uptimeS = 172 * 86_400
        live.lifetime = lt
        live.device = [
            "firmware_version": .string("26.26.1"),
            "part_number": .string("1529455-02-F"),
            "serial_number": .string("WC-DEMO-0001"),
            "wifi_ssid": .string("Garage"),
            "wifi_rssi": .number(-61),
            "wifi_snr": .number(28),
            "wifi_connected": .bool(true),
            "internet": .bool(true),
        ]
        live.openSession = ChargeSession(
            id: 999, startedAt: sessionStart, endedAt: nil, energyWh: 7_580,
            durationS: now - sessionStart, chargeS: now - sessionStart - 90,
            peakPowerW: 11_090, peakHandleC: 24.9, isOpen: 1, avgGridV: 230.2
        )
        return live
    }

    func sessions() async throws -> [ChargeSession] {
        var rows: [ChargeSession] = []
        let open = try await live().openSession
        if let open { rows.append(open) }
        var day = 1
        var id = 40
        while day < 45 {
            let n = noise(id)
            // Evening plug-ins two days out of three, sized like real home charging.
            let start = now - day * 86_400 - Int(6.5 * 3600) + Int(n * 5_400)
            let energy = 4_000 + n * 38_000
            let duration = Int(energy / 11_000 * 3_600) + Int(n * 2_400)
            rows.append(ChargeSession(
                id: id, startedAt: start, endedAt: start + duration,
                energyWh: energy, durationS: duration,
                chargeS: Int(Double(duration) * 0.93),
                peakPowerW: 10_900 + n * 250, peakHandleC: 22 + n * 6,
                isOpen: 0, avgGridV: 229 + n * 3
            ))
            day += n < 0.33 ? 2 : 1
            id -= 1
        }
        return rows
    }

    func history(hours: Int) async throws -> [HistoryPoint] {
        var points: [HistoryPoint] = []
        let sessionStart = now - 48 * 60
        let step = 120
        var ts = now - hours * 3600
        while ts <= now {
            let inSession = ts >= sessionStart
            // This morning's finished charge, so a 24 h window shows two humps.
            let previous = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(ts)))
                .addingTimeInterval(7 * 3600)
            let inPrevious = TimeInterval(ts) >= previous.timeIntervalSince1970
                && TimeInterval(ts) <= previous.timeIntervalSince1970 + 2.6 * 3600
            let charging = inSession || inPrevious
            var p = HistoryPoint(ts: ts)
            p.powerW = charging ? 10_950 + noise(ts / step).rounded() * 180 : 0
            p.gridV = 229.5 + noise(ts / step) * 2
            p.gridHz = 49.9 + noise(ts / step) * 0.15
            p.currentA = charging ? 16 : 0
            p.handleC = charging ? 24 : 19
            p.pcbaC = charging ? 31 : 24
            p.mcuC = charging ? 33 : 26
            p.contactorClosed = charging ? 1 : 0
            points.append(p)
            ts += step
        }
        return points
    }
}

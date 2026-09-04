import Foundation

// The server relays the charger's vitals verbatim, so every field is optional:
// firmware differences must never break decoding.
struct Vitals: Decodable, Sendable {
    var contactorClosed: Bool? = nil
    var vehicleConnected: Bool? = nil
    var sessionS: Int? = nil
    var sessionEnergyWh: Double? = nil
    var gridV: Double? = nil
    var gridHz: Double? = nil
    var vehicleCurrentA: Double? = nil
    var voltageA: Double? = nil
    var voltageB: Double? = nil
    var voltageC: Double? = nil
    var currentA: Double? = nil
    var currentB: Double? = nil
    var currentC: Double? = nil
    var currentN: Double? = nil
    var handleTempC: Double? = nil
    var pcbaTempC: Double? = nil
    var mcuTempC: Double? = nil
    var evseState: Int? = nil

    enum CodingKeys: String, CodingKey {
        case contactorClosed = "contactor_closed"
        case vehicleConnected = "vehicle_connected"
        case sessionS = "session_s"
        case sessionEnergyWh = "session_energy_wh"
        case gridV = "grid_v"
        case gridHz = "grid_hz"
        case vehicleCurrentA = "vehicle_current_a"
        case voltageA = "voltageA_v"
        case voltageB = "voltageB_v"
        case voltageC = "voltageC_v"
        case currentA = "currentA_a"
        case currentB = "currentB_a"
        case currentC = "currentC_a"
        case currentN = "currentN_a"
        case handleTempC = "handle_temp_c"
        case pcbaTempC = "pcba_temp_c"
        case mcuTempC = "mcu_temp_c"
        case evseState = "evse_state"
    }
}

struct Lifetime: Decodable, Sendable {
    var energyWh: Double? = nil
    var chargeStarts: Int? = nil
    var connectorCycles: Int? = nil
    var chargingTimeS: Int? = nil
    var contactorCycles: Int? = nil
    var thermalFoldbacks: Int? = nil
    var alertCount: Int? = nil
    var cyclesLoaded: Int? = nil
    var uptimeS: Int? = nil

    enum CodingKeys: String, CodingKey {
        case energyWh = "energy_wh"
        case chargeStarts = "charge_starts"
        case connectorCycles = "connector_cycles"
        case chargingTimeS = "charging_time_s"
        case contactorCycles = "contactor_cycles"
        case thermalFoldbacks = "thermal_foldbacks"
        case alertCount = "alert_count"
        case cyclesLoaded = "cycles_loaded"
        case uptimeS = "uptime_s"
    }
}

struct ChargeSession: Decodable, Sendable, Identifiable, Hashable {
    var id: Int
    var startedAt: Int
    var endedAt: Int? = nil
    var energyWh: Double? = nil
    var durationS: Int? = nil
    var chargeS: Int? = nil
    var peakPowerW: Double? = nil
    var peakHandleC: Double? = nil
    var isOpen: Int? = nil
    var avgGridV: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case energyWh = "energy_wh"
        case durationS = "duration_s"
        case chargeS = "charge_s"
        case peakPowerW = "peak_power_w"
        case peakHandleC = "peak_handle_c"
        case isOpen = "is_open"
        case avgGridV = "avg_grid_v"
    }

    var started: Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
    var ended: Date? { endedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    var open: Bool { isOpen == 1 }
}

struct HistoryPoint: Decodable, Sendable {
    var ts: Int
    var gridV: Double? = nil
    var gridHz: Double? = nil
    var powerW: Double? = nil
    var currentA: Double? = nil
    var handleC: Double? = nil
    var pcbaC: Double? = nil
    var mcuC: Double? = nil
    var contactorClosed: Int? = nil
    // Only the per-session samples endpoint carries the phases.
    var ampA: Double? = nil
    var ampB: Double? = nil
    var ampC: Double? = nil

    enum CodingKeys: String, CodingKey {
        case ts
        case gridV = "grid_v"
        case gridHz = "grid_hz"
        case powerW = "power_w"
        case currentA = "current_a"
        case handleC = "handle_c"
        case pcbaC = "pcba_c"
        case mcuC = "mcu_c"
        case contactorClosed = "contactor_closed"
        case ampA = "amp_a"
        case ampB = "amp_b"
        case ampC = "amp_c"
    }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
}

// The device map mixes strings, numbers and booleans from /api/1/version and
// /api/1/wifi_status, so it is decoded permissively.
enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let value = try? c.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? c.decode(Double.self) {
            self = .number(value)
        } else if let value = try? c.decode(String.self) {
            self = .string(value)
        } else if let value = try? c.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    var text: String? {
        switch self {
        case .string(let value): value
        case .number(let value):
            value == value.rounded() ? String(Int(value)) : String(value)
        case .bool(let value): value ? "Yes" : "No"
        default: nil
        }
    }

    var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
}

// One reading of the charger's Wi-Fi link, taken every slow poll.
struct WifiPoint: Decodable, Sendable {
    var ts: Int
    var rssi: Int? = nil
    var snr: Int? = nil
    var connected: Int? = nil
    var internet: Int? = nil

    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
}

// The charger's lifetime counters as they stood at one point in time.
struct LifetimeRow: Decodable, Sendable {
    var ts: Int
    var energyWh: Double? = nil
    var chargeStarts: Int? = nil
    var chargingTimeS: Int? = nil

    enum CodingKeys: String, CodingKey {
        case ts
        case energyWh = "energy_wh"
        case chargeStarts = "charge_starts"
        case chargingTimeS = "charging_time_s"
    }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
}

// One failed poll of the charger, as the server logged it.
struct PollError: Decodable, Sendable {
    var ts: Int
    var detail: String

    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
}

// What Settings shows to tell a healthy server from a stalled or drifted one.
struct Diagnostics: Sendable {
    var live: Live
    var serverClock: Date?
    var lastError: PollError?
}

// The server's own pointer to Grafana: a bare ":3399" that follows the server's
// host, or a full URL the operator configured, plus whether it answered lately.
struct GrafanaLink: Decodable, Sendable {
    var url: String? = nil
    var up: Bool? = nil
}

struct Live: Decodable, Sendable {
    var ts: Int? = nil
    var ok: Bool? = nil
    var error: String? = nil
    var vitals: Vitals? = nil
    var powerW: Double? = nil
    var lifetime: Lifetime? = nil
    var device: [String: JSONValue]? = nil
    var openSession: ChargeSession? = nil
    var evseStateText: String? = nil
    var grafana: GrafanaLink? = nil

    enum CodingKeys: String, CodingKey {
        case ts, ok, error, vitals, lifetime, device, grafana
        case powerW = "power_w"
        case openSession = "open_session"
        case evseStateText = "evse_state_text"
    }

    var charging: Bool { vitals?.contactorClosed == true }
    var connected: Bool { vitals?.vehicleConnected == true }

    func deviceText(_ key: String) -> String? { device?[key]?.text }
    func deviceNumber(_ key: String) -> Double? { device?[key]?.number }
}

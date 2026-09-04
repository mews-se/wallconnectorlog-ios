import Foundation

// Everything the Statistics tab shows, computed once from the session list.
// Foundation only, so the arithmetic can be checked outside the app.
struct SessionStats {
    let sessions: [ChargeSession]
    let now: Date
    var calendar = Calendar.current

    struct Totals {
        var energyWh = 0.0
        var count = 0
        var chargingS = 0
        var pluggedS = 0

        var averagePowerW: Double? {
            chargingS > 0 ? energyWh / (Double(chargingS) / 3600) : nil
        }

        var idleShare: Double? {
            pluggedS > 0 ? Double(max(0, pluggedS - chargingS)) / Double(pluggedS) : nil
        }
    }

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: "This week"
            case .month: "This month"
            case .year: "This year"
            case .all: "All time"
            }
        }
    }

    func totals(_ period: Period) -> Totals {
        let start: Date? = switch period {
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .month: calendar.dateInterval(of: .month, for: now)?.start
        case .year: calendar.dateInterval(of: .year, for: now)?.start
        case .all: nil
        }
        var t = Totals()
        for s in sessions where start.map({ s.started >= $0 }) ?? true {
            t.energyWh += s.energyWh ?? 0
            t.count += 1
            t.chargingS += s.chargeS ?? 0
            t.pluggedS += s.durationS ?? 0
        }
        return t
    }

    // One bar per calendar day for the last `days` days, zero where nothing
    // was charged, so the chart keeps its time axis honest.
    func perDay(days: Int) -> [(day: Date, energyWh: Double)] {
        let today = calendar.startOfDay(for: now)
        var buckets: [Date: Double] = [:]
        for s in sessions {
            buckets[calendar.startOfDay(for: s.started), default: 0] += s.energyWh ?? 0
        }
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (day, buckets[day] ?? 0)
        }
    }

    func perMonth(months: Int) -> [(month: Date, energyWh: Double)] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        var buckets: [Date: Double] = [:]
        for s in sessions {
            if let m = calendar.dateInterval(of: .month, for: s.started)?.start {
                buckets[m, default: 0] += s.energyWh ?? 0
            }
        }
        return (0..<months).reversed().compactMap { back in
            guard let month = calendar.date(byAdding: .month, value: -back, to: thisMonth) else { return nil }
            return (month, buckets[month] ?? 0)
        }
    }

    var largest: ChargeSession? { sessions.max { ($0.energyWh ?? 0) < ($1.energyWh ?? 0) } }
    var longestCharge: ChargeSession? { sessions.max { ($0.chargeS ?? 0) < ($1.chargeS ?? 0) } }
    var strongest: ChargeSession? { sessions.max { ($0.peakPowerW ?? 0) < ($1.peakPowerW ?? 0) } }
}

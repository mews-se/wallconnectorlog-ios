import Foundation

enum Fmt {
    // Takes watts, shows kW the way the charger is talked about: one decimal
    // below 10 kW, none above.
    static func kw(_ w: Double?) -> String {
        guard let w else { return "–" }
        let kw = w / 1000
        let decimals = kw < 10 ? 1 : 0
        return kw.formatted(.number.precision(.fractionLength(decimals))) + " kW"
    }

    // Takes watt-hours; grows into MWh where kWh stops being readable.
    static func kwh(_ wh: Double?) -> String {
        guard let wh else { return "–" }
        let kwh = wh / 1000
        if kwh >= 1000 {
            return (kwh / 1000).formatted(.number.precision(.fractionLength(2))) + " MWh"
        }
        let decimals = kwh >= 100 ? 0 : 1
        return kwh.formatted(.number.precision(.fractionLength(decimals))) + " kWh"
    }

    static func temp(_ c: Double?) -> String {
        guard let c else { return "–" }
        return c.formatted(.number.precision(.fractionLength(0))) + "°"
    }

    static func volts(_ v: Double?) -> String {
        guard let v else { return "–" }
        return v.formatted(.number.precision(.fractionLength(0))) + " V"
    }

    static func hz(_ v: Double?) -> String {
        guard let v else { return "–" }
        return v.formatted(.number.precision(.fractionLength(1))) + " Hz"
    }

    static func amps(_ a: Double?, decimals: Int = 1) -> String {
        guard let a else { return "–" }
        return a.formatted(.number.precision(.fractionLength(decimals))) + " A"
    }

    static func duration(_ s: Int?) -> String {
        guard let s, s >= 0 else { return "–" }
        let minutes = s / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    // Lifetime counters run to hundreds of hours where minutes are noise.
    static func wholeHours(_ s: Int?) -> String {
        guard let s else { return "–" }
        return "\(s / 3600) h"
    }

    // "12 s", "3 min", "2 h 05 min": how long ago something happened.
    static func age(_ s: Int) -> String {
        if s < 60 { return "\(s) s" }
        let minutes = s / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
    }

    // Cost in the phone's currency. The price is whatever the user typed per
    // kWh, so this is only ever as right as that number.
    static func money(_ amount: Double) -> String {
        let code = Locale.current.currency?.identifier ?? "SEK"
        return amount.formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }

    static func days(_ s: Int?) -> String {
        guard let s else { return "–" }
        return "\(s / 86_400) days"
    }

    static func count(_ n: Int?) -> String {
        n.map { $0.formatted() } ?? "–"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func timeRange(_ start: Date, _ end: Date?) -> String {
        guard let end else { return time(start) + " –" }
        return time(start) + " – " + time(end)
    }
}

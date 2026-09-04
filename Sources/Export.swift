import SwiftUI
import UniformTypeIdentifiers

// The session list as a CSV file for the share sheet: one row per session, the
// columns /api/sessions serves, in units that read without a legend. Numbers
// use a dot as the decimal mark whatever the phone's locale, so the file opens
// the same way everywhere.
struct SessionsCSV: Transferable {
    let sessions: [ChargeSession]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.text.utf8)
        }
        .suggestedFileName("wallconnectorlog-sessions.csv")
    }

    var text: String {
        var lines = ["started,ended,energy_kwh,plugged_in_min,charging_min,peak_power_kw,peak_handle_c,avg_grid_v"]
        for s in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            lines.append([
                Self.stamp(s.started),
                s.ended.map(Self.stamp) ?? "",
                Self.number(s.energyWh.map { $0 / 1000 }, decimals: 3),
                Self.number(s.durationS.map { Double($0) / 60 }, decimals: 0),
                Self.number(s.chargeS.map { Double($0) / 60 }, decimals: 0),
                Self.number(s.peakPowerW.map { $0 / 1000 }, decimals: 2),
                Self.number(s.peakHandleC.flatMap { $0 > -99 ? $0 : nil }, decimals: 1),
                Self.number(s.avgGridV, decimals: 1),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // Local time with its offset spelled out, so the file is unambiguous anywhere.
    private static let stampFormat = Date.ISO8601FormatStyle(timeZone: .current)
        .year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .colon)

    private static func stamp(_ date: Date) -> String {
        date.formatted(stampFormat)
    }

    private static func number(_ value: Double?, decimals: Int) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(decimals)).grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX")))
    }
}

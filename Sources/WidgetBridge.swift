import Foundation
import WidgetKit

// The widget runs in its own process and cannot see the app's defaults, so
// the server address is mirrored into the shared group whenever it changes,
// and the app nudges the widget when the charger's state moves.
enum WidgetBridge {
    static let group = "group.se.mews.wallconnectorlog"
    static let kind = "WallConnectorLogWidget"

    static var serverURL: String {
        UserDefaults(suiteName: group)?.string(forKey: "serverURL") ?? ""
    }

    // Compared against what the group has on disk: a launch argument would
    // otherwise answer for the suite too and hide that nothing was written.
    static func mirror(serverURL: String) {
        guard let shared = UserDefaults(suiteName: group) else { return }
        let stored = shared.persistentDomain(forName: group)?["serverURL"] as? String
        guard stored != serverURL else { return }
        shared.set(serverURL, forKey: "serverURL")
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    // Called after every poll. Reloads asked for while the app is in front
    // are free, but the widget only needs a redraw when its numbers move.
    @MainActor private static var shown = ""

    @MainActor static func refresh(with live: Live) {
        let signature = [
            live.charging ? "c" : live.connected ? "p" : "i",
            "\(Int((live.powerW ?? 0) / 500))",
            "\(Int((live.vitals?.sessionEnergyWh ?? 0) / 100))",
        ].joined(separator: "|")
        guard signature != shown else { return }
        shown = signature
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}

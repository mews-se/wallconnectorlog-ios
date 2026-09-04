import SwiftUI
import UIKit

struct AboutView: View {
    private static let developer = "Martin Stockzell (mews-se)"

    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("grafanaURL") private var grafanaURL = ""
    // one reading of /api/live, for the server's own Grafana pointer
    @State private var live: Live?

    // the icon exactly as shipped, read from the bundle so the page never drifts
    // from the home screen. the catalog compiles it under the names listed in
    // CFBundleIcons - asking for "AppIcon" itself comes back empty
    private static let appIcon: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }()

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    // 60 points is the compiled variant's own size - larger would upscale
                    if let icon = Self.appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                            .padding(.bottom, 6)
                    }
                    Text(verbatim: "WallConnectorLog")
                        .font(.title2.weight(.semibold))
                    Text(verbatim: version)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "A project by \(Self.developer)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }

            Section {
                HStack(spacing: 13) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free and open source")
                            .font(.subheadline.weight(.semibold))
                        Text("No ads, no tracking, nothing to buy")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)

                LinkRow(icon: "chevron.left.forwardslash.chevron.right",
                        title: "Source code", detail: "GitHub",
                        url: "https://github.com/mews-se/wallconnectorlog-ios")

                LabeledContent {
                    Text(verbatim: "MIT")
                } label: {
                    Label("License", systemImage: "doc.plaintext")
                }

                LinkRow(icon: "gift", title: "Donate",
                        detail: "If you feel like giving back",
                        url: "https://mews-se.github.io/wallconnectorlog-site/donate/")
            } header: {
                Text("Open source")
            } footer: {
                Text("The code is there to read, build and change.")
            }

            Section {
                // the row opens the server's own dashboard - its code is already
                // one step away through Source code above
                if !Server.isDemo(serverURL), let base = Server.baseURL(serverURL) {
                    LinkRow(icon: "ev.charger.fill", title: "WallConnectorLog server",
                            detail: base.absoluteString, url: base.absoluteString)
                    if let grafana = Server.grafanaURL(setting: grafanaURL, server: serverURL, live: live) {
                        LinkRow(icon: "chart.xyaxis.line", title: "Graphs in Grafana",
                                detail: grafana.absoluteString, url: grafana.absoluteString)
                    } else if live != nil {
                        PlainRow(icon: "chart.xyaxis.line", title: "Graphs in Grafana",
                                 detail: "Set the address in Settings")
                    }
                } else {
                    PlainRow(icon: "ev.charger.fill", title: "WallConnectorLog server",
                             detail: "No server configured")
                }
            } header: {
                Text("Data source")
            } footer: {
                Text(verbatim: "This app is an unofficial community tool and is not affiliated with, endorsed by, or supported by Tesla, Inc.")
            }
        }
        // the list's default first-section margin leaves a hole between the bar
        // and the icon; the page reads better with the header pulled up
        .contentMargins(.top, 8, for: .scrollContent)
        .navigationTitle("About WallConnectorLog")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !Server.isDemo(serverURL) else { return }
            live = try? await Server.make(serverURL)?.live()
        }
    }
}

private struct PlainRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let detail: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .foregroundStyle(.primary)
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

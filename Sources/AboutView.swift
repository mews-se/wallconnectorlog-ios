import SwiftUI
import UIKit

struct AboutView: View {
    private static let developer = "Martin Stockzell (mews-se)"

    @AppStorage("serverURL") private var serverURL = ""

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
                } else {
                    HStack(spacing: 13) {
                        Image(systemName: "ev.charger.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WallConnectorLog server")
                            Text("No server configured")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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

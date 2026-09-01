import SwiftUI

struct RootView: View {
    @AppStorage("serverURL") private var serverURL = ""

    var body: some View {
        if let api = Server.make(serverURL) {
            TabView {
                Tab("Overview", systemImage: "gauge.with.dots.needle.50percent") {
                    OverviewView(api: api)
                }
                Tab("Sessions", systemImage: "bolt.fill") {
                    SessionsView(api: api)
                }
                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
        } else {
            OnboardingView()
        }
    }
}

struct OnboardingView: View {
    @AppStorage("serverURL") private var serverURL = ""

    @State private var draft = ""
    @State private var result: SettingsView.TestResult?
    @State private var testing = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            AppIconImage()
            Text("WallConnectorLog")
                .font(.largeTitle.bold())
            Text("A phone-sized window into the charge log your WallConnectorLog server keeps around the clock.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("Server address", text: $draft, prompt: Text(verbatim: "10.0.1.11:4680"))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .onSubmit { connect() }
            Text("No server yet? Type demo to look around with sample data.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if case .failed(let message) = result {
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button(action: connect) {
                if testing {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Connect").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || testing)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(.systemGroupedBackground))
    }

    private func connect() {
        Task {
            testing = true
            defer { testing = false }
            result = await SettingsView.probe(draft)
            if case .ok = result {
                serverURL = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}

// The compiled icon variant is the only way to the artwork: UIImage(named:
// "AppIcon") is nil, the bundle carries it as AppIcon60x60.
struct AppIconImage: View {
    var body: some View {
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 84 * 0.2237, style: .continuous))
        }
    }
}

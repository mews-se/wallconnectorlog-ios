import SwiftUI

struct SettingsView: View {
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("grafanaURL") private var grafanaURL = ""

    // The field edits a draft and commits on Done/submit, never per keystroke -
    // a keystroke-live binding rebuilds the view tree under the keyboard.
    @State private var draft = ""
    @State private var grafanaDraft = ""
    @State private var testResult: TestResult?
    @State private var testing = false

    enum TestResult {
        case ok(String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Address", text: $draft, prompt: Text(verbatim: "10.0.1.11:4680"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { commit() }
                    Button {
                        Task { await test() }
                    } label: {
                        if testing {
                            ProgressView()
                        } else {
                            Text("Test connection")
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || testing)
                    if let testResult {
                        switch testResult {
                        case .ok(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("The address of your WallConnectorLog server: 10.0.1.11:4680 on your own network, or a name like charger.example.com if it sits behind HTTPS. No server yet? Type demo to look around with sample data.")
                }
                Section {
                    TextField("Address", text: $grafanaDraft, prompt: Text(verbatim: "Optional"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { commit() }
                } header: {
                    Text("Grafana")
                } footer: {
                    Text("Leave empty when Grafana runs next to the server: the app follows the server's own link, 10.0.1.11:3399 for a server at 10.0.1.11:4680. Give a name or URL when Grafana sits behind its own HTTPS name.")
                }
                Section("About") {
                    NavigationLink("About WallConnectorLog") { AboutView() }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                draft = serverURL
                grafanaDraft = grafanaURL
            }
            .onDisappear { commit() }
        }
    }

    // An empty server field is ignored, an empty Grafana field means "follow
    // the server", so that one is always written back.
    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { serverURL = trimmed }
        grafanaURL = grafanaDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func test() async {
        testing = true
        defer { testing = false }
        testResult = await Self.probe(draft)
        if case .ok = testResult { commit() }
    }

    // Shared with onboarding: demo passes straight through, anything else must
    // answer /api/live.
    static func probe(_ address: String) async -> TestResult {
        if Server.isDemo(address) {
            return .ok("Demo mode")
        }
        guard let api = Server.make(address) else {
            return .failed("Not a usable address")
        }
        do {
            let live = try await api.live()
            if live.ok == true {
                return .ok("Connected — charger answering")
            }
            return .ok("Connected — charger unreachable from the server")
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @AppStorage("serverURL") private var serverURL = ""

    // The field edits a draft and commits on Done/submit, never per keystroke -
    // a keystroke-live binding rebuilds the view tree under the keyboard.
    @State private var draft = ""
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
                    Text("The address of your WallConnectorLog server, like 10.0.1.11:4680. No server yet? Type demo to look around with sample data.")
                }
                Section("About") {
                    NavigationLink("About WallConnectorLog") { AboutView() }
                }
            }
            .navigationTitle("Settings")
            .onAppear { draft = serverURL }
            .onDisappear { commit() }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        serverURL = trimmed
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

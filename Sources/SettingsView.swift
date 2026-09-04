import SwiftUI

struct SettingsView: View {
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("grafanaURL") private var grafanaURL = ""
    @AppStorage("pricePerKwh") private var pricePerKwh = 0.0
    @State private var priceDraft = ""

    // The field edits a draft and commits on Done/submit, never per keystroke -
    // a keystroke-live binding rebuilds the view tree under the keyboard.
    @State private var draft = ""
    @State private var grafanaDraft = ""
    @State private var testResult: TestResult?
    @State private var testing = false
    @State private var diagnostics: Diagnostics?
    @State private var diagnosticsError: String?
    // when the diagnostics were read, so the ages below are honest
    @State private var readAt = Date()

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
                Section {
                    TextField("Price per kWh", text: $priceDraft, prompt: Text(verbatim: "0"))
                        .keyboardType(.decimalPad)
                        .onChange(of: priceDraft) { pricePerKwh = Self.price(from: priceDraft) }
                } header: {
                    Text("Cost")
                } footer: {
                    Text("Your price per kWh, in your own currency. Set it and the statistics and session details show what each charge cost; leave it at 0 to hide cost.")
                }
                Section {
                    if let d = diagnostics {
                        let age = Int(readAt.timeIntervalSince1970) - (d.live.ts ?? Int(readAt.timeIntervalSince1970))
                        LabeledContent("Last reading") {
                            Text(verbatim: Fmt.age(max(0, age)) + " ago")
                                .foregroundStyle(age > Self.staleAfter ? .orange : .secondary)
                        }
                        LabeledContent("Server clock") {
                            Text(verbatim: clockText(d.serverClock))
                                .foregroundStyle(clockOff(d.serverClock) ? .orange : .secondary)
                        }
                        LabeledContent("Last poll error") {
                            if let e = d.lastError {
                                Text(verbatim: Fmt.age(max(0, Int(readAt.timeIntervalSince(e.date)))) + " ago · " + e.detail)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("None")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let diagnosticsError {
                        Label(diagnosticsError, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("The logger polls every 5 to 60 seconds, so a reading older than a few minutes means it has stopped. A server clock off by more than a minute skews the session times it records.")
                }
                Section("About") {
                    NavigationLink("About WallConnectorLog") { AboutView() }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                draft = serverURL
                grafanaDraft = grafanaURL
                priceDraft = pricePerKwh > 0
                    ? pricePerKwh.formatted(.number.precision(.fractionLength(0...4)).grouping(.never))
                    : ""
            }
            .task { await readDiagnostics() }
            .refreshable { await readDiagnostics() }
            .onDisappear { commit() }
        }
    }

    // "2,5" and "2.5" mean the same price whatever separator the keyboard
    // offers, so the field is parsed by hand instead of by locale.
    static func price(from text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return max(0, Double(cleaned) ?? 0)
    }

    // Three poll intervals at the idle cadence: beyond this the logger is not
    // just slow, it has stopped.
    private static let staleAfter = 180

    private func clockText(_ server: Date?) -> String {
        guard let server else { return "Not reported" }
        let delta = Int(server.timeIntervalSince(readAt).rounded())
        if abs(delta) < 5 { return "In sync" }
        return Fmt.age(abs(delta)) + (delta > 0 ? " ahead" : " behind")
    }

    private func clockOff(_ server: Date?) -> Bool {
        guard let server else { return false }
        return abs(server.timeIntervalSince(readAt)) > 60
    }

    private func readDiagnostics() async {
        guard let api = Server.make(serverURL) else {
            diagnosticsError = "No server configured"
            return
        }
        do {
            let d = try await api.diagnostics()
            readAt = Date()
            diagnostics = d
            diagnosticsError = nil
        } catch {
            diagnostics = nil
            diagnosticsError = error.localizedDescription
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

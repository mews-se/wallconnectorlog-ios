import Foundation

protocol WCLApi: Sendable {
    var isDemo: Bool { get }
    func live() async throws -> Live
    func sessions() async throws -> [ChargeSession]
    func history(hours: Int) async throws -> [HistoryPoint]
}

enum Server {
    // "demo" is a reserved address: it switches the whole app to generated data.
    static func isDemo(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "demo"
    }

    // Accepts a bare host, host:port or a pasted URL; a missing port gets the
    // server's default 4680.
    static func baseURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }
        guard var parts = URLComponents(string: s), parts.host?.isEmpty == false else { return nil }
        if parts.port == nil { parts.port = 4680 }
        parts.path = ""
        parts.query = nil
        return parts.url
    }

    static func make(_ raw: String) -> (any WCLApi)? {
        if isDemo(raw) { return DemoApi() }
        return baseURL(raw).map(HTTPApi.init)
    }
}

struct HTTPApi: WCLApi {
    let base: URL
    var isDemo: Bool { false }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: base) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func live() async throws -> Live {
        try await get("/api/live")
    }

    func sessions() async throws -> [ChargeSession] {
        try await get("/api/sessions")
    }

    func history(hours: Int) async throws -> [HistoryPoint] {
        try await get("/api/history?hours=\(min(max(hours, 1), 720))")
    }
}

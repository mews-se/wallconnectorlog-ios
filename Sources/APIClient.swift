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

    // Accepts a bare host, host:port or a pasted URL. A typed scheme is kept,
    // and a missing port then means that scheme's default. Without a scheme a
    // local address keeps plain http and the server's 4680, while any other
    // name is taken to sit behind a proxy with a certificate: https, no port.
    static func baseURL(_ raw: String, defaultPort: Int = 4680) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let typedScheme = s.contains("://")
        if !typedScheme { s = "http://" + s }
        guard var parts = URLComponents(string: s), let host = parts.host, !host.isEmpty else {
            return nil
        }
        if !typedScheme && parts.port == nil {
            if isLocal(host) {
                parts.port = defaultPort
            } else {
                parts.scheme = "https"
            }
        }
        parts.path = ""
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }

    // The addresses NSAllowsLocalNetworking lets plain http reach: private and
    // loopback IPv4 ranges, link-local, .local names and single-label names.
    // IPv6 literals are treated as local too; nobody exposes a charger on one.
    static func isLocal(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "localhost" || h.hasSuffix(".local") || !h.contains(".") || h.contains(":") {
            return true
        }
        let octets = h.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (169, 254), (192, 168), (172, 16...31):
            return true
        default:
            return false
        }
    }

    // Where the graphs live. A typed address wins. Otherwise the server's own
    // pointer from /api/live is followed the way its web page follows it - a
    // bare port on the server's host, a full URL as it is - but never a bare
    // port on an https server address: a proxy does not listen there, so that
    // case needs the field.
    static func grafanaURL(setting: String, server: String, live: Live?) -> URL? {
        if !setting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return baseURL(setting, defaultPort: 3399)
        }
        guard let hint = live?.grafana, hint.up == true, let raw = hint.url, !raw.isEmpty,
              let base = baseURL(server) else { return nil }
        if raw.contains("://") { return baseURL(raw, defaultPort: 3399) }
        guard base.scheme == "http", let port = Int(raw.hasPrefix(":") ? String(raw.dropFirst()) : raw),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        parts.port = port
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

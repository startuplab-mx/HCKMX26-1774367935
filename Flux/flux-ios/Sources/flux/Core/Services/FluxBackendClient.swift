import Foundation

/// Cliente HTTP del backend flux. Mínimo y sin dependencias.
/// Apunta al `main.py` de backend/ (FastAPI).
actor FluxBackendClient {

    enum ClientError: Error {
        case invalidURL
        case http(status: Int, body: String)
        case decoding(Error)
    }

    static let shared = FluxBackendClient()

    /// Base URL configurable vía Info.plist `FLUX_BACKEND_URL`. Fallback a localhost.
    private let baseURL: URL

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        let resolved: URL = {
            if let baseURL { return baseURL }
            if let str = Bundle.main.object(forInfoDictionaryKey: "FLUX_BACKEND_URL") as? String,
               let url = URL(string: str) {
                return url
            }
            return URL(string: "http://127.0.0.1:8000")!
        }()
        self.baseURL = resolved
        self.session = session

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    /// POST /api/v1/children/{id}/events
    func ingestEvents(
        childID: UUID,
        events: [FluxUsageEvent]
    ) async throws -> FluxUsageBatchResponse {
        guard !events.isEmpty else {
            return FluxUsageBatchResponse(accepted: 0, signalsGenerated: 0, signalIds: [])
        }

        let url = baseURL
            .appendingPathComponent("api/v1/children")
            .appendingPathComponent(childID.uuidString.lowercased())
            .appendingPathComponent("events")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(FluxUsageBatchRequest(events: events))

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.http(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(status: http.statusCode, body: body)
        }

        do {
            return try decoder.decode(FluxUsageBatchResponse.self, from: data)
        } catch {
            throw ClientError.decoding(error)
        }
    }

    /// Drena la cola local y envía los eventos al backend en un batch.
    /// Al confirmar, los elimina del queue. Si falla, los deja para reintento.
    @discardableResult
    func flushQueue(childID: UUID, queue: FluxEventQueue = .shared) async throws -> FluxUsageBatchResponse {
        let pending = queue.peekAll()
        guard !pending.isEmpty else {
            return FluxUsageBatchResponse(accepted: 0, signalsGenerated: 0, signalIds: [])
        }
        let response = try await ingestEvents(childID: childID, events: pending)
        queue.remove(ids: Set(pending.map(\.id)))
        return response
    }
}

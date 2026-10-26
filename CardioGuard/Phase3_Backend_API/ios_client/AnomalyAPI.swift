import Foundation

// MARK: - Wire types (match backend/app/schemas.py exactly)

/// Minimal reading sent to the server. Build one from your own stored model (see README).
struct APIReading: Codable {
    /// "heartRate" | "bloodPressure" | "glucose" | "oxygen"
    var type: String
    var timestamp: Date
    var value: Double
    /// Diastolic, for bloodPressure only.
    var value2: Double?
}

struct ScoreRequestBody: Codable {
    var reading: APIReading
    var history: [APIReading]
}

struct ChannelResultDTO: Codable {
    var channel: String
    var value: Double
    var z: Double
    var center: Double
    var spread: Double
    var usualLow: Double
    var usualHigh: Double
    var nBaseline: Int
    var confidence: String
    var tier: String
    var direction: String
    var consecutiveDeviations: Int
}

struct ScoreResult: Codable {
    /// "normal" | "note" | "urgent"
    var tier: String
    var score: Double
    var confidence: String
    var message: String
    var reasons: [String]
    var channels: [ChannelResultDTO]
    var modelVersion: String
    var disclaimer: String

    var isNormal: Bool { tier == "normal" }
    var isUrgent: Bool { tier == "urgent" }
}

// MARK: - Client

enum AnomalyAPIError: Error, LocalizedError {
    case badURL
    case http(Int)
    case offline

    var errorDescription: String? {
        switch self {
        case .badURL: return "The server address is invalid."
        case .http(let code): return "The server returned an error (\(code))."
        case .offline: return "Couldn't reach the CardioGuard server."
        }
    }
}

struct AnomalyAPIConfig {
    /// Simulator + server on the same Mac: "http://localhost:8000".
    /// Real iPhone on the same Wi-Fi: "http://<your-mac-LAN-IP>:8000". Production: use https.
    var baseURL: String = "http://localhost:8000"
    /// Matches CARDIOGUARD_API_KEY on the server (leave empty in dev mode).
    var apiKey: String = ""
}

final class AnomalyAPIClient {
    private let config: AnomalyAPIConfig
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(config: AnomalyAPIConfig = AnomalyAPIConfig(), session: URLSession = .shared) {
        self.config = config
        self.session = session

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
    }

    /// Scores `reading` against the user's own `history`. Never throws for "abnormal" results;
    /// throws only for network / server problems so the app can keep working offline.
    func score(reading: APIReading, history: [APIReading]) async throws -> ScoreResult {
        guard let url = URL(string: config.baseURL + "/v1/score") else {
            throw AnomalyAPIError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        }

        // Cap history so requests stay small: the most recent 500 readings are plenty.
        let recent: [APIReading] = Array(history.sorted { $0.timestamp < $1.timestamp }.suffix(500))
        let body = ScoreRequestBody(reading: reading, history: recent)
        request.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnomalyAPIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw AnomalyAPIError.offline }
        guard (200..<300).contains(http.statusCode) else { throw AnomalyAPIError.http(http.statusCode) }
        return try decoder.decode(ScoreResult.self, from: data)
    }
}

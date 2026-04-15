import Foundation

/// HTTP client for pushing records to the Cloudflare D1 API.
///
/// Reuses the Apex pattern: `POST /v1/:table` with a JSON body.
/// All methods are async and never throw — errors are logged internally
/// so the mirror layer stays fire-and-forget.
struct APIClient {
    let baseURL: URL
    let authToken: String

    private let session: URLSession
    private let encoder = JSONEncoder()

    init(baseURL: URL, authToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = session
    }

    // MARK: - Push

    /// Push a single mirrorable record to the remote table.
    /// Returns `true` on success, `false` on failure (logged, never thrown).
    @discardableResult
    func push(_ record: MirrorableRecord) async -> Bool {
        guard let request = buildPushRequest(for: record) else {
            log("Failed to build request for table \(record.mirrorTable)")
            return false
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("Push to \(record.mirrorTable) failed with status \(code)")
                return false
            }
            return true
        } catch {
            log("Push to \(record.mirrorTable) error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Request Building

    func buildPushRequest(for record: MirrorableRecord) -> URLRequest? {
        let url = baseURL.appendingPathComponent("v1/\(record.mirrorTable)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let payload = record.toMirrorPayload()
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        request.httpBody = body
        return request
    }

    // MARK: - Private

    private func log(_ message: String) {
        Log.sync.warning(message)
    }
}

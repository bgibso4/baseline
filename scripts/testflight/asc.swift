// App Store Connect for the TestFlight workflow. Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the .p8 file).
// Errors print the API's error title and detail; the key and the token are never printed.
import CryptoKit
import Foundation

let usage = """
    usage: swift scripts/testflight/asc.swift <command>

      count-certificates [--type <certificateType>]
          Prints how many certificates the team has (of that type, e.g. DEVELOPMENT). Read-only.
      selftest
          Checks the token's shape and error reports offline (scripts/testflight/tests/asc.bats).
    """
/// GETs that hit a network error, a 5xx or a 429 are tried this many times in all, this far apart.
let getAttempts = 3
let retryDelay: Duration = .seconds(10)

struct Failure: Error {
    let message: String
}

/// A line to standard output (scripts don't log; the workflow reads this).
func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - The API

typealias JSON = [String: Any]

struct Client {
    let keyID: String
    let issuerID: String
    let key: P256.Signing.PrivateKey

    /// An ES256 token for the App Store Connect API, good for 15 minutes; a new one for each request.
    func token() throws -> String {
        let header: JSON = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        let payload: JSON = [
            "iss": issuerID, "exp": Int(Date().timeIntervalSince1970) + 15 * 60, "aud": "appstoreconnect-v1"
        ]
        let input = try [header, payload]
            .map { try base64URL(JSONSerialization.data(withJSONObject: $0)) }
            .joined(separator: ".")
        let signature = try key.signature(for: Data(input.utf8)).rawRepresentation
        return input + "." + base64URL(signature)
    }

    func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// GETs a path, retried after a network error, a 5xx or a 429.
    func get(_ path: String, query: [String: String] = [:]) async throws -> JSON {
        guard var components = URLComponents(string: "https://api.appstoreconnect.apple.com" + path) else {
            throw Failure(message: "bad path \(path)")
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw Failure(message: "bad query for \(path)") }
        var request = URLRequest(url: url)
        var attempt = 1
        while true {
            request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200..<300).contains(status) {
                    return data.isEmpty ? [:] : (try JSONSerialization.jsonObject(with: data) as? JSON ?? [:])
                }
                let message = apiError(method: "GET", path: path, status: status, body: data)
                guard status >= 500 || status == 429, attempt < getAttempts else { throw Failure(message: message) }
                say("\(message); trying again")
            } catch let error as URLError where attempt < getAttempts {
                say("App Store Connect, GET \(path): \(error.localizedDescription); trying again")
            }
            attempt += 1
            try await Task.sleep(for: retryDelay)
        }
    }
}

func makeClient() -> Client {
    let environment = ProcessInfo.processInfo.environment
    let names = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"]
    let missing = names.filter { (environment[$0] ?? "").isEmpty }
    guard missing.isEmpty, let keyID = environment["ASC_KEY_ID"], let issuerID = environment["ASC_ISSUER_ID"],
        let keyPath = environment["ASC_KEY_PATH"]
    else { fail("not set: \(missing.joined(separator: " "))") }
    // try?: the reasons below are enough, and the key's own errors could quote it, so they are never shown.
    guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8) else { fail("can't read ASC_KEY_PATH") }
    // try?: as above, never show the key's parse error.
    guard let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        fail("ASC_KEY_PATH isn't an App Store Connect .p8 key")
    }
    return Client(keyID: keyID, issuerID: issuerID, key: key)
}

/// The API's error title and detail, or just the status when the body isn't the API's JSON (a proxy's 5xx page).
func apiError(method: String, path: String, status: Int, body: Data) -> String {
    // try?: a body that isn't JSON still gets reported, by its status.
    let json = (try? JSONSerialization.jsonObject(with: body)) as? JSON
    let error = (json?["errors"] as? [JSON])?.first
    let title = (error?["title"] as? String).map { ": \($0)" } ?? ""
    let detail = (error?["detail"] as? String).map { " \($0)" } ?? ""
    return "App Store Connect, \(method) \(path) (HTTP \(status))\(title)\(detail)"
}

// MARK: - Commands

func countCertificates(type: String?, client: Client) async throws {
    var query = ["limit": "200"]
    query["filter[certificateType]"] = type
    let json = try await client.get("/v1/certificates", query: query)
    let total = ((json["meta"] as? JSON)?["paging"] as? JSON)?["total"] as? Int
    say(String(total ?? (json["data"] as? [JSON])?.count ?? 0))
}

// MARK: - Self-test

func decodeBase64URL(_ text: String) -> Data? {
    var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    return Data(base64Encoded: base64)
}

/// Offline checks of the token and error reports; the first failure ends it.
func selftest() throws {
    func check(_ condition: Bool, _ what: String) throws {
        if !condition { throw Failure(message: "selftest: \(what)") }
    }
    let key = P256.Signing.PrivateKey()
    let client = Client(keyID: "KEY123", issuerID: "issuer-1", key: key)
    let parts = try client.token().split(separator: ".").map(String.init)
    try check(parts.count == 3, "the token has three parts")
    try check(parts.allSatisfy { !$0.contains(where: { "+/=".contains($0) }) }, "the token is base64url")
    let decoded = parts.map { decodeBase64URL($0) ?? Data() }
    // try?: a part that isn't JSON fails the checks below.
    let objects = decoded.prefix(2).map { (try? JSONSerialization.jsonObject(with: $0)) as? JSON ?? [:] }
    let (header, payload) = (objects[0], objects[1])
    try check(header.count == 3, "the header has alg, kid and typ only")
    try check(header["alg"] as? String == "ES256" && header["kid"] as? String == "KEY123", "the header's alg and kid")
    try check(header["typ"] as? String == "JWT", "the header's typ")
    try check(payload["iss"] as? String == "issuer-1", "the payload's iss")
    try check(payload["aud"] as? String == "appstoreconnect-v1", "the payload's aud")
    let lifetime = (payload["exp"] as? Int ?? 0) - Int(Date().timeIntervalSince1970)
    try check((14 * 60...15 * 60).contains(lifetime), "the token expires in 15 minutes")
    let signature = try P256.Signing.ECDSASignature(rawRepresentation: decoded[2])
    let input = Data((parts[0] + "." + parts[1]).utf8)
    try check(key.publicKey.isValidSignature(signature, for: input), "the signature verifies")

    let html = apiError(method: "GET", path: "/v1/builds", status: 502, body: Data("<html>Bad Gateway</html>".utf8))
    try check(html == "App Store Connect, GET /v1/builds (HTTP 502)", "a non-JSON error reports its status")
    let body = Data(#"{"errors":[{"title":"Not found","detail":"No build."}]}"#.utf8)
    let api = apiError(method: "GET", path: "/v1/builds", status: 404, body: body)
    try check(api == "App Store Connect, GET /v1/builds (HTTP 404): Not found No build.", "an API error's title")
    say("selftest: ok")
}

// MARK: - Main

var arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    say(usage)
    exit(arguments.isEmpty ? 64 : 0)
}
let command = arguments.removeFirst()

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

do {
    switch command {
    case "count-certificates":
        try await countCertificates(type: option("--type"), client: makeClient())
    case "selftest":
        try selftest()
    default:
        fail("unknown command \(command)\n\(usage)")
    }
} catch let failure as Failure {
    fail(failure.message)
} catch {
    fail(error.localizedDescription)
}

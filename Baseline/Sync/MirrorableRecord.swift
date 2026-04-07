import Foundation

/// A record that can be mirrored to an outbound sync target (e.g. Cloudflare D1).
///
/// Each conforming model declares the remote table name and converts itself
/// to a dictionary payload for the API request body.
protocol MirrorableRecord {
    var mirrorTable: String { get }
    func toMirrorPayload() -> [String: Any]
}

// MARK: - WeightEntry + MirrorableRecord

extension WeightEntry: MirrorableRecord {
    var mirrorTable: String { "weight_entries" }

    func toMirrorPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "id": id.uuidString,
            "weight": weight,
            "unit": unit,
            "date": ISO8601DateFormatter().string(from: date),
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
        if let notes { payload["notes"] = notes }
        return payload
    }
}

// MARK: - Scan + MirrorableRecord

extension Scan: MirrorableRecord {
    var mirrorTable: String { "scans" }

    func toMirrorPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "id": id.uuidString,
            "date": ISO8601DateFormatter().string(from: date),
            "type": type,
            "source": source,
            "payload_data": payloadData.base64EncodedString(),
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
        if let notes { payload["notes"] = notes }
        return payload
    }
}

// MARK: - Measurement + MirrorableRecord

extension Measurement: MirrorableRecord {
    var mirrorTable: String { "measurements" }

    func toMirrorPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "id": id.uuidString,
            "date": ISO8601DateFormatter().string(from: date),
            "type": type,
            "value_cm": valueCm,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
        if let notes { payload["notes"] = notes }
        return payload
    }
}

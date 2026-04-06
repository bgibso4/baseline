import Foundation
import SwiftData

@Model
final class Scan {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    var source: String = ""
    var notes: String?
    var payloadData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(date: Date, type: ScanType, source: ScanSource, payload: Data, notes: String? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type.rawValue
        self.source = source.rawValue
        self.payloadData = payload
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var scanType: ScanType? { ScanType(rawValue: type) }
    var scanSource: ScanSource? { ScanSource(rawValue: source) }

    func decoded() throws -> ScanContent {
        guard let scanType = ScanType(rawValue: type) else {
            throw ScanDecodingError.unknownType(type)
        }
        switch scanType {
        case .inBody:
            let payload = try JSONDecoder().decode(InBodyPayload.self, from: payloadData)
            return .inBody(payload)
        }
    }
}

enum ScanType: String, Codable, CaseIterable {
    case inBody
}

enum ScanSource: String, Codable, CaseIterable {
    case manual
    case ocr
    case imported
}

enum ScanDecodingError: Error {
    case unknownType(String)
}

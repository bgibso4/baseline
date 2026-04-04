import SwiftData
import Foundation

@Model
final class BodyMeasurement {
    var id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

import SwiftData
import Foundation

@Model
final class WeightEntry {
    var id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

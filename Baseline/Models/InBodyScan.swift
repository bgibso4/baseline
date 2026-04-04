import SwiftData
import Foundation

@Model
final class InBodyScan {
    var id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

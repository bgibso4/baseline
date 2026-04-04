import Foundation
import SwiftData

@Model
class SyncState {
    @Attribute(.unique) var tableName: String
    var lastSyncTimestamp: String

    init(tableName: String, lastSyncTimestamp: String = "") {
        self.tableName = tableName
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}

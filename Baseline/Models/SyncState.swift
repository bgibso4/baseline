import Foundation
import SwiftData

extension BaselineSchemaV1 {
    @Model
    class SyncState {
        var tableName: String = ""
        var lastSyncTimestamp: String = ""

        init(tableName: String, lastSyncTimestamp: String = "") {
            self.tableName = tableName
            self.lastSyncTimestamp = lastSyncTimestamp
        }
    }
}

typealias SyncState = BaselineSchemaV1.SyncState

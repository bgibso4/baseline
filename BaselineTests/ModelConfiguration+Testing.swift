import SwiftData

extension ModelConfiguration {
    /// In-memory store for tests, with CloudKit explicitly off.
    ///
    /// The default (`.automatic`) mirrors to iCloud because the test host has the
    /// iCloud entitlement. On iOS 27, in a simulator with no iCloud account, saves
    /// to those stores abort with "No eligible connection available".
    static var inMemoryForTesting: ModelConfiguration {
        ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }
}

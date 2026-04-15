import Foundation
import SwiftData

/// Cadre-build implementation of `OutboundMirror` that pushes records
/// to Cloudflare D1 via the shared API (same endpoints Apex uses).
///
/// Fire-and-forget: failures are logged, never blocking. CloudKit remains
/// the source of truth; this mirror is purely additive.
struct CloudflareOutboundMirror: OutboundMirror {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - OutboundMirror

    func mirror(_ record: MirrorableRecord) async {
        let success = await apiClient.push(record)
        if success {
            Log.sync.debug("Mirrored record to \(record.mirrorTable)")
        } else {
            Log.sync.warning("Failed to mirror record to \(record.mirrorTable)")
        }
    }

    func reconcile(context: ModelContext) async {
        await reconcileTable(WeightEntry.self, context: context)
        await reconcileTable(Scan.self, context: context)
        await reconcileTable(Measurement.self, context: context)
    }

    // MARK: - Private

    private func reconcileTable<T: PersistentModel & MirrorableRecord>(
        _ type: T.Type,
        context: ModelContext
    ) async {
        // Read last sync timestamp for this table
        let tableName = T.self == WeightEntry.self ? "weight_entries"
            : T.self == Scan.self ? "scans"
            : "measurements"

        let lastSync = fetchLastSync(for: tableName, context: context)

        // Fetch records updated since last sync
        let records: [T]
        do {
            var descriptor = FetchDescriptor<T>()
            if let since = lastSync {
                descriptor.predicate = #Predicate<T> { _ in true }
                // Fetch all and filter in memory — SwiftData generic predicates
                // cannot reference stored properties across types in a single predicate.
                let all = try context.fetch(descriptor)
                records = all
                    .filter { record in
                        guard let entry = record as? any Timestamped else { return true }
                        return entry.updatedAt > since
                    }
            } else {
                records = try context.fetch(descriptor)
            }
        } catch {
            Log.sync.error("Reconcile fetch failed for \(tableName): \(error.localizedDescription)")
            return
        }

        guard !records.isEmpty else {
            Log.sync.debug("Reconcile: \(tableName) is up to date")
            return
        }

        Log.sync.info("Reconcile: pushing \(records.count) records to \(tableName)")

        var latestUpdate: Date?
        for record in records {
            await mirror(record)
            if let ts = (record as? any Timestamped)?.updatedAt {
                if latestUpdate == nil || ts > latestUpdate! {
                    latestUpdate = ts
                }
            }
        }

        // Update sync state
        if let latestUpdate {
            updateLastSync(for: tableName, date: latestUpdate, context: context)
        }
    }

    private func fetchLastSync(for tableName: String, context: ModelContext) -> Date? {
        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == tableName }
        )
        descriptor.fetchLimit = 1
        guard let state = try? context.fetch(descriptor).first,
              !state.lastSyncTimestamp.isEmpty else {
            return nil
        }
        return ISO8601DateFormatter().date(from: state.lastSyncTimestamp)
    }

    private func updateLastSync(for tableName: String, date: Date, context: ModelContext) {
        let timestamp = ISO8601DateFormatter().string(from: date)
        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == tableName }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.lastSyncTimestamp = timestamp
        } else {
            let state = SyncState(tableName: tableName, lastSyncTimestamp: timestamp)
            context.insert(state)
        }
        try? context.save()
    }
}

// MARK: - Timestamped

/// Internal protocol to access `updatedAt` generically across model types.
private protocol Timestamped {
    var updatedAt: Date { get }
}

extension WeightEntry: Timestamped {}
extension Scan: Timestamped {}
extension Measurement: Timestamped {}

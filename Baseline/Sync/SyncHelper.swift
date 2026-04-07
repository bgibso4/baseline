import Foundation

/// Centralized access point for the outbound mirror.
///
/// View models call `SyncHelper.mirrorRecord(_:)` after saving to SwiftData.
/// The mirror implementation is injected at app startup — `NoOpOutboundMirror`
/// for the public build, `CloudflareOutboundMirror` for the Cadre build.
enum SyncHelper {
    static var mirror: OutboundMirror = NoOpOutboundMirror()

    /// Fire-and-forget mirror of a single record. Spawns an unstructured task
    /// so the caller never blocks on network I/O.
    static func mirrorRecord(_ record: MirrorableRecord) {
        Task { await mirror.mirror(record) }
    }
}

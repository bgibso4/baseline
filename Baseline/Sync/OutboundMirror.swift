import Foundation
import SwiftData

/// Outbound mirror protocol for replicating local SwiftData records
/// to an external data store. The app talks only to this protocol;
/// the build configuration picks the concrete implementation.
///
/// See: docs/superpowers/specs/2026-04-05-release-strategy-and-scan-model-design.md
protocol OutboundMirror {
    /// Push a single record to the mirror target. Fire-and-forget — failures
    /// are logged, never surfaced to the user.
    func mirror(_ record: MirrorableRecord) async

    /// Catch-up sync: push any records created or updated since the last
    /// successful mirror. Called on app launch and return-to-foreground.
    func reconcile(context: ModelContext) async
}

// MARK: - NoOpOutboundMirror

/// Public-build implementation: does nothing. Injected when the Cloudflare
/// mirror is disabled (i.e. the non-Cadre App Store build).
struct NoOpOutboundMirror: OutboundMirror {
    func mirror(_ record: MirrorableRecord) async { }
    func reconcile(context: ModelContext) async { }
}

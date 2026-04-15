import Foundation
import os

// MARK: - Log Backend Protocol

/// Abstraction for log destinations. The default backend uses Apple's unified
/// logging (`os.Logger`). Swap or layer additional backends (Sentry, Amplitude,
/// Datadog, etc.) by conforming to this protocol and calling `Log.addBackend()`.
protocol LogBackend {
    func log(_ level: Log.Level, category: String, message: String)
}

// MARK: - Log

/// Centralized, category-based logging for Baseline.
///
/// Usage:
///     Log.data.info("Saved weight entry")
///     Log.data.error("Save failed", error)
///     Log.health.warning("HealthKit authorization denied")
///
/// All messages route through `os.Logger` by default (visible in Console.app,
/// included in sysdiagnose crash logs). Additional backends can be added at
/// runtime for analytics, crash reporting, or remote logging:
///
///     Log.addBackend(SentryLogBackend())
///
enum Log {

    enum Level: String {
        case debug, info, warning, error
    }

    // MARK: - Categories

    /// SwiftData saves, fetches, deletes, migrations
    static let data = Channel("Data")

    /// CloudKit sync, Cloudflare mirror
    static let sync = Channel("Sync")

    /// HealthKit writes and authorization
    static let health = Channel("Health")

    /// OCR parsing, document scanning, image processing
    static let scan = Channel("Scan")

    /// App lifecycle — launch, background, foreground, memory warnings
    static let app = Channel("App")

    /// Goal tracking — set, complete, abandon, auto-detect
    static let goal = Channel("Goal")

    // MARK: - Backends

    private static var extraBackends: [LogBackend] = []

    /// Register an additional log backend (e.g., Sentry, analytics).
    /// Called at app launch after initializing the third-party SDK.
    static func addBackend(_ backend: LogBackend) {
        extraBackends.append(backend)
    }

    /// Forward a log entry to all registered backends.
    fileprivate static func forward(_ level: Level, category: String, message: String) {
        for backend in extraBackends {
            backend.log(level, category: category, message: message)
        }
    }

    // MARK: - Channel

    /// A typed logging channel. Each channel maps to an `os.Logger` category
    /// and forwards to any registered backends.
    struct Channel {
        private let logger: Logger
        private let category: String

        init(_ category: String) {
            self.logger = Logger(subsystem: "com.cadre.baseline", category: category)
            self.category = category
        }

        func debug(_ message: String) {
            logger.debug("\(message, privacy: .public)")
            Log.forward(.debug, category: category, message: message)
        }

        func info(_ message: String) {
            logger.info("\(message, privacy: .public)")
            Log.forward(.info, category: category, message: message)
        }

        func warning(_ message: String) {
            logger.warning("\(message, privacy: .public)")
            Log.forward(.warning, category: category, message: message)
        }

        func error(_ message: String) {
            logger.error("\(message, privacy: .public)")
            Log.forward(.error, category: category, message: message)
        }

        /// Log an error with its description appended.
        func error(_ message: String, _ error: Error) {
            let full = "\(message): \(error.localizedDescription)"
            logger.error("\(full, privacy: .public)")
            Log.forward(.error, category: category, message: full)
        }
    }
}

// MARK: - Default Backend (os.Logger)

/// The default backend is baked into `Channel` via `os.Logger`.
/// This struct exists as a reference for how to build additional backends.
///
/// Example third-party backend:
///
///     struct SentryLogBackend: LogBackend {
///         func log(_ level: Log.Level, category: String, message: String) {
///             if level == .error || level == .warning {
///                 SentrySDK.capture(message: "[\(category)] \(message)")
///             }
///         }
///     }
///
///     // In BaselineApp.init():
///     SentrySDK.start { options in ... }
///     Log.addBackend(SentryLogBackend())

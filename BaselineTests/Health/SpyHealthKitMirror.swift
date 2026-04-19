import Foundation
import HealthKit
@testable import Baseline

/// Test double for `HealthMirroring` that records every save/delete call
/// in order so tests can assert on the exact sequence of operations VMs
/// perform. Actor-isolated so calls fired from unstructured Tasks don't
/// race on the recording array.
actor SpyHealthKitMirror: HealthMirroring {

    /// A single recorded interaction. Only the source UUID is captured —
    /// numeric values and dates belong to the sample builders' tests, not
    /// the flow-level tests that use this spy.
    enum Call: Equatable, CustomStringConvertible {
        case saveWeight(entryID: UUID)
        case saveScanMetrics(scanID: UUID)
        case saveWaist(sourceID: UUID)
        case delete(sourceID: UUID)

        var description: String {
            switch self {
            case .saveWeight(let id): return "saveWeight(\(id.uuidString.prefix(8)))"
            case .saveScanMetrics(let id): return "saveScanMetrics(\(id.uuidString.prefix(8)))"
            case .saveWaist(let id): return "saveWaist(\(id.uuidString.prefix(8)))"
            case .delete(let id): return "delete(\(id.uuidString.prefix(8)))"
            }
        }
    }

    private(set) var calls: [Call] = []

    func reset() {
        calls = []
    }

    /// Polls until `count` calls are recorded or `timeout` seconds elapse.
    /// VMs dispatch HK work in detached Tasks, so tests need a way to wait
    /// for those tasks to reach the mirror before asserting.
    func waitForCalls(_ count: Int, timeout: TimeInterval = 2.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while calls.count < count && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000) // 2ms
        }
    }

    // MARK: - HealthMirroring

    func saveWeight(weight: Double, unit: String, date: Date, sourceID: UUID) async {
        calls.append(.saveWeight(entryID: sourceID))
    }

    func saveScanMetrics(payload: InBodyPayload, date: Date, sourceID: UUID) async {
        calls.append(.saveScanMetrics(scanID: sourceID))
    }

    func saveWaistCircumference(valueCm: Double, date: Date, sourceID: UUID) async {
        calls.append(.saveWaist(sourceID: sourceID))
    }

    func deleteSamples(forSourceID id: UUID) async {
        calls.append(.delete(sourceID: id))
    }
}

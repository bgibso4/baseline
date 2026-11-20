import XCTest
import UIKit
import FoundationModels
@testable import Baseline

/// End-to-end accuracy of the on-device model path against every scan
/// fixture. This is the acceptance bar for issue #49.
///
/// Needs Apple Intelligence, so it never runs in CI: it is skipped unless
/// `RUN_INTELLIGENCE_ACCURACY=1` (pass `TEST_RUNNER_RUN_INTELLIGENCE_ACCURACY=1`
/// to xcodebuild) and skipped when the model is unavailable. Each test
/// attaches a scorecard listing every value that was wrong or blank.
final class IntelligenceAccuracyTests: XCTestCase {

    private struct Reading {
        let result: InBodyParseResult
        let seconds: TimeInterval
    }

    /// One model read per fixture, shared by every test in the class.
    private static var readings: [String: Reading] = [:]

    override func setUp() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_INTELLIGENCE_ACCURACY"] == "1",
            "Set RUN_INTELLIGENCE_ACCURACY=1 to run the on-device model accuracy suite."
        )
        let model = SystemLanguageModel.default
        try XCTSkipUnless(
            model.availability == .available && model.capabilities.contains(.vision),
            "The on-device model is not available on this destination."
        )
        guard Self.readings.isEmpty else { return }
        let reader = InBodyIntelligenceReader(
            locator: VisionSectionLocator(),
            sections: FoundationModelsSectionReader(),
            fallback: ForbiddenFallback()
        )
        for truth in ScanFixtureTruth.all {
            let page = try ScanFixtureTruth.image(named: truth.name)
            let start = Date()
            let result = await reader.read(page: page)
            Self.readings[truth.name] = Reading(result: result, seconds: Date().timeIntervalSince(start))
            // The system rate-limits model requests from a backgrounded app.
            let state = await UIApplication.shared.applicationState
            NSLog("ACCURACY \(truth.name) read with app state \(state.rawValue) (0 = active)")
        }
    }

    // MARK: - The bar

    func testCoreValues() {
        var failures: [String] = []
        for truth in ScanFixtureTruth.all {
            for key in ScanFixtureTruth.coreKeys {
                let tolerance = key == "basalMetabolicRate" ? 0.5 : 0.05
                if case .right = verdict(truth, key, tolerance: tolerance) { continue }
                failures.append(describe(truth, key))
            }
        }
        report("Core values", failures)
        XCTAssertTrue(failures.isEmpty, "core values wrong or blank:\n" + failures.joined(separator: "\n"))
    }

    func testOtherSections() {
        var failures: [String] = []
        let skipped = Set(ScanFixtureTruth.coreKeys + ScanFixtureTruth.segmentalLeanKeys)
        for truth in ScanFixtureTruth.all {
            for key in ScanFixtureTruth.keys where !skipped.contains(key) {
                switch verdict(truth, key, tolerance: 0.0006) {
                case .right: continue
                case .blank where truth.isMisprinted: continue
                default: failures.append(describe(truth, key))
                }
            }
        }
        report("Other sections", failures)
        XCTAssertTrue(failures.isEmpty, "values wrong, or blank on a clean sheet:\n" + failures.joined(separator: "\n"))
    }

    func testSegmentalLean() {
        var failures: [String] = []
        for truth in ScanFixtureTruth.all {
            for key in ScanFixtureTruth.segmentalLeanKeys {
                switch verdict(truth, key, tolerance: 0.0006) {
                case .right: continue
                case .blank where truth.isMisprinted: continue
                case .wrong(flagged: true) where truth.isMisprinted: continue
                default: failures.append(describe(truth, key))
                }
            }
        }
        report("Segmental lean", failures)
        XCTAssertTrue(failures.isEmpty, "segmental lean below the bar:\n" + failures.joined(separator: "\n"))
    }

    func testDates() {
        var failures: [String] = []
        for truth in ScanFixtureTruth.all {
            let read = Self.readings[truth.name]?.result.scanDate
            if let expected = truth.testDate.flatMap({ Calendar.current.date(from: $0) }) {
                if read != expected { failures.append("\(truth.name): date \(String(describing: read)), truth \(expected)") }
            }
            // Where the sheet's date is unreadable, ReadoutValidator's window is
            // the only guard; a plausible-but-wrong date cannot be detected here.
        }
        report("Dates", failures)
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testSecondsPerPage() {
        let lines = ScanFixtureTruth.all.compactMap { truth in
            Self.readings[truth.name].map { "\(truth.name): \(String(format: "%.1f", $0.seconds))s" }
        }
        report("Seconds per page", lines)
    }

    // MARK: - Scoring

    private enum Verdict {
        case right, blank
        case wrong(flagged: Bool)
    }

    private func verdict(_ truth: ScanFixtureTruth, _ key: String, tolerance: Double) -> Verdict {
        guard let result = Self.readings[truth.name]?.result, let expected = truth.values[key] else { return .blank }
        guard let value = result.value(forKey: key) else { return .blank }
        if abs(value - expected) <= tolerance { return .right }
        return .wrong(flagged: (result.confidence[key] ?? 0) < 0.70)
    }

    private func describe(_ truth: ScanFixtureTruth, _ key: String) -> String {
        let result = Self.readings[truth.name]?.result
        let value = result?.value(forKey: key).map { String($0) } ?? "blank"
        let confidence = result?.confidence[key].map { String($0) } ?? "-"
        return "\(truth.name) \(key): got \(value) (confidence \(confidence)), truth \(truth.values[key] ?? .nan)"
    }

    private func report(_ title: String, _ lines: [String]) {
        let body = lines.isEmpty ? "all right" : lines.joined(separator: "\n")
        let attachment = XCTAttachment(string: "\(title)\n\(body)")
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
        NSLog("ACCURACY %@ — %d line(s)\n%@", title, lines.count, body)
    }
}

/// The accuracy suite measures the model path only; reaching the parser is a failure.
private struct ForbiddenFallback: ScanPageReading {
    func read(page: UIImage) async -> InBodyParseResult {
        XCTFail("the model path fell back to the parser")
        return InBodyParseResult()
    }
}

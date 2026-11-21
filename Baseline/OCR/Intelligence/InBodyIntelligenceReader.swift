import UIKit

/// Reads a page by showing the on-device model one section at a time.
///
/// A whole page is too much for the model to read reliably; a crop of one
/// section with a question about only that section is what works. The
/// answers are then range- and redundancy-checked by `ReadoutValidator`.
///
/// Falls back to `fallback` when this path cannot run at all for a page:
/// the image cannot be prepared, the sheet's sections cannot be found, or
/// the model is unavailable.
struct InBodyIntelligenceReader: ScanPageReading {

    private let locator: any SectionLocating
    private let sections: any SectionReading
    private let fallback: any ScanPageReading
    private let now: @Sendable () -> Date

    init(
        locator: any SectionLocating,
        sections: any SectionReading,
        fallback: any ScanPageReading,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.locator = locator
        self.sections = sections
        self.fallback = fallback
        self.now = now
    }

    /// The seven core values come from these, so they are read first.
    private static let readingOrder: [SheetSection] = {
        let core: [SheetSection] = [
            .bodyCompositionValues, .bodyCompositionTotals, .muscleFat, .obesity, .basalMetabolicRate
        ]
        return core + SheetSection.allCases.filter { !core.contains($0) }
    }()

    /// Measured on an iPhone 16 Pro: four at a time is the fastest (about a sixth
    /// quicker than one at a time); more than that is no quicker.
    private static let sectionsReadAtOnce = 4

    private struct SectionOutcome {
        let section: SheetSection
        let reading: Result<SectionReadout, Error>
        let took: Duration
    }

    /// Each value is checked on its own, and a page takes many seconds to read.
    var needsOnlyOnePage: Bool { true }

    func prepare() {
        sections.prepare()
    }

    func read(page: UIImage) async -> InBodyParseResult {
        guard let image = ScanImagePreparer.standardRangeImage(from: page) else {
            Log.scan.error("Intelligence reader: page image could not be prepared; using parser")
            return await fallback.read(page: page)
        }
        let clock = ContinuousClock()
        let started = clock.now
        guard let rects = await locator.sectionRects(in: image) else {
            Log.scan.info("Intelligence reader: sheet sections not found; using parser")
            return await fallback.read(page: page)
        }

        let located = Self.seconds(clock.now - started)

        let crops = Self.readingOrder.compactMap { section in
            rects[section].flatMap { Self.crop(image, to: $0) }.map { (section: section, image: $0) }
        }
        var readouts: [SheetSection: SectionReadout] = [:]
        var timings: [String] = []
        let sections = self.sections
        let modelIsUnavailable = await withTaskGroup(of: SectionOutcome.self) { group in
            var waiting = crops.makeIterator()
            func startNext() {
                guard let next = waiting.next() else { return }
                group.addTask {
                    let sectionStarted = clock.now
                    let reading = await Result { try await sections.read(next.section, crop: next.image) }
                    return SectionOutcome(section: next.section, reading: reading, took: clock.now - sectionStarted)
                }
            }
            for _ in 0..<Self.sectionsReadAtOnce { startNext() }
            for await outcome in group {
                timings.append("\(outcome.section) \(Self.seconds(outcome.took))")
                switch outcome.reading {
                case .success(let readout):
                    readouts[outcome.section] = readout
                case .failure(SectionReadingError.modelUnavailable):
                    group.cancelAll()
                    return true
                case .failure(let error):
                    // The type only: a generation error can describe what was read, which is health data.
                    Log.scan.error("Intelligence reader: \(outcome.section) failed: \(type(of: error))")
                }
                startNext()
            }
            return false
        }
        if modelIsUnavailable {
            Log.scan.error("Intelligence reader: model became unavailable; using parser")
            return await fallback.read(page: page)
        }

        let result = ReadoutValidator.assemble(readouts, now: now())
        guard InBodyParseResult.allFieldKeys.contains(where: { result.value(forKey: $0) != nil }) else {
            Log.scan.error("Intelligence reader: no value could be read; using parser")
            return await fallback.read(page: page)
        }
        let total = Self.seconds(clock.now - started)
        Log.scan.info("Intelligence reader: read \(readouts.count) of \(rects.count) sections in \(total)")
        Log.scan.info("Intelligence reader timings: locate \(located), \(timings.joined(separator: ", "))")
        return result
    }

    private static func seconds(_ duration: Duration) -> String {
        duration.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
    }

    private static func crop(_ image: CGImage, to normalised: CGRect) -> CGImage? {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let pixels = CGRect(
            x: normalised.minX * width,
            y: normalised.minY * height,
            width: normalised.width * width,
            height: normalised.height * height
        ).integral
        return image.cropping(to: pixels)
    }
}

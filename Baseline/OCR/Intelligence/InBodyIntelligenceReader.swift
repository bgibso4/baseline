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

        var readouts: [SheetSection: SectionReadout] = [:]
        var timings: [String] = []
        for section in Self.readingOrder {
            guard let rect = rects[section], let crop = Self.crop(image, to: rect) else { continue }
            let sectionStarted = clock.now
            defer { timings.append("\(section) \(Self.seconds(clock.now - sectionStarted))") }
            do {
                readouts[section] = try await sections.read(section, crop: crop)
            } catch SectionReadingError.modelUnavailable {
                Log.scan.error("Intelligence reader: model became unavailable; using parser")
                return await fallback.read(page: page)
            } catch {
                Log.scan.error("Intelligence reader: \(String(describing: section)) failed: \(error)")
            }
        }

        let result = ReadoutValidator.assemble(readouts, now: now())
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

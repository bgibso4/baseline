import CoreGraphics
import Vision

/// Finds the sheet's sections from the headings Vision recognises on the page.
struct VisionSectionLocator: SectionLocating {

    /// Text starting to the right of this is in the right-hand column.
    private static let columnSplit = 0.55

    func sectionRects(in image: CGImage) async -> [SheetSection: CGRect]? {
        do {
            let observations = try await RecognizeDocumentsRequest().perform(on: image)
            guard let document = observations.first?.document else { return nil }
            return SectionLayout.rects(found: Self.headings(in: document.paragraphs))
        } catch {
            Log.scan.error("Section locator: text recognition failed: \(error)")
            return nil
        }
    }

    /// Heading → distance of its centre from the top of the page.
    private static func headings(in paragraphs: [DocumentObservation.Container.Text]) -> [SheetHeading: Double] {
        var found: [SheetHeading: Double] = [:]
        for paragraph in paragraphs {
            let text = paragraph.transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            // Vision's origin is bottom-left; the layout works from the top.
            let box = paragraph.boundingRegion.boundingBox
            let fromTop = 1 - (box.origin.y + box.height / 2)
            let isRightColumn = box.origin.x > columnSplit
            for heading in SheetHeading.allCases
            where heading.isRightColumn == isRightColumn && heading.matches(text) {
                // The right column repeats its headings in the explanations
                // further down, so the one nearest the top is the real one.
                if let existing = found[heading], existing <= fromTop { continue }
                found[heading] = fromTop
            }
        }
        return found
    }
}

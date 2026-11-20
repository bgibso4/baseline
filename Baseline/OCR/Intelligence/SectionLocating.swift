import CoreGraphics

/// Finds where each section of the sheet is on a page image.
protocol SectionLocating: Sendable {
    /// Section → rectangle in normalised, top-left-origin page coordinates.
    /// `nil` when the page cannot be recognised as an InBody sheet.
    func sectionRects(in image: CGImage) async -> [SheetSection: CGRect]?
}

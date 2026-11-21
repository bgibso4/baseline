import CoreGraphics

enum SectionReadingError: Error {
    /// The on-device model cannot run at all right now (switched off,
    /// still downloading, assets missing). Nothing on this page can be read.
    case modelUnavailable
}

/// Reads the values printed in one cropped section of the sheet.
protocol SectionReading: Sendable {
    /// Throws `SectionReadingError.modelUnavailable` when no section can be
    /// read; any other error means only this section failed.
    func read(_ section: SheetSection, crop: CGImage) async throws -> SectionReadout

    /// Loads whatever the reader needs so the first read is not slow.
    func prepare()
}

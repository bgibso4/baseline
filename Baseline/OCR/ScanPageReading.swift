import UIKit

/// Turns one scanned page into parsed InBody values.
///
/// The confidence on each returned field says how far that value can be
/// trusted; `ScanEntryViewModel` flags anything below its review threshold.
protocol ScanPageReading: Sendable {
    func read(page: UIImage) async -> InBodyParseResult

    /// Optional warm-up before the first read (for example, loading a model).
    func prepare()

    /// True when one page read by this reader can be trusted on its own, so
    /// further pages add waiting time and nothing else. False for a reader
    /// whose accuracy comes from comparing several pages.
    var needsOnlyOnePage: Bool { get }
}

extension ScanPageReading {
    func prepare() {}
    var needsOnlyOnePage: Bool { false }
}

import Foundation

extension String {
    /// Removes a leading UTF-8 BOM (`U+FEFF`) if present. Excel writes one
    /// when exporting CSVs on macOS — silently breaking header matching.
    func stripBOM() -> String {
        guard hasPrefix("\u{FEFF}") else { return self }
        return String(dropFirst())
    }
}

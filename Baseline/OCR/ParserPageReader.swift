import UIKit

/// Reads a page with the position-based `InBodyDocumentParser`.
struct ParserPageReader: ScanPageReading {
    func read(page: UIImage) async -> InBodyParseResult {
        await InBodyDocumentParser.parse(image: page)
    }
}

import FoundationModels

/// Chooses how a scan page is read: the on-device model when it can see
/// images, today's OCR parser otherwise.
enum ScanPageReaderSelector {

    static func reader(modelIsAvailable: Bool, modelSeesImages: Bool) -> any ScanPageReading {
        guard modelIsAvailable, modelSeesImages else { return ParserPageReader() }
        return InBodyIntelligenceReader(
            locator: VisionSectionLocator(),
            sections: FoundationModelsSectionReader(),
            fallback: ParserPageReader()
        )
    }

    /// The reader for this device right now. On-device model only.
    static func current() -> any ScanPageReading {
        let model = SystemLanguageModel.default
        return reader(
            modelIsAvailable: model.availability == .available,
            modelSeesImages: model.capabilities.contains(.vision)
        )
    }
}

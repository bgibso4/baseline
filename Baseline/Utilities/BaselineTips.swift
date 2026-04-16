import TipKit

/// Tip shown on the Now screen near the Weigh In button.
struct WeighInTip: Tip {
    var title: Text {
        Text("Log your weight")
    }

    var message: Text? {
        Text("Tap Weigh In to record today's weight. Consistency builds your trend.")
    }

    var image: Image? {
        Image(systemName: "scalemass.fill")
    }
}

/// Tip shown on the Body screen near the scan entry button.
struct ScanTip: Tip {
    var title: Text {
        Text("Add a body scan")
    }

    var message: Text? {
        Text("Tap + to log an InBody scan. You can photograph the printout or enter values manually.")
    }

    var image: Image? {
        Image(systemName: "camera")
    }
}

/// Tip shown before camera opens for scan — encourages multiple photos.
struct MultiPhotoTip: Tip {
    var title: Text {
        Text("Take multiple photos")
    }

    var message: Text? {
        Text("Scanning the same page 2–3 times significantly improves accuracy. Each photo is cross-checked to catch OCR errors.")
    }

    var image: Image? {
        Image(systemName: "photo.on.rectangle.angled")
    }
}

/// Tip shown on the Trends screen when data exists.
struct TrendsTip: Tip {
    var title: Text {
        Text("Track your progress")
    }

    var message: Text? {
        Text("Switch time ranges to see your weight trend over different periods.")
    }

    var image: Image? {
        Image(systemName: "chart.xyaxis.line")
    }
}

import Foundation

/// Single source of truth for accessibility identifiers used by UI tests.
/// Compiled into both the app and the BaselineUITests target.
enum A11yID {
    enum TabBar {
        static let trends = "tab.trends"
        static let now = "tab.now"
        static let body = "tab.body"
    }
    enum Now {
        static let settingsButton = "now.settingsButton"
        static let historyButton = "now.historyButton"
        static let weighInButton = "now.weighInButton"
        static let rangeToggle = "now.rangeToggle"
        static let statLowest = "now.stat.lowest"
        static let statAverage = "now.stat.average"
        static let statHighest = "now.stat.highest"
    }
    enum WeighIn {
        static let dateChip = "weighIn.dateChip"
        static let stepperPlus = "weighIn.stepperPlus"
        static let stepperMinus = "weighIn.stepperMinus"
        static let addNote = "weighIn.addNote"
        static let addPhoto = "weighIn.addPhoto"
        static let save = "weighIn.save"
        static let overwriteConfirm = "weighIn.overwriteConfirm"
    }
    enum Trends {
        static let metricPicker = "trends.metricPicker"
        static let windowStepBack = "trends.windowStepBack"
        static let windowStepForward = "trends.windowStepForward"
        static let setGoalButton = "trends.setGoalButton"
        static let manageGoalButton = "trends.manageGoalButton"
    }
    enum SetGoal {
        static let targetField = "setGoal.targetField"
        static let targetDateField = "setGoal.targetDateField"
        static let save = "setGoal.save"
        static let cancel = "setGoal.cancel"
    }
    enum Body {
        static let scanButton = "body.scanButton"
        static let logMeasurementButton = "body.logMeasurementButton"
    }
    enum ScanEntry {
        static let manualEntryButton = "scanEntry.manualEntryButton"
        static let weightField = "scanEntry.weightField"
        static let bodyFatField = "scanEntry.bodyFatField"
        static let save = "scanEntry.save"
        static let cancel = "scanEntry.cancel"
    }
    enum History {
        static let list = "history.list"
    }
    enum Settings {
        static let unitToggle = "settings.unitToggle"
        static let importCSV = "settings.importCSV"
        static let exportCSV = "settings.exportCSV"
        static let privacyLink = "settings.privacyLink"
        static let termsLink = "settings.termsLink"
    }
}

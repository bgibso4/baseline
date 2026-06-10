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
        /// Combined non-interactive greeting header ("Good morning, Ben").
        static let greeting = "now.greeting"
        static let statLowest = "now.stat.lowest"
        static let statAverage = "now.stat.average"
        static let statHighest = "now.stat.highest"
        /// Hero weight number — 84pt UIFontMetrics font. Responds to Dynamic Type
        /// at runtime but XCTest audit cannot detect UIFont-bridged scaling.
        /// Used in AccessibilityAuditUITests handler to suppress false-positive.
        static let heroWeight = "now.heroWeight"
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
        /// Hero metric value (large display number). Uses UIFontMetrics-scaled
        /// font that DOES respond to Dynamic Type at runtime, but the XCTest
        /// accessibility audit cannot detect UIFont-bridged scaling — suppressed
        /// in AccessibilityAuditUITests with this identifier.
        static let heroValue = "trends.heroValue"
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
        static let scanHistoryCard = "body.scanHistoryCard"
        // Body composition metric tiles
        static let tileBodyFat = "body.tile.bodyFat"
        static let tileSkeletalMuscle = "body.tile.skeletalMuscle"
        static let tileFatMass = "body.tile.fatMass"
        static let tileBMI = "body.tile.bmi"
        static let tileTotalBodyWater = "body.tile.totalBodyWater"
        static let tileBMR = "body.tile.bmr"
        static let tileInBodyScore = "body.tile.inBodyScore"
        static let tileLeanBodyMass = "body.tile.leanBodyMass"
        // Measurement tiles
        static let tileMeasurementWaist = "body.tile.measurement.waist"
        static let tileMeasurementChest = "body.tile.measurement.chest"
        static let tileMeasurementNeck = "body.tile.measurement.neck"
        static let tileMeasurementHips = "body.tile.measurement.hips"
        static let tileMeasurementArms = "body.tile.measurement.arms"
        static let tileMeasurementThighs = "body.tile.measurement.thighs"
    }
    enum ScanEntry {
        static let manualEntryButton = "scanEntry.manualEntryButton"
        /// "Continue" button on the scan-type selection step (step 1 of 2).
        static let continueButton = "scanEntry.continueButton"
        static let weightField = "scanEntry.weightField"
        static let bodyFatField = "scanEntry.bodyFatField"
        /// Required field: Skeletal Muscle Mass — needed for canSave gate.
        static let skeletalMuscleMassField = "scanEntry.skeletalMuscleMassField"
        /// Required field: Body Fat Mass — needed for canSave gate.
        static let bodyFatMassField = "scanEntry.bodyFatMassField"
        /// Required field: Total Body Water — needed for canSave gate.
        static let totalBodyWaterField = "scanEntry.totalBodyWaterField"
        /// Required field: BMI — needed for canSave gate.
        static let bmiField = "scanEntry.bmiField"
        /// Required field: Basal Metabolic Rate — needed for canSave gate.
        static let basalMetabolicRateField = "scanEntry.basalMetabolicRateField"
        static let save = "scanEntry.save"
        static let cancel = "scanEntry.cancel"
    }
    enum History {
        static let list = "history.list"
    }
    enum Settings {
        static let unitToggle = "settings.unitToggle"
        static let lengthToggle = "settings.lengthToggle"
        static let importCSV = "settings.importCSV"
        static let exportCSV = "settings.exportCSV"
        static let privacyLink = "settings.privacyLink"
        static let termsLink = "settings.termsLink"
        /// "Choose CSV file" button on the ImportCSVView screen.
        static let importChooseFile = "settings.importChooseFile"
        /// DEBUG developer row that clears the onboarding-completed flag.
        static let showOnboardingAgain = "settings.showOnboardingAgain"
    }
    enum Onboarding {
        static let getStarted = "onboarding.getStarted"
        static let skipForNow = "onboarding.skipForNow"
        static let nameField = "onboarding.nameField"
        static let continueButton = "onboarding.continue"
        static let skipName = "onboarding.skipName"
    }
}

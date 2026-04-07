import Foundation
import SwiftData
import Observation

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable {
    case male
    case female
    case other
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }

    /// Only Dark is available in v1.
    var isAvailable: Bool { self == .dark }
}

// MARK: - SettingsViewModel

@Observable
class SettingsViewModel {
    private let defaults: UserDefaults

    // Stored sentinels that @Observable can track.
    // Mutating these triggers SwiftUI view updates for the corresponding
    // computed properties that read from UserDefaults.
    private var _nameVersion = 0
    private var _heightFeetVersion = 0
    private var _heightInchesVersion = 0
    private var _heightCmVersion = 0
    private var _birthdayVersion = 0
    private var _genderVersion = 0
    private var _weightUnitVersion = 0
    private var _lengthUnitVersion = 0
    private var _themeVersion = 0
    private var _syncEnabledVersion = 0
    private var _syncAPIURLVersion = 0
    private var _syncAPIKeyVersion = 0

    // MARK: Profile

    var name: String {
        get { _ = _nameVersion; return defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName"); _nameVersion += 1 }
    }

    var heightFeet: Int {
        get { _ = _heightFeetVersion; return defaults.integer(forKey: "heightFeet") }
        set { defaults.set(newValue, forKey: "heightFeet"); _heightFeetVersion += 1 }
    }

    var heightInches: Int {
        get { _ = _heightInchesVersion; return defaults.integer(forKey: "heightInches") }
        set { defaults.set(newValue, forKey: "heightInches"); _heightInchesVersion += 1 }
    }

    var heightCm: Int {
        get { _ = _heightCmVersion; return defaults.integer(forKey: "heightCm") }
        set { defaults.set(newValue, forKey: "heightCm"); _heightCmVersion += 1 }
    }

    var birthday: Date? {
        get {
            _ = _birthdayVersion
            let interval = defaults.double(forKey: "birthdayInterval")
            return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: "birthdayInterval")
            } else {
                defaults.removeObject(forKey: "birthdayInterval")
            }
            _birthdayVersion += 1
        }
    }

    var gender: Gender? {
        get {
            _ = _genderVersion
            return defaults.string(forKey: "gender").flatMap { Gender(rawValue: $0) }
        }
        set {
            defaults.set(newValue?.rawValue, forKey: "gender")
            _genderVersion += 1
        }
    }

    // MARK: Units

    var weightUnit: String {
        get { _ = _weightUnitVersion; return defaults.string(forKey: "weightUnit") ?? "lb" }
        set { defaults.set(newValue, forKey: "weightUnit"); _weightUnitVersion += 1 }
    }

    var lengthUnit: String {
        get { _ = _lengthUnitVersion; return defaults.string(forKey: "lengthUnit") ?? "in" }
        set {
            let oldValue = defaults.string(forKey: "lengthUnit") ?? "in"
            defaults.set(newValue, forKey: "lengthUnit")
            _lengthUnitVersion += 1
            if oldValue != newValue {
                convertHeight(from: oldValue, to: newValue)
            }
        }
    }

    /// Converts stored height values when the length unit changes.
    private func convertHeight(from oldUnit: String, to newUnit: String) {
        if oldUnit == "in" && newUnit == "cm" {
            // inches → cm
            let totalInches = (heightFeet * 12) + heightInches
            if totalInches > 0 {
                heightCm = Int(round(Double(totalInches) * 2.54))
            }
        } else if oldUnit == "cm" && newUnit == "in" {
            // cm → inches
            if heightCm > 0 {
                let totalInches = Int(round(Double(heightCm) / 2.54))
                heightFeet = totalInches / 12
                heightInches = totalInches % 12
            }
        }
    }

    // MARK: Appearance

    var theme: AppTheme {
        get {
            _ = _themeVersion
            return defaults.string(forKey: "theme").flatMap { AppTheme(rawValue: $0) } ?? .dark
        }
        set { defaults.set(newValue.rawValue, forKey: "theme"); _themeVersion += 1 }
    }

    // MARK: Integrations

    var syncEnabled: Bool {
        get { _ = _syncEnabledVersion; return defaults.bool(forKey: "cadreSyncEnabled") }
        set { defaults.set(newValue, forKey: "cadreSyncEnabled"); _syncEnabledVersion += 1 }
    }

    var syncAPIURL: String {
        get { _ = _syncAPIURLVersion; return defaults.string(forKey: "cadreSyncAPIURL") ?? "" }
        set { defaults.set(newValue, forKey: "cadreSyncAPIURL"); _syncAPIURLVersion += 1 }
    }

    var syncAPIKey: String {
        get { _ = _syncAPIKeyVersion; return defaults.string(forKey: "cadreSyncAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "cadreSyncAPIKey"); _syncAPIKeyVersion += 1 }
    }

    // MARK: Computed

    var age: Int? {
        guard let birthday else { return nil }
        let components = Calendar.current.dateComponents([.year], from: birthday, to: Date())
        return components.year
    }

    var heightDisplay: String {
        if lengthUnit == "cm" {
            return heightCm > 0 ? "\(heightCm) cm" : ""
        } else {
            if heightFeet == 0 && heightInches == 0 { return "" }
            return "\(heightFeet)\u{2032} \(heightInches)\u{2033}"
        }
    }

    var ageDisplay: String {
        guard let age else { return "" }
        return "\(age)"
    }

    var genderDisplay: String {
        gender?.displayName ?? ""
    }

    /// App version string shown in About section.
    var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Actions

    /// Delete all user data from SwiftData and reset UserDefaults preferences.
    func deleteAllData(modelContext: ModelContext) {
        // Delete all SwiftData entities
        do {
            try modelContext.delete(model: WeightEntry.self)
            try modelContext.delete(model: Scan.self)
            try modelContext.delete(model: Baseline.Measurement.self)
            try modelContext.delete(model: SyncState.self)
            try modelContext.save()
        } catch {
            // Log but don't crash — partial deletion is acceptable.
            print("SettingsViewModel: failed to delete data: \(error)")
        }

        // Reset profile + unit prefs
        let keys = [
            "userName", "heightFeet", "heightInches", "heightCm",
            "birthdayInterval", "gender", "weightUnit", "lengthUnit",
            "theme", "cadreSyncEnabled", "cadreSyncAPIURL", "cadreSyncAPIKey"
        ]
        for key in keys { defaults.removeObject(forKey: key) }
    }

    /// Stub: export CSV — Task 19 will implement properly.
    func exportCSV(modelContext: ModelContext) -> URL? {
        // Placeholder — returns nil until Task 19.
        return nil
    }

    /// Counts for the delete confirmation sheet.
    func dataCounts(modelContext: ModelContext) -> (weights: Int, scans: Int, measurements: Int) {
        let weights = (try? modelContext.fetchCount(FetchDescriptor<WeightEntry>())) ?? 0
        let scans = (try? modelContext.fetchCount(FetchDescriptor<Scan>())) ?? 0
        let measurements = (try? modelContext.fetchCount(FetchDescriptor<Baseline.Measurement>())) ?? 0
        return (weights, scans, measurements)
    }
}

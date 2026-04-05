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

    // MARK: Profile

    var name: String {
        get { defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName") }
    }

    var heightFeet: Int {
        get { defaults.integer(forKey: "heightFeet") }
        set { defaults.set(newValue, forKey: "heightFeet") }
    }

    var heightInches: Int {
        get { defaults.integer(forKey: "heightInches") }
        set { defaults.set(newValue, forKey: "heightInches") }
    }

    var heightCm: Int {
        get { defaults.integer(forKey: "heightCm") }
        set { defaults.set(newValue, forKey: "heightCm") }
    }

    var birthday: Date? {
        get {
            let interval = defaults.double(forKey: "birthdayInterval")
            return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: "birthdayInterval")
            } else {
                defaults.removeObject(forKey: "birthdayInterval")
            }
        }
    }

    var gender: Gender? {
        get {
            defaults.string(forKey: "gender").flatMap { Gender(rawValue: $0) }
        }
        set {
            defaults.set(newValue?.rawValue, forKey: "gender")
        }
    }

    // MARK: Units

    var weightUnit: String {
        get { defaults.string(forKey: "weightUnit") ?? "lb" }
        set { defaults.set(newValue, forKey: "weightUnit") }
    }

    var lengthUnit: String {
        get { defaults.string(forKey: "lengthUnit") ?? "in" }
        set { defaults.set(newValue, forKey: "lengthUnit") }
    }

    // MARK: Appearance

    var theme: AppTheme {
        get {
            defaults.string(forKey: "theme").flatMap { AppTheme(rawValue: $0) } ?? .dark
        }
        set { defaults.set(newValue.rawValue, forKey: "theme") }
    }

    // MARK: Integrations

    var syncEnabled: Bool {
        get { defaults.bool(forKey: "cadreSyncEnabled") }
        set { defaults.set(newValue, forKey: "cadreSyncEnabled") }
    }

    var syncAPIURL: String {
        get { defaults.string(forKey: "cadreSyncAPIURL") ?? "" }
        set { defaults.set(newValue, forKey: "cadreSyncAPIURL") }
    }

    var syncAPIKey: String {
        get { defaults.string(forKey: "cadreSyncAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "cadreSyncAPIKey") }
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

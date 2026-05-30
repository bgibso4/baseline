import Foundation

// MARK: - Column roles
//
// The semantic dimensions a CSV row can carry, independent of what the
// source spreadsheet happens to call them. Parsers extract data by role,
// not by column index or header string — so a header of `Weight (lb)` and
// one of `lb` resolve to the same thing.

/// Semantic role of a single CSV column.
enum ColumnRole: String, Hashable, CaseIterable {
    // Shared across all formats
    case date
    case time
    case notes

    // Weight entries
    case weight
    case weightUnit

    // Tape measurements
    case measurementType
    case measurementValue

    // InBody scans
    case scanType
    case scanSource
    case scanWeightKg
    case scanSMM
    case scanBFM
    case scanPBF
    case scanTBW
    case scanBMI
    case scanBMR
}

/// Registry of acceptable header names for each role. Matching is
/// case-insensitive, trims whitespace, and ignores parenthesized hints
/// (which are captured separately for unit resolution).
///
/// **Extension point:** to accept a new synonym for an existing role,
/// add it to the set. To introduce a new role, add a `ColumnRole` case
/// and a matching entry here — the parsers pick it up via `HeaderMap`
/// without any orchestration change.
enum ColumnSynonyms {
    static let registry: [ColumnRole: Set<String>] = [
        .date: ["date", "day", "timestamp", "datetime"],
        .time: ["time", "time of day", "clock"],
        .notes: ["notes", "note", "comment", "comments", "memo"],

        .weight: ["weight", "mass", "lb", "lbs", "kg", "kgs", "pounds", "kilograms"],
        .weightUnit: ["unit", "units"],

        .measurementType: ["type", "measurement", "part", "site"],
        .measurementValue: ["value", "valuecm", "valuein", "measurement value", "cm", "in", "inches", "centimeters"],

        .scanType: ["type", "scan type"],
        .scanSource: ["source", "scan source"],
        .scanWeightKg: ["weightkg", "weight_kg"],
        .scanSMM: ["skeletalmusclemasskg", "skeletal_muscle_mass_kg", "smm"],
        .scanBFM: ["bodyfatmasskg", "body_fat_mass_kg", "bfm"],
        .scanPBF: ["bodyfatpct", "body_fat_pct", "pbf"],
        .scanTBW: ["totalbodywaterl", "total_body_water_l", "tbw"],
        .scanBMI: ["bmi"],
        .scanBMR: ["basalmetabolicrate", "basal_metabolic_rate", "bmr"]
    ]

    /// Returns every role whose synonym set contains this normalised
    /// header. Multiple roles can match (e.g. `type` matches both
    /// `.measurementType` and `.scanType`); format detection later
    /// disambiguates based on which required-column-sets are satisfied.
    static func roles(forNormalized header: String) -> Set<ColumnRole> {
        var matches: Set<ColumnRole> = []
        for (role, synonyms) in registry where synonyms.contains(header) {
            matches.insert(role)
        }
        return matches
    }
}

// MARK: - Header parsing

/// One header cell's raw form broken into the parts each consumer needs:
/// the synonym-match key (`normalized`) and the optional unit hint
/// extracted from any parenthesized suffix (`"Weight (lb)"` → `"lb"`).
struct NormalizedHeader: Equatable {
    let raw: String
    let normalized: String
    let parentheticalHint: String?

    init(_ raw: String) {
        self.raw = raw
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let openIdx = trimmed.firstIndex(of: "("),
           let closeIdx = trimmed.firstIndex(of: ")"),
           openIdx < closeIdx {
            let hint = trimmed[trimmed.index(after: openIdx)..<closeIdx]
            let base = trimmed[..<openIdx]
            self.parentheticalHint = hint.trimmingCharacters(in: .whitespaces).lowercased()
            self.normalized = base.trimmingCharacters(in: .whitespaces).lowercased()
        } else {
            self.parentheticalHint = nil
            self.normalized = trimmed.lowercased()
        }
    }
}

/// Maps semantic roles to column indexes. Built once per header row and
/// reused by the per-row parsers.
///
/// Ambiguity handling: if a header matches multiple roles (e.g. `type`
/// → `.measurementType` and `.scanType`), both entries point to the
/// same column index. Format detection resolves which one is load-bearing.
struct HeaderMap {
    /// Headers as they appeared in the file (for error messages).
    let rawHeaders: [String]
    /// Role → column index, first match wins.
    let roleIndex: [ColumnRole: Int]
    /// Role → parenthesized hint captured from that column's header,
    /// if any (e.g. `"lb"` from `Weight (lb)`).
    let roleHint: [ColumnRole: String]

    static func build(from headers: [String]) -> HeaderMap {
        var roleIndex: [ColumnRole: Int] = [:]
        var roleHint: [ColumnRole: String] = [:]

        for (columnIndex, raw) in headers.enumerated() {
            let norm = NormalizedHeader(raw)
            for role in ColumnSynonyms.roles(forNormalized: norm.normalized) where roleIndex[role] == nil {
                roleIndex[role] = columnIndex
                if let hint = norm.parentheticalHint {
                    roleHint[role] = hint
                }
            }
        }

        return HeaderMap(
            rawHeaders: headers,
            roleIndex: roleIndex,
            roleHint: roleHint
        )
    }

    func has(_ role: ColumnRole) -> Bool { roleIndex[role] != nil }

    func hasAll(_ roles: Set<ColumnRole>) -> Bool {
        roles.allSatisfy { has($0) }
    }

    func hasAny(_ roles: Set<ColumnRole>) -> Bool {
        roles.contains { has($0) }
    }

    /// Which of the given roles are missing. Used to build user-facing
    /// error messages when required columns aren't satisfied.
    func missing(_ roles: Set<ColumnRole>) -> [ColumnRole] {
        roles.filter { !has($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Raw value at the column matching `role`, trimmed. Returns nil if
    /// the role is unmapped, the row is short, or the cell is blank.
    func value(_ columns: [String], for role: ColumnRole) -> String? {
        guard let index = roleIndex[role], index < columns.count else { return nil }
        let v = columns[index].trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? nil : v
    }

    /// Parenthesized hint captured from `role`'s header cell, if any.
    func hint(for role: ColumnRole) -> String? { roleHint[role] }
}

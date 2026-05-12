
import Foundation

enum InputValidation {
    private static let maxTagsPerLoad = 12
    private static let maxTagLength = 24

    static func sanitizedName(_ raw: String, fallback: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    static func parsedTags(from commaSeparated: String) -> [String] {
        commaSeparated
            .split { $0 == "," || $0 == ";" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func normalizeTags(from commaSeparated: String) -> [String] {
        var out: [String] = []
        var seenLower = Set<String>()
        for raw in parsedTags(from: commaSeparated) {
            let t = String(raw.prefix(maxTagLength))
            if t.isEmpty { continue }
            let key = t.lowercased()
            if seenLower.contains(key) { continue }
            seenLower.insert(key)
            out.append(t)
            if out.count >= maxTagsPerLoad { break }
        }
        return out
    }

    static func validateTags(_ tags: [String]) -> String? {
        if tags.count > maxTagsPerLoad {
            return "At most \(maxTagsPerLoad) tags per load."
        }
        for t in tags {
            if t.count > maxTagLength {
                return "Each tag must be at most \(maxTagLength) characters."
            }
        }
        return nil
    }

    static func validate(project: Project) -> String? {
        let n = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return "Enter a project name." }
        if project.context.lineToLineVoltageVolts <= 0 { return "Line voltage must be greater than 0." }
        if project.context.lineToNeutralVoltageVolts <= 0 { return "Line-to-neutral voltage must be greater than 0." }
        let cos = project.context.defaultPowerFactor
        if cos < 0.1 || cos > 1 { return "Project power factor must be between 0.1 and 1." }
        if let lim = project.context.maxCurrentPerPhaseAmps, lim <= 0 {
            return "Per-phase limit must be greater than 0, or turn the limit off."
        }
        return nil
    }

    static func validate(load: LoadDevice, context: ProjectElectricalContext) -> String? {
        let n = load.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return "Enter a load name." }
        switch load.inputKind {
        case .current:
            if load.currentAmps < 0 { return "Current cannot be negative." }
        case .power:
            if load.powerKW < 0 { return "Power cannot be negative." }
        }
        if let c = load.customPowerFactor, (c < 0.1 || c > 1) {
            return "Device power factor must be between 0.1 and 1, or leave custom PF off."
        }
        if load.connectionKind == .threePhaseBalanced, context.lineToLineVoltageVolts <= 0 {
            return "Three-phase loads require line voltage greater than 0 in the project."
        }
        if load.connectionKind == .singlePhase, context.lineToNeutralVoltageVolts <= 0 {
            return "Single-phase loads require line-to-neutral voltage greater than 0 in the project."
        }
        if let err = validateTags(load.tags) { return err }
        return nil
    }
}
